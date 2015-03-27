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

abstract class P2PGame<L extends LocalPlayer, R extends RemotePlayer, G extends GameRoom> extends WebSocketProtocolP2PClient {
  /**
   * List of 
   */
  
  final List<G> gameRooms = [];
  
  /**
   * Stream of GameRooms [G] that have been created for every room 
   */
  
  Stream<G> get onGameRoomCreated => _onGameRoomCreatedController.stream;
  StreamController<G> _onGameRoomCreatedController = new StreamController.broadcast();
  
  /**
   * Constructor, creates a new WebSocketP2PClient with the given WebSocket URL and rtcConfiguration
   */
  
  P2PGame(String webSocketUrl,
      Map rtcConfiguration)
    : super(webSocketUrl, rtcConfiguration) {
    onJoinRoom.listen((Room room) {
      G gameRoom = createGameRoom(room);
      gameRooms.add(gameRoom);
      _onGameRoomCreatedController.add(gameRoom);
    });
    
    // When disconnecting cleanup rooms?
    onDisconnect.listen((int reason) {
      // print('P2PGame disconnected from signaling channel. Reason: $reason');
      // cleanup();
    });
  }
  
  GameRoom createGameRoom(Room room);
  
  L createLocalPlayer(GameRoom room, int id);
  
  R createRemotePlayer(GameRoom room, ProtocolPeer peer);
  
  /* {
    // return new GameRoom<P2PGame, L,R>(this, room);
  }*/
}

abstract class SynchronizedP2PGame<L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer>
    extends P2PGame<L, R, SynchronizedGameRoom> {
  SynchronizedP2PGame(String webSocketUrl, Map rtcConfiguration)
      : super(webSocketUrl, rtcConfiguration);

  @override
  SynchronizedGameRoom createGameRoom(Room room) {
    return new SynchronizedGameRoom<SynchronizedP2PGame, L, R>(this, room);
  }
}
