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

abstract class P2PGame<L extends LocalPlayer, R extends RemotePlayer> extends WebSocketProtocolP2PClient {
  /**
   * Constructor, creates a new WebSocketP2PClient with the given WebSocket URL and rtcConfiguration
   */
  
  P2PGame(String webSocketUrl,
      Map rtcConfiguration)
    : super(webSocketUrl, rtcConfiguration) {
    onJoinRoom.listen(createGameRoom);
    
    onDisconnect.listen((int reason) {
      print('P2PGame disconnected from signaling channel. Reason: $reason');
      // cleanup();
    });
  }
  
  GameRoom createGameRoom(Room room);/* {
    // return new GameRoom<P2PGame, L,R>(this, room);
  }*/
}