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
   * List of gamerooms the client joined
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
    onJoinRoom.listen((PeerRoom room) {
      // Instantiate game room wrapper, add to list and fire event
      G gameRoom = createGameRoom(room);
      gameRooms.add(gameRoom);
      _onGameRoomCreatedController.add(gameRoom);
    });
    
    // TODO(rh): When disconnecting cleanup rooms?
    onDisconnect.listen((int reason) {
      // print('P2PGame disconnected from signaling channel. Reason: $reason');
      // cleanup();
    });
  }
  
  GameRoom createGameRoom(PeerRoom room) {
    return new GameRoom<P2PGame, L,R, Player>._(this, room);
  }
  
  L createLocalPlayer(GameRoom room, int id);
  
  R createRemotePlayer(GameRoom room, ProtocolPeer peer);
}

/**
 * A synchronized game implementation
 */

abstract class SynchronizedP2PGame<L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer> extends P2PGame<L, R, SynchronizedGameRoom> {

  /**
   * An integer representing the target tick rate (FPS) for the game.
   * 
   * [window.animationFrame] might not generate accurate 60 fps, thus we can
   * only rely on the time passed to the callback.
   */
      
  final int targetTickRate;
  
  /**
   * Indicator if we're still in the loop
   */
  
  var _animationLoop = true;
  
  /**
   * Constructor that passes the url and rtcConfiguration to the [P2PGame],
   * it takes an optionally, named parameter [targetTickRate] that defines
   * the target tick rate of all rooms of this game.
   */
  
  SynchronizedP2PGame(String webSocketUrl, Map rtcConfiguration, {int targetTickRate: 60})
      : super(webSocketUrl, rtcConfiguration),
      this.targetTickRate = targetTickRate;

  /**
   * Start animation in all rooms
   */
  
  void startAnimation() {
    _animationLoop = true;
    window.animationFrame.then(_animationFrame);
  }
  
  /**
   * Stop animation in all rooms
   */
  
  void stopAnimation() {
    _animationLoop = false;
  }
  
  /**
   * This is the callback for the [window.animationFrame]. The only argument is a
   * high precision timestamp that we have to synchronize for each [SynchronizedGameRoom]
   * seperately!
   */
  
  void _animationFrame(num localTime) {
    // This time is local, but the same for all rooms
    // synchronize each room and render game afterwards
    gameRooms.forEach((SynchronizedGameRoom room) {
      room._synchronize(localTime);
    });

    render();
    
    if(_animationLoop) {
      window.animationFrame.then(_animationFrame);
    }
  }
  
  /**
   * Method to be implemeneted by the actual application that is called the browser's
   * frame rate for [window.animationFrame]. Ticks and messages will be delivered before.
   * 
   * Ticks will be delivered by the .tick method of the [SynchronizedPlayer]s. Messages will be
   * delivered by a sync stream.
   */
  
  void render();
  
  /**
   * Overrides method from [P2PGame] and creates a synchronized room instead.
   */
  
  @override
  SynchronizedGameRoom createGameRoom(PeerRoom room) {
    return new SynchronizedGameRoom<SynchronizedP2PGame, L, R>._(this, room);
  }
}