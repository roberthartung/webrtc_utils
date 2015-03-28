/**
 * NOTE: We do not extend [Room] because it uses an internal constructor.
 *    Another good side effect is that we can hide the room from the user
 *    So he cannot work on [PeerConnection]s directly.
 */

part of webrtc_utils.game;

/**
 * A room that holds [Player]s instead of [Peer]
 */

abstract class GameRoom<G extends P2PGame, L extends LocalPlayer, R extends RemotePlayer> {
  final G game;
  
  /**
   * Set if the LocalPlayer is the owner of the game (room)
   */
  
  bool get isOwner => _gameOwner == localPlayer;
  Player _gameOwner = null;
    
  /**
   * List of remote Players in the game
   */
  
  final Map<Peer, R> peerToPlayer = {};
  
  /**
   * List of all [Player]s in the game
   */
  
  final List<Player> players = [];
  
  /**
   * A getter to filter the players list for remote players only (used by some mixins)
   */
 
  Iterable<R> get remotePlayers => players.where((Player p) => (p is R));
  
  /**
   * The local player instance
   */
  
  L get localPlayer => _localPlayer;
  L _localPlayer = null;
  
  /**
   * Stream of [Player]s that joined
   */
  
  Stream<R> get onPlayerJoin => _onPlayerJoinStreamController.stream;
  StreamController<R> _onPlayerJoinStreamController = new StreamController.broadcast();
  
  /**
   * Stream of [Player]s that left
   */
  
  Stream<R> get onPlayerLeave => _onPlayerLeaveStreamController.stream;
  StreamController<R> _onPlayerLeaveStreamController = new StreamController.broadcast();
  
  /**
   * Stream of [Player]s that become gameowner
   */
  
  Stream<Player> get onGameOwnerChanged => _onGameOwnerChangedStreamController.stream;
  StreamController<Player> _onGameOwnerChangedStreamController = new StreamController.broadcast();
  
  /**
   * The room of this gameroom
   */
  
  ProtocolPeerRoom get room => _room;
  final ProtocolPeerRoom _room;
  
  GameRoom(this.game, this._room) {
    // _localPlayer = createLocalPlayer(game.id);
    _localPlayer = game.createLocalPlayer(this, game.id);
    _playerJoined(_localPlayer);
    _room.peers.forEach((Peer peer) {
      // R player = createRemotePlayer(peer);
      R player = game.createRemotePlayer(this, peer);
      peerToPlayer[peer] = player;
      _playerJoined(player);
    });
    // Initially get game owner, after this the owner only changes if the player leaves
    _getGameOwner();
    // When a new player joins
    _room.onPeerJoin.listen((Peer peer) {
      // R player = createRemotePlayer(peer);
      R player = game.createRemotePlayer(this, peer);
      peerToPlayer[peer] = player;
      _playerJoined(player);
      // Create channel here and not in RemotePlayer constructor because we only want create channels
      // to be created that joined after us!
      peer.createChannel('game', {'protocol': 'game'});
    });
    // When a player leaves
    room.onPeerLeave.listen((Peer peer) {
      _playerLeft(peerToPlayer.remove(peer));
    });
  }
  
  /**
   * Get game owner from all players (smalles id)
   */
  
  void _getGameOwner() {
    // Get new owner
    players.forEach((Player player) {
      _checkGameOwner(player);
    });
    _onGameOwnerChangedStreamController.add(_gameOwner);
  }
  
  void _checkGameOwner(Player player) {
    if(_gameOwner == null || player.id < _gameOwner.id) {
      _gameOwner = player;
    }
  }
  
  /**
   * Do cleanup after disconnect or room leave
   */
  
  void cleanup() {
    _localPlayer = null;
    players.clear();
    _gameOwner = null;
    peerToPlayer.clear();
  }
  
  /**
   * Called for every Player (both local and remote players)
   */
  
  void _playerJoined(Player player) {
    _onPlayerJoinStreamController.add(player);
    players.add(player);
  }
  
  /**
   * Called for each player, that leaves a room 
   */
  
  void _playerLeft(Player player) {
    players.remove(player);
    // Fire this event before new game owner election to make sure an event handler
    // can compare the current game owner with the player that left the game
    _onPlayerLeaveStreamController.add(player);
    
    // If Player was game owner reset gameowner and elect new one
    if(_gameOwner == player) {
      _gameOwner = null;
      _getGameOwner();
    }
  }
}

/**
 * A Message Queue for the [SynchronizedGameRoom]
 */

class MessageQueue<M> {
  /**
   * Use a SplayTreeMap so we can sort by time
   */
  
  SplayTreeMap<double, Queue<M>> queue = new SplayTreeMap();
  
  /**
   * Getter if this queue is empty
   */
  
  bool get isEmpty => queue.isEmpty;
  
  /**
   * Adds a message at the given point in time
   */
  
  void add(double time, M message) {
    queue.putIfAbsent(time, () => new Queue<M>()).add(message);
  }
  
  /**
   * Retrieve and remove the element, throws StateError if this queue is empty
   */
  
  M poll() {
    if(queue.isEmpty) {
      throw new StateError("MessageQueue is empty");
    }
    final double key =  queue.firstKey();
    // Get first Queue
    Queue<M> head = queue[key];
    // Remove first so we can check for emptyness afterwards
    M first = head.removeFirst();
    // Remove head if queue is empty
    if(head.isEmpty) {
      queue.remove(key);
    }
    return first;
  }
  
  /**
   * Peek at the first element but do not remove it
   */
  
  /*
  M peek() {
    if(queue.isEmpty) {
      throw new StateError("MessageQueue is empty");
    }
    return queue[queue.firstKey()].first;
  }
  */
}

/**
 * Synchronized version of a game room
 */

class SynchronizedGameRoom<G extends SynchronizedP2PGame, L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer>
extends GameRoom<G,L,R> {
  Timer _pingTimer = null;
  
  double get globalTime => isOwner ? window.performance.now() : window.performance.now();
  
  double _maxPing = null;
  double get maxPing => _maxPing == null ? 0 : _maxPing;
  
  double _maxPositiveTimeDifference = null;
  double get timeDifferenceToMaster => _maxPositiveTimeDifference == null ? 0 : _maxPositiveTimeDifference;
  
  Map<R, JsonProtocol> _pingablePlayers = {};
  
  Stream get onSynchronizedMessage => _onSynchronizedMessageController.stream;
  StreamController _onSynchronizedMessageController = new StreamController.broadcast();
  
  MessageQueue _messageQueue = new MessageQueue();
  
  /**
   * Constructor of the [SynchronizedGameRoom] class
   */
  
  SynchronizedGameRoom(G game, ProtocolPeerRoom room) : super(game, room) {
    // Loop through existing players in the channel
    remotePlayers.forEach(_onPlayerJoined);
    onPlayerJoin.listen((R remotePlayer) {
      _onPlayerJoined(remotePlayer);
      // Create channel only for players that join after us.
      remotePlayer.peer.createChannel('synchronization', {'protocol': 'json'});
    });
    
    // Remove Player from list and cancel timer if there are no more RemotePlayers
    onPlayerLeave.listen((R remotePlayer) {
      _pingablePlayers.remove(remotePlayer);
      if(_pingablePlayers.length == 0) {
        _pingTimer.cancel();
        _pingTimer = null;
      }
    });
  }
  
  /**
   * A RemotePlayer [R] joined (existing ones and new ones!)
   */
  
  void _onPlayerJoined(R remotePlayer) {
    remotePlayer.getGameChannel().then((DataChannelProtocol gameChannel) {
      print('[$this] GameChannel: $gameChannel');
      // Sub ping from time because it passed over network
      gameChannel.onMessage.listen((message) => _synchronizeMessage(message['time'] - remotePlayer.ping, message));
    });

    if(_pingTimer == null) {
      _startSynchronizationTimer();
    }
    
    // print('[$this] Player $remotePlayer joined');
    remotePlayer.peer.onProtocol
    .firstWhere((DataChannelProtocol protocol) => (protocol is JsonProtocol && protocol.channel.label == 'synchronization'))
    .then((DataChannelProtocol protocol) {
      _pingablePlayers[remotePlayer] = protocol;
      remotePlayer._startSynchronization(protocol);
    });
  }
  
  /**
   * Start the ping timer
   */
  
  void _startSynchronizationTimer() {
    _pingTimer = new Timer.periodic(new Duration(seconds: 1), _ping);
  }
  
  /**
   * Get maximum ping across all remote players in this room every second
   */
  
  void _ping(Timer t) {
    // TODO(rh): Implement and use _room.send()? -> How do we get the channel label?
    // Send ping message to all players
    double maxPing = null;
    _maxPositiveTimeDifference = null;
    
    // TODO(rh): Should we use this?
    // room.sendToProtocol('synchronization', {'ping': window.performance.now()});
    
    _pingablePlayers.forEach((R remotePlayer, JsonProtocol protocol) {
      protocol.send({'ping': window.performance.now()});
      
      // get maximum difference
      // 
      if(remotePlayer.timeDifference > 0 && (_maxPositiveTimeDifference == null || remotePlayer.timeDifference > _maxPositiveTimeDifference)) {
        _maxPositiveTimeDifference = remotePlayer.timeDifference;
      }
      
      // ping might be null at first run
      if(remotePlayer.ping != null && (maxPing == null || remotePlayer.ping > maxPing)) {
        maxPing = remotePlayer.ping;
      }
    });
    
    if(maxPing != null) {
      if(_maxPing == null || maxPing > _maxPing) {
        _maxPing = maxPing;
      } else {
        _maxPing = _maxPing * .5 + maxPing * .5;
      }
      querySelector('#maxping').text = '$_maxPing';
      querySelector('#maxdifference').text = '$_maxPositiveTimeDifference';
      // TODO(rh): Should we provide an onMaxPing stream?
      // print('MaxPing: $_maxPing');
    }
  }
  
  void _synchronizeMessage(double time, dynamic message) {
    _messageQueue.add(time, message);
  }
  
  void synchronizeMessage(dynamic message) {
    // print('[$this] synchronizeMessage: $message');
    room.sendToProtocol('game', message);
    // Delay message locally
    _synchronizeMessage(message['time'], message);
  }
  
  void tick(double localTime) {
    double globalTime = localTime + timeDifferenceToMaster;
    // If there are messages in the queue
    // Deliver all messages that have smaller or equal global time
    while(!_messageQueue.isEmpty && _messageQueue.queue.firstKey() <= globalTime) {
      _onSynchronizedMessageController.add(_messageQueue.poll());
    }
    
    // print('[$this] tick@$localTime');
  }
}