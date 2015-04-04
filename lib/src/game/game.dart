part of webrtc_utils.game;

/// Interface for the P2PGame class
abstract class P2PGame<L extends LocalPlayer, R extends RemotePlayer, G extends GameRoom> /*extends ProtocolP2PClient*/ {
  /// List of game rooms of type [G]
  List<G> get gameRooms;

  /// Listen to this stream to get notified of new rooms that get created
  Stream<G> get onGameRoomCreated;

  /// Sets the [PlayerFactory] that will be called if we need to create a new
  /// [Player] object.
  void setPlayerFactory(PlayerFactory factory);

  /// Sets the [GameRoomRendererFactory] for this game. It is used to create a
  /// room specific [GameRoomRenderer]
  void setGameRoomRendererFactory(GameRoomRendererFactory<G> gameRoomRenderer);
}

/// Interface for the P2PGame class
abstract class SynchronizedP2PGame<L extends LocalPlayer, R extends RemotePlayer, G extends SynchronizedGameRoom>
    extends P2PGame<L, R, G> {
}

///
abstract class PlayerFactory<L extends LocalPlayer, R extends RemotePlayer> {
  /// Creates a local player using the [room] and the [id].
  ///
  /// Note: There will be no [ProtocolPeer] object because we don't have a
  /// P2PConnection to this user because its the local one
  L createLocalPlayer(GameRoom room, int id);

  /// Creates a remote player using the [room] and the [peer]
  R createRemotePlayer(GameRoom room, ProtocolPeer peer);
}

///
abstract class GameRoomRenderer<R extends GameRoom> {
  int get targetTickRate;

  void render();
}

///
abstract class GameRoomRendererFactory<R extends GameRoom> {
  GameRoomRenderer<R> createRenderer(R gameRoom);
}

/// An abstract, basic implementation of a peer2peer game
///
/// It handles the following functions:
/// * LocalPlayer/RemotePlayer
/// * List of all players
/// * Owner of the game (smallest id)
/// * Hides room information and events
abstract class _P2PGame<L extends LocalPlayer, R extends RemotePlayer, G extends _GameRoom>
    extends WebSocketProtocolP2PClient implements P2PGame<L, R, G> {
  /// List of gamerooms the client joined
  final List<G> gameRooms = [];

  GameRoomRendererFactory<G> _gameRoomRendererFactory;

  /// Stream of GameRooms [G] that have been created for every room
  Stream<G> get onGameRoomCreated => _onGameRoomCreatedController.stream;
  StreamController<G> _onGameRoomCreatedController =
      new StreamController.broadcast();

  /// Instance of a [PlayerFactory] that is used to create custom/application specific
  /// player objects.
  PlayerFactory playerFactory;

  /// Constructor, creates a new WebSocketP2PClient with the given WebSocket URL and rtcConfiguration
  _P2PGame(String webSocketUrl, Map rtcConfiguration)
      : super(webSocketUrl, rtcConfiguration) {
    onJoinRoom.listen((ProtocolPeerRoom room) {
      // Instantiate game room wrapper, add to list and fire event
      G gameRoom = _createGameRoom(room);
      gameRooms.add(gameRoom);
      _onGameRoomCreatedController.add(gameRoom);
    });

    // TODO(rh): When disconnecting cleanup rooms?
    onDisconnect.listen((int reason) {
      // print('P2PGame disconnected from signaling channel. Reason: $reason');
      // cleanup();
    });
  }

  /// Creates a game room
  GameRoom _createGameRoom(ProtocolPeerRoom room) {
    _GameRoom gameRoom = new _GameRoom<_P2PGame, L, R, Player>(this, room, _gameRoomRendererFactory);
    return gameRoom;
  }

  void setPlayerFactory(PlayerFactory f) {
    this.playerFactory = f;
  }

  void setGameRoomRendererFactory(GameRoomRendererFactory<G> gameRoomRendererFactory) {
    this._gameRoomRendererFactory = gameRoomRendererFactory;
  }
}

/// A synchronized game implementation
abstract class _SynchronizedP2PGame<L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer>
    extends _P2PGame<L, R, _SynchronizedGameRoom>
    implements SynchronizedP2PGame<L, R, _SynchronizedGameRoom> {
  /// Constructor that passes the url and rtcConfiguration to the [P2PGame],
  /// it takes an optionally, named parameter [targetTickRate] that defines
  /// the target tick rate of all rooms of this game.
  _SynchronizedP2PGame(
      String webSocketUrl, Map rtcConfiguration)
      : super(webSocketUrl, rtcConfiguration);

  /// Overrides method from [P2PGame] and creates a synchronized room instead.
  @override
  SynchronizedGameRoom _createGameRoom(ProtocolPeerRoom room) {
    _SynchronizedGameRoom gameRoom = new _SynchronizedGameRoom<_SynchronizedP2PGame, L, R>(this, room, _gameRoomRendererFactory);
    return gameRoom;
  }
}

class WebSocketP2PGame<L extends LocalPlayer, R extends RemotePlayer>
  extends _P2PGame<L, R, _GameRoom> {
    WebSocketP2PGame(String webSocketUrl, Map rtcConfiguration)
    : super(webSocketUrl, rtcConfiguration);
}

class SynchronizedWebSocketP2PGame<L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer>
    extends _SynchronizedP2PGame<L, R> implements SynchronizedP2PGame<L,R, _SynchronizedGameRoom> {
  SynchronizedWebSocketP2PGame(String webSocketUrl, Map rtcConfiguration)
      : super(webSocketUrl, rtcConfiguration);
}
