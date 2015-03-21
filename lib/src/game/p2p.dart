part of webrtc_utils.game;

abstract class P2PGame extends WebSocketP2PClient {
  
  /**
   * Set if the LocalPlayer is the owner of the game (room)
   */
  
  bool get isOwner => _gameOwner;
  bool _gameOwner = false;
    
  /**
   * List of remote Players in the game
   */
  
  final Map<Peer, RemotePlayer> peerToPlayer = {};
  
  /**
   * List of all [Player]s in the game
   */
  
  final List<Player> players = [];
  
  /**
   * The local player instance
   */
  
  LocalPlayer get localPlayer => _localPlayer;
  LocalPlayer _localPlayer = null;
  
  Room get room => _room;
  Room _room;
  
  /**
   * Room's name
   */
  
  String _roomName;
  
  /**
   * Room's password
   */
  
  String _roomPassword;
  
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
   * Constructor, creates a new WebSocketP2PClient with the given WebSocket URL and rtcConfiguration
   */
 
  P2PGame(String webSocketUrl,
      Map rtcConfiguration
    )
    : super(webSocketUrl, rtcConfiguration) {
    onConnect.listen((int id) {
      
    });
    
    // TODO(rh): What happens when a player leaves / joins a room?
    onJoinRoom.listen((Room room) {
      _room = room;
      
      if(_localPlayer != null) {
        // TODO(rh): What's wrong then? Is this possible?
      }
      _localPlayer = createLocalPlayer(id);
      _playerJoined(_localPlayer);
      
      room.peers.forEach((Peer peer) {
        RemotePlayer player = createRemotePlayer(peer);
        peerToPlayer[peer] = player;
        _playerJoined(player);
      });
      
      room.onJoin.listen((Peer peer) {
        RemotePlayer player = createRemotePlayer(peer);
        peerToPlayer[peer] = player;
        _playerJoined(player);
      });
      
      room.onLeave.listen((Peer peer) {
        _playerLeft(peerToPlayer.remove(peer));
      });
    });
    
    // TODO(rh): Reset players list when onLeaveRoom event occurs
  }
  
  LocalPlayer createLocalPlayer(_localId) {
    return new LocalPlayer(this, id);
  }
  
  RemotePlayer createRemotePlayer(Peer peer) {
    return new RemotePlayer(this, peer);
  }
  
  void _playerJoined(Player player) {
    _onPlayerJoinStreamController.add(player);
    players.add(player);
  }
  
  void _playerLeft(Player player) {
    players.remove(player);
    _onPlayerLeaveStreamController.add(player);
  }
}