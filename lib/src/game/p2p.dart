part of webrtc_utils.game;

class P2PGame extends WebSocketP2PClient {
  /**
   * List of remote Players in the game
   */
  
  final Map<Peer, RemotePlayer> peerToPlayer = {};
  
  /**
   * List of all [Player]s in the game
   */
  
  List<Player> players = [];
  
  /**
   * The local player instance
   */
  
  LocalPlayer get localPlayer => _localPlayer;
  LocalPlayer _localPlayer = null;
  
  /**
   * Room's name
   */
  
  String _roomName;
  
  /**
   * Room's password
   */
  
  String _roomPassword;
  
  /**
   * Constructor, creates a new WebSocketP2PClient with the given WebSocket URL and rtcConfiguration
   */
 
  P2PGame(String webSocketUrl,
      Map rtcConfiguration
    )
    : super(webSocketUrl, rtcConfiguration);
}