/**
 * NOTE: We do not extend [Room] because it uses an internal constructor.
 *    Another good side effect is that we can hide the room from the user
 *    So he cannot work on [PeerConnection]s directly.
 */

part of webrtc_utils.game;

/**
 * A room that holds [Player]s instead of [Peer]
 */

class GameRoom<G extends P2PGame, L extends LocalPlayer, R extends RemotePlayer, P extends Player> {
  final G game;
  
  /**
   * Set if the LocalPlayer is the owner of the game (room)
   */
  
  bool get isOwner => _gameOwner == localPlayer;
  P _gameOwner = null;
    
  /**
   * List of remote Players in the game
   */
  
  final Map<Peer, R> peerToPlayer = {};
  
  /**
   * List of all [P]s in the game
   */
  
  final List<P> players = [];
  
  /**
   * A getter to filter the players list for remote players only (used by some mixins)
   * 
   * TODO(rh): Can we omit the 'as Iterable<R>' somehow?
   */
 
  Iterable<R> get remotePlayers => players.where((P p) => (p is R)) as Iterable<R>;
  
  /**
   * The local player instance
   */
  
  L get localPlayer => _localPlayer;
  L _localPlayer = null;
  
  /**
   * Stream of remote players that joined the room
   */
  
  Stream<R> get onPlayerJoin => _onPlayerJoinStreamController.stream;
  StreamController<R> _onPlayerJoinStreamController = new StreamController.broadcast();
  
  /**
   * Stream of remote players that left the room
   */
  
  Stream<R> get onPlayerLeave => _onPlayerLeaveStreamController.stream;
  StreamController<R> _onPlayerLeaveStreamController = new StreamController.broadcast();
  
  /**
   * Stream of [P]s that become gameowner
   */
  
  Stream<P> get onGameOwnerChanged => _onGameOwnerChangedStreamController.stream;
  StreamController<P> _onGameOwnerChangedStreamController = new StreamController.broadcast();
  
  /**
   * The room of this gameroom
   */
  
  ProtocolPeerRoom get room => _room;
  final ProtocolPeerRoom _room;
  
  GameRoom._(this.game, this._room) {
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
  
  SplayTreeMap<int, Queue<M>> queue = new SplayTreeMap();
  
  /**
   * Getter if this queue is empty
   */
  
  bool get isEmpty => queue.isEmpty;
  
  /**
   * Adds a message at the given point in time
   */
  
  void add(int time, M message) {
    queue.putIfAbsent(time, () => new Queue<M>()).add(message);
  }
  
  /**
   * Retrieve and remove the element, throws StateError if this queue is empty
   */
  
  Queue<M> poll() {
    if(queue.isEmpty) {
      throw new StateError("MessageQueue is empty");
    }
    
    return queue.remove(peekKey());
  }
  
  /**
   * Peeks at the next key, throws StateError if this queue is empty
   */
  
  int peekKey() {
    if(queue.isEmpty) {
      throw new StateError("MessageQueue is empty");
    }
    
    return queue.firstKey();
  }
}

/**
 * Synchronized version of a game room. The gameroom will send a 'ping' message to all
 * remote players every 1 second. 
 */

class SynchronizedGameRoom<G extends SynchronizedP2PGame, L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer> extends GameRoom<G,L,R,Player> {
  /**
   * Timer for this room that seconds a ping every second
   */
  
  Timer _pingTimer = null;
  
  /**
   * List of players that have successfully opened the game channel
   */
  
  Map<R, JsonProtocol> _pingablePlayers = {};
  
  /**
   * Getter for the globalTime of this room
   */
  
  double get globalTime => isOwner ? window.performance.now() : window.performance.now() + timeDifferenceToMaster;
  
  // TODO(rh)
  int get globalTick => globalTime ~/ (1000.0 / game.targetTickRate);
  
  /**
   * Internal variable for holding the maximum ping. The maximum ping will be adjusted
   * every second by taking 50% of the old maximum ping and 50% of the new maximum ping,
   * but only if the new maximum ping is lower than the current maximum ping. This means:
   * 
   * If there is a spike in the ping of one player this will be the new maximum. Afterwards
   * the ping will be reduced step by step. This is to make sure that messages will be delayed
   * long enough.
   */
  
  double _maxPing = null;
  
  /**
   * Public getter
   */
  
  double get maxPing => _maxPing == null ? 0 : _maxPing;
  
  /**
   * Internal 
   */
  
  num _maxPositiveTimeDifference = null;
  num get timeDifferenceToMaster => _maxPositiveTimeDifference == null ? 0 : _maxPositiveTimeDifference;
  
  /**
   * Stream of events that indicates that this room is synchronized across all players
   */
  
  Stream get onSynchronizationStateChanged => _onSynchronizationStateChangedController.stream;
  
  /**
   * Message for controller for [onSynchronized] stream
   */
  
  StreamController _onSynchronizationStateChangedController = new StreamController.broadcast();
  
  /**
   * Last tick that was delivered to the application
   * 
   * TODO(rh): correct initialization from onSynchronized event
   */
  
  int _lastDeliveredTick = 0;
  
  bool _isSynchronized = true;
  
  bool get isSynchronized => _isSynchronized;
  
  /**
   * Constructor of the [SynchronizedGameRoom] class
   */
  
  SynchronizedGameRoom._(G game, ProtocolPeerRoom room) : super._(game, room) {
    // Loop through existing players in the channel
    remotePlayers.forEach(_onPlayerJoined);
    onPlayerJoin.listen((R remotePlayer) {
      _onPlayerJoined(remotePlayer);
      // Create channel only for players that joined after us.
      remotePlayer.peer.createChannel('synchronization', {'protocol': 'json'});
    });
    
    // Remove Player from list and cancel timer if there are no more remote players
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
   * 
   * Changes synchronization state to false if needed
   */
  
  void _onPlayerJoined(R remotePlayer) {
    // Whenever a new remote player joins make sure
    if(_isSynchronized) {
      _isSynchronized = false;
      _onSynchronizationStateChangedController.add(_isSynchronized);
    }
    
    remotePlayer.getSynchronizationChannel().then((JsonProtocol protocol) {
      _pingablePlayers[remotePlayer] = protocol;
    });
    
    _startSynchronizationTimer();
  }
  
  /**
   * Starts the ping timer if it hasn't been started yet
   */
  
  void _startSynchronizationTimer() {
    if(_pingTimer == null) {
      _pingTimer = new Timer.periodic(new Duration(seconds: 1), _ping);
    }
  }
  
  /**
   * Get maximum ping across all remote players in this room every second
   * 
   * If we receive a ping from all players and we can 
   */
  
  void _ping(Timer t) {
    // Local variable to hold the ping of all local players
    double maxPing = null;
    _maxPositiveTimeDifference = null;
    
    int numOfPlayersOutOfSync = 0;
    
    // Loop through players and 
    _pingablePlayers.forEach((R remotePlayer, JsonProtocol protocol) {
      protocol.send({'ping': window.performance.now()});
      
      // Difference in time
      if(remotePlayer.timeDifference != null && remotePlayer.timeDifference > 0 && (_maxPositiveTimeDifference == null || remotePlayer.timeDifference > _maxPositiveTimeDifference)) {
        _maxPositiveTimeDifference = remotePlayer.timeDifference;
      } else {
        // If we don't know the difference of this player he is not in sync!
        numOfPlayersOutOfSync++;
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
      
      print('[$this] _maxPing: $_maxPing $globalTime');
      
      // TODO(rh): Should we provide an onMaxPing stream?
    }
    
    if(numOfPlayersOutOfSync == 0) {
      if(!_isSynchronized) {
        _isSynchronized = true;
        _onSynchronizationStateChangedController.add(_isSynchronized);
      }
    }
  }
  
  /**
   * Synchronizes a message across all players in this room
   */
  
  void synchronizeMessage(SynchronizedGameMessage message) {
    print('[$this] Synchronizing message $message');
    // Send message to all remote players
    room.sendToProtocol('game', message);
    // Queue message in local player
    print('[$this] Synchronize message locally for $localPlayer');
    (localPlayer as SynchronizedPlayer)._synchronizeMessage(message);
  }
  
  /**
   * Called by the [SynchronizedP2PGame], this method synchronizes and delivers
   * messages in the queue and advances in time
   */
  
  void _synchronize(double localTime) {
    // convert local to global time
    double globalTime = localTime + timeDifferenceToMaster;
    // get last tick
    int lastTick = globalTime ~/ (1000 / game.targetTickRate);
    // generate ticks
    
    for(int t=_lastDeliveredTick+1;t<=lastTick;t++) {
      // If t == next key in message queue, get list of messages and deliver each message for this tick.
      // Deliver messages for each player in the game independently
      /*
      players.forEach((Player player) {
        (player as SynchronizedPlayer).tick(t);
      });
      */
      // We do not use the [players] list because it is not typed to SynchronizedPlayer
      // TODO(rh): When we can use mixins that extend from other classes fix this!
      // print('localPlayer: $localPlayer $t');
      // print('localPlayer: $localPlayer');
      localPlayer.tick(t);
      remotePlayers.forEach((R remotePlayer) {
        remotePlayer.tick(t);
      });
    }
    
    _lastDeliveredTick = lastTick;
  }
}