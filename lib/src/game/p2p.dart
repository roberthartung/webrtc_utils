part of webrtc_utils.game;

/**
 * An abstract, basic implementation of a peer2peer game
 * 
 * It handles the following functions:
 * - LocalPlayer/RemotePlayer
 * - List of all players
 * - Owner of the game (smallest id)
 * - Hides room information and events
 * - cleanup for disconnect/room change: override [cleanup] and call super.clean() if you want to extend
 */

abstract class P2PGame<L extends LocalPlayer, R extends RemotePlayer> extends WebSocketP2PClient {
  
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
   * The last room we joined
   */
  
  Room get room => _room;
  Room _room;
  
  /**
   * Stream of [Player]s that joined
   */
  
  Stream<Player> get onPlayerJoin => _onPlayerJoinStreamController.stream;
  StreamController<Player> _onPlayerJoinStreamController = new StreamController.broadcast();
  
  /**
   * Stream of [Player]s that left
   */
  
  Stream<Player> get onPlayerLeave => _onPlayerLeaveStreamController.stream;
  StreamController<Player> _onPlayerLeaveStreamController = new StreamController.broadcast();
  
  /**
   * Stream of [Player]s that become gameowner
   */
  
  Stream<Player> get onGameOwnerChanged => _onGameOwnerChangedStreamController.stream;
  StreamController<Player> _onGameOwnerChangedStreamController = new StreamController.broadcast();
  
  /**
   * Constructor, creates a new WebSocketP2PClient with the given WebSocket URL and rtcConfiguration
   */
 
  P2PGame(String webSocketUrl,
      Map rtcConfiguration
    )
    : super(webSocketUrl, rtcConfiguration) {
    onJoinRoom.listen((Room room) {
      _room = room;
      
      if(_localPlayer != null) {
        // TODO(rh): What's wrong then? Is this possible?
        // Maybe at reconnect? Then we should cleanup onDisconnect
      }
      _localPlayer = createLocalPlayer(id);
      _playerJoined(_localPlayer);
      
      room.peers.forEach((Peer peer) {
        R player = createRemotePlayer(peer);
        peerToPlayer[peer] = player;
        _playerJoined(player);
      });
      // Initially get game owner, after this the owner only changes if the player leaves
      _getGameOwner();
      // When a new player joins
      room.onJoin.listen((Peer peer) {
        R player = createRemotePlayer(peer);
        peerToPlayer[peer] = player;
        _playerJoined(player);
      });
      // When a player leaves
      room.onLeave.listen((Peer peer) {
        _playerLeft(peerToPlayer.remove(peer));
      });
    });
    
    onDisconnect.listen((int reason) {
      print('P2PGame disconnected from signaling channel. Reason: $reason');
      cleanup();
    });
    
    // TODO(rh): Reset players list when onLeaveRoom event occurs
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
    _room = null;
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