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
  
  ProtocolRoom get room => _room;
  final ProtocolRoom _room;
  
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
    
    // If Player was game owner
    if(_gameOwner == player) {
      _gameOwner = null;
      _getGameOwner();
    }
  }
  
  /**
   * Creates the [LocalPlayer] object using the generic [L] parameter
   */
  
  // L createLocalPlayer(int localId);
  
  /**
   * Creates the [RemotePlayer] object using the generic [R] parameter
   */
  
  // R createRemotePlayer(Peer peer);
}

/**
 * Synchronized version of a game room
 */

class SynchronizedGameRoom<G extends SynchronizedP2PGame, L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer> extends GameRoom<G,L,R> {
  Timer _pingTimer = null;
  
  double get globalTime => isOwner ? window.performance.now() : window.performance.now();
  
  int _maxPing = null;
  
  int get maxPing => _maxPing;
  
  Map<R, JsonProtocol> _pingablePlayers = {};
  
  
  Stream get onSynchronizedMessage => _onSynchronizedMessageController.stream;
  StreamController _onSynchronizedMessageController = new StreamController.broadcast();
  
  /**
   * Constructor of the [SynchronizedGameRoom] class
   */
  
  SynchronizedGameRoom(G game, ProtocolRoom room) : super(game, room) {
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
    if(_pingTimer == null) {
      _startSynchronizationTimer();
    }

    print('[$this] Player $remotePlayer joined');
    remotePlayer.peer.onProtocol.listen((DataChannelProtocol protocol) {
      if (protocol is JsonProtocol && protocol.channel.label == 'synchronization') {
        _pingablePlayers[remotePlayer] = protocol;
        remotePlayer._startSynchronization(protocol);
      }
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
    double _maxPing = null;
    
    // TODO(rh): Should we use this?
    // room.sendToProtocol('synchronization', {'ping': window.performance.now()});
    
    _pingablePlayers.forEach((R remotePlayer, JsonProtocol protocol) {
      protocol.send({'ping': window.performance.now()});
      // ping might be null at first run
      if(remotePlayer.ping != null && (_maxPing == null || remotePlayer.ping > _maxPing)) {
        _maxPing = remotePlayer.ping;
      }
    });
    
    if(_maxPing != null) {
      // TODO(rh): Should we provide a onMaxPing stream?
      print('MaxPing: $_maxPing');
    }
  }
  
  void synchronizeMessage(dynamic message) {
    
  }
  
  void tick(double localTime) {
    print('[$this] tick@$localTime');
  }
}