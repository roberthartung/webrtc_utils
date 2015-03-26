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
  
  Room get room => _room;
  final Room _room;
  
  GameRoom(this.game, this._room) {
    // TODO(rh): Should we use game.createLocalPlayer() here?
    _localPlayer = createLocalPlayer(game.id);
    _playerJoined(_localPlayer);
    _room.peers.forEach((Peer peer) {
      R player = createRemotePlayer(peer);
      peerToPlayer[peer] = player;
      _playerJoined(player);
    });
    // Initially get game owner, after this the owner only changes if the player leaves
    _getGameOwner();
    // When a new player joins
    _room.onPeerJoin.listen((Peer peer) {
      // TODO(rh): Should we use game.createRemotePlayer() here?
      R player = createRemotePlayer(peer);
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
  
  L createLocalPlayer(int localId);
  
  /**
   * Creates the [RemotePlayer] object using the generic [R] parameter
   */
  
  R createRemotePlayer(Peer peer);
}

/**
 * Synchronized version of a game room
 */

abstract class SynchronizedGameRoom<G extends SynchronizedP2PGame, L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer> extends GameRoom<G,L,R> {
  Timer _pingTimer = null;
  
  int get globalTime => 0;
  
  Map<R, JsonProtocol> _pingablePlayers = {};
  
  /**
   * Constructor of the [SynchronizedGameRoom] class
   */
  
  SynchronizedGameRoom(G game, Room room) : super(game, room) {
    // If there are no remote players, wait for first player and start timer
    if(remotePlayers.length == 0) {
      onPlayerJoin.first.then((_) {
        _startSynchronizationTimer();
      });
    }
    // If there is at least one player, start synchronization timer immedeately
    else {
      _startSynchronizationTimer();
    }
    
    remotePlayers.forEach(_onPlayerJoined);
    // Create channel only for new players!
    onPlayerJoin.listen((R remotePlayer) {
      _onPlayerJoined(remotePlayer);
      remotePlayer.peer.createChannel('synchronization', {'protocol': 'json'});
    });
    
    onPlayerLeave.listen((R remotePlayer) {
      _pingablePlayers.remove(remotePlayer);
      
      if(_pingablePlayers.length == 0) {
        _pingTimer.cancel();
        _pingTimer = null;
      }
    });
  }
  
  void _onSynchronizationProtocolMessage(JsonProtocol protocol, Map data) {
    if(data.containsKey('ping')) {
      double diff = window.performance.now() - data['ping'];
      // if diff is <0 
      protocol.send({'pong': data['ping']});
      print('Diff: $diff');
    } else if(data.containsKey('pong')) {
      // Calculate ping
      double rtt = window.performance.now() - data['pong'];
      double ping = rtt/2;
      print('Ping: $ping');
    }
  }
  
  void _onPlayerJoined(R remotePlayer) {
    print('[$this] Player $remotePlayer joined');
    
    remotePlayer.peer.onChannel.listen((RtcDataChannel channel) {
      channel.onMessage.listen((MessageEvent ev) {
        print('Message: ${ev.data}');
      });
    });
    
    remotePlayer.peer.onProtocol.listen((DataChannelProtocol protocol) {
      if(protocol is JsonProtocol && protocol.channel.label == 'synchronization') {
        _pingablePlayers[remotePlayer] = protocol;
        protocol.onMessage.listen((Object message) => _onSynchronizationProtocolMessage(protocol, message));
      }
    });
  }
  
  void _startSynchronizationTimer() {
    _pingTimer = new Timer.periodic(new Duration(seconds: 1), _ping);
  }
  
  void _ping(Timer t) {
    // TODO(rh): Use _room.send()?
    // Send ping message to all players
    Map pingMessage = {'ping': window.performance.now()};
    _pingablePlayers.forEach((R remotePlayer, JsonProtocol protocol) {
      protocol.send(pingMessage);
    });
    /*remotePlayers.forEach((R remotePlayer) {
      // remotePlayer.peer.channels['synchronization'].send(pingMessage);
    });
    */
  }
}