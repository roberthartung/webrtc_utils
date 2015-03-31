part of webrtc_utils.game;

/**
 * Interface for the P2PGame class
 */

abstract class P2PGame<L extends LocalPlayer, R extends RemotePlayer, G extends GameRoom> {
  List<G> get gameRooms;
  Stream<G> get onGameRoomCreated;
  void setPlayerFactory(PlayerFactory factory);
}

/**
 * Interface for the P2PGame class
 */

abstract class SynchronizedP2PGame<L extends LocalPlayer, R extends RemotePlayer, G extends SynchronizedGameRoom>
  extends P2PGame<L,R, G> {
  int get targetTickRate;
  
  void startAnimation();
  
  void stopAnimation();
  
  /**
   * Method to be implemeneted by the actual application that is called the browser's
   * frame rate for [window.animationFrame]. Ticks and messages will be delivered before.
   * 
   * Ticks will be delivered by the .tick method of the [SynchronizedPlayer]s. Messages will be
   * delivered by a sync stream.
   */
  
  void render();
}

abstract class PlayerFactory<L extends LocalPlayer, R extends RemotePlayer> {
  L createLocalPlayer(GameRoom room, int id);
  
  R createRemotePlayer(GameRoom room, ProtocolPeer peer);
}

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

abstract class _P2PGame<L extends LocalPlayer, R extends RemotePlayer, G extends _GameRoom>
    extends WebSocketProtocolP2PClient
    implements P2PGame<L,R,G> {
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
   * Instance of a [PlayerFactory] that is used to create custom/application specific
   * player objects.
   */
  
  PlayerFactory playerFactory;
  
  /**
   * Constructor, creates a new WebSocketP2PClient with the given WebSocket URL and rtcConfiguration
   */
  
  _P2PGame(String webSocketUrl,
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
    return new _GameRoom<_P2PGame, L,R, Player>(this, room);
  }
  
  void setPlayerFactory(PlayerFactory f) {
    this.playerFactory = f;
  }
}

/**
 * A synchronized game implementation
 */

abstract class _SynchronizedP2PGame<L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer>
  extends _P2PGame<L, R, _SynchronizedGameRoom>
  implements SynchronizedP2PGame<L,R, _SynchronizedGameRoom> {

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
  
  _SynchronizedP2PGame(String webSocketUrl, Map rtcConfiguration, this.targetTickRate)
      : super(webSocketUrl, rtcConfiguration);

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
    gameRooms.forEach((_SynchronizedGameRoom room) {
      room._synchronize(localTime);
    });
    
    render();
    
    if(_animationLoop) {
      window.animationFrame.then(_animationFrame);
    }
  }
  
  /**
   * Overrides method from [P2PGame] and creates a synchronized room instead.
   */
  
  @override
  SynchronizedGameRoom createGameRoom(PeerRoom room) {
    return new _SynchronizedGameRoom<_SynchronizedP2PGame, L, R>(this, room);
  }
}

abstract class SynchronizedWebSocketP2PGame<L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer> extends _SynchronizedP2PGame<L,R> {
  SynchronizedWebSocketP2PGame(String webSocketUrl, Map rtcConfiguration, {int targetTickRate: 60}) : super(webSocketUrl, rtcConfiguration, targetTickRate);
}