/// NOTE: We do not extend [Room] because it uses an internal constructor.
///   Another good side effect is that we can hide the room from the user
///   So he cannot work on [PeerConnection]s directly.
part of webrtc_utils.game;

/// Interface for the GameRoom
abstract class GameRoom<G extends P2PGame, L extends LocalPlayer, R extends RemotePlayer, P extends Player> {
  /// The game this room belongs to
  G get game;

  /// Can be used to check if the localplayer is the game owner
  bool get isOwner;

  /// The owner of the game
  P get owner;

  /// The local Player
  ///
  /// TODO(rh): Should we support multiple local players?
  L get localPlayer;

  /// A class that is responsible for rendering the room
  GameRoomRenderer get renderer;

  /// The underlying room
  ProtocolPeerRoom get room;

  /// A list of all players already in the room.
  List<P> get players;

  /// List of remote players
  Iterable<R> get remotePlayers;

  /// Stream that informs about players that join
  ///
  /// Note: This does not include the initial list of players. Use the [players]
  /// getter for an initial list of players
  Stream<R> get onPlayerJoin;

  /// Stream that informs about players that leave the room
  Stream<R> get onPlayerLeave;

  /// Stream that notifies about changes in the game owner.
  ///
  /// Note: Does not fire for initial game owner
  Stream<P> get onGameOwnerChanged;

  /// Starts the animation loop in this room
  void startAnimation();

  /// Stops the animation
  void stopAnimation();
}

/// An interface for a synchronized version of a [GameRoom]
/// It provides mechanisms to create a global time (ticks) across all players.
///
/// The [synchronizeMessage] method can be used to synchronize a message across
/// all players.
///
/// Whenever a player joins the [onSynchronizationStateChanged] event will be
/// fired with to notify that the game is not in sync any more (argument is
/// false in this case). When the ping and global time was exchanged the event
/// will fire once more.
abstract class SynchronizedGameRoom<G extends SynchronizedP2PGame, L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer, P extends Player>
    extends GameRoom<G, L, R, P> {
  /// The global time that is [window.performance.now()] + [timeDifferenceToMaster]
  double get globalTime;

  /// An int representing the global tick
  int get globalTick;

  /// Max ping within the last second across all players
  num get maxPing;

  /// The time difference to the master (game owner)
  num get timeDifferenceToMaster;

  /// Stream that notifies about changes in the synchronization state (e.g. if
  /// a player joins of leaves the room). This can be used to disable buttons
  /// so a game can not be started while synchronization is in progress.
  Stream get onSynchronizationStateChanged;

  /// Getter to check if this room is synchronized
  bool get isSynchronized;

  /// Synchronizes a message across all players with a delay of [tickDelay]
  /// ticks.
  ///
  /// Note: The number of ticks per second can be configured using the getter of
  /// your [GameRoomRenderer]
  void synchronizeMessage(GameMessage message, {int tickDelay: 1});
}

/// A room that holds [Player]s instead of [_Peer]
class _GameRoom<G extends _P2PGame, L extends LocalPlayer, R extends RemotePlayer, P extends Player>
    implements GameRoom<G, L, R, P> {
  /// Indicator if we're still in the animation loop
  var _animationLoop = true;

  /// Internal variable
  GameRoomRenderer _gameRoomRenderer;

  /// Returns the [GameRoomRenderer] instance for this room
  GameRoomRenderer get renderer => _gameRoomRenderer;

  /// Can be used to get the [P2PGame] this room belongs to
  final G game;

  /// Set if the LocalPlayer is the owner of the game (room)
  bool get isOwner => _gameOwner == localPlayer;
  P _gameOwner = null;
  P get owner => _gameOwner;

  /// List of remote Players in the game
  final Map<Peer, R> peerToPlayer = {};

  /// List of all [P]s in the game
  final List<P> players = [];

  /// A getter to filter the players list for remote players only (used by some mixins)
  ///
  /// TODO(rh): Can we omit the 'as Iterable<R>' somehow?
  /// TODO(rh): When the generic type is omitted it will be dynamic so this check will fail
  Iterable<R> get remotePlayers =>
      // (p is R)
      players.where((P p) => !p.isLocal) as Iterable<R>;

  /// The local player instance
  L get localPlayer => _localPlayer;
  L _localPlayer = null;

  /// Stream of remote players that joined the room
  Stream<R> get onPlayerJoin => _onPlayerJoinStreamController.stream;
  StreamController<R> _onPlayerJoinStreamController =
      new StreamController.broadcast();

  /// Stream of remote players that left the room
  Stream<R> get onPlayerLeave => _onPlayerLeaveStreamController.stream;
  StreamController<R> _onPlayerLeaveStreamController =
      new StreamController.broadcast();

  /// Stream of [P]s that become gameowner
  Stream<P> get onGameOwnerChanged =>
      _onGameOwnerChangedStreamController.stream;
  StreamController<P> _onGameOwnerChangedStreamController =
      new StreamController.broadcast();

  /// The room of this gameroom
  ProtocolPeerRoom get room => _room;
  final ProtocolPeerRoom _room;

  _GameRoom(this.game, this._room, GameRoomRendererFactory factory) {
    _gameRoomRenderer = factory.createRenderer(this);
    _room.peers.forEach((Peer peer) {
      // R player = createRemotePlayer(peer);
      R player = game.playerFactory.createRemotePlayer(this, peer);
      peerToPlayer[peer] = player;
      _playerJoined(player);
    });
    _localPlayer = game.playerFactory.createLocalPlayer(this, game.id);
    _playerJoined(_localPlayer);
    // Initially get game owner, after this the owner only changes if the player leaves
    _getGameOwner();
    // When a new player joins
    _room.onPeerJoin.listen((Peer peer) {
      R player = game.playerFactory.createRemotePlayer(this, peer);
      peerToPlayer[peer] = player;
      _playerJoined(player);
      // Create channel here and not in RemotePlayer constructor because we only want create channels
      // to be created that joined after us!
      peer.createChannel('game', {'protocol': 'game'});
    });
    // When a player leaves
    room.onPeerLeave.listen((Peer peer) {
      _playerLeft(peerToPlayer.remove(peer));
    });
  }

  /// Get game owner from all players (smalles id)
  void _getGameOwner() {
    // Get new owner
    players.forEach((Player player) {
      _checkGameOwner(player);
    });
    _onGameOwnerChangedStreamController.add(_gameOwner);
  }

  void _checkGameOwner(Player player) {
    if (_gameOwner == null || player.id < _gameOwner.id) {
      _gameOwner = player;
    }
  }

  /// Called for every player (both local and remote players) that joined the room
  void _playerJoined(Player player) {
    players.add(player);
    _onPlayerJoinStreamController.add(player);
  }

  /// Called for each player, that leaves a room
  void _playerLeft(Player player) {
    players.remove(player);
    // Fire this event before new game owner election to make sure an event handler
    // can compare the current game owner with the player that left the game
    _onPlayerLeaveStreamController.add(player);

    // If Player was game owner reset gameowner and elect new one
    if (_gameOwner == player) {
      _gameOwner = null;
      _getGameOwner();
    }
  }

  /// Start animation in all rooms
  void startAnimation() {
    // TODO(rh): Use the current time to calculate an offset!
    _animationLoop = true;
    window.animationFrame.then(_animationFrame);
  }

  /// Stop animation in all rooms
  void stopAnimation() {
    _animationLoop = false;
  }

  /// This is the callback for the [window.animationFrame]. The only argument is a
  /// high precision timestamp that we have to synchronize for each [SynchronizedGameRoom]
  /// seperately!
  void _animationFrame(num localTime) {
    _gameRoomRenderer.render();
    if (_animationLoop) {
      window.animationFrame.then(_animationFrame);
    }
  }
}

/// Synchronized version of a game room. The gameroom will send a 'ping' message to all
/// remote players every 1 second.
class _SynchronizedGameRoom<G extends _SynchronizedP2PGame, L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer>
    extends _GameRoom<G, L, R, Player>
    implements SynchronizedGameRoom<G, L, R, Player> {

  /// Timer for this room that seconds a ping every second
  Timer _pingTimer = null;

  /// List of players that have successfully opened the game channel
  Map<R, JsonProtocol> _pingablePlayers = {};

  /// Getter for the globalTime of this room
  double get globalTime => isOwner
      ? window.performance.now()
      : window.performance.now() + timeDifferenceToMaster;

  /// Getter that returns the current global tick
  int get globalTick =>
      globalTime ~/ (1000.0 / _gameRoomRenderer.targetTickRate);

  /// Internal variable for holding the maximum ping. The maximum ping will be adjusted
  /// every second by taking 50% of the old maximum ping and 50% of the new maximum ping,
  /// but only if the new maximum ping is lower than the current maximum ping. This means:
  ///
  /// If there is a spike in the ping of one player this will be the new maximum. Afterwards
  /// the ping will be reduced step by step. This is to make sure that messages will be delayed
  /// long enough.
  num _maxPing = null;

  /// Public getter
  num get maxPing => _maxPing == null ? 0 : _maxPing;

  /// Internal
  num _maxPositiveTimeDifference = null;
  num get timeDifferenceToMaster =>
      _maxPositiveTimeDifference == null ? 0 : _maxPositiveTimeDifference;

  /// Stream of events that indicates that this room is synchronized across all players
  Stream get onSynchronizationStateChanged =>
      _onSynchronizationStateChangedController.stream;

  /// Message for controller for [onSynchronized] stream
  StreamController _onSynchronizationStateChangedController =
      new StreamController.broadcast();

  /// Last tick that was delivered to the application
  ///
  /// TODO(rh): correct initialization from onSynchronized event
  int _lastDeliveredTick = 0;

  bool get isSynchronized => _isSynchronized;
  bool _isSynchronized = true;

  /// Constructor of the [SynchronizedGameRoom] class
  _SynchronizedGameRoom(G game, ProtocolPeerRoom room,
      GameRoomRendererFactory gameRoomRendererFactory)
      : super(game, room, gameRoomRendererFactory) {
    // Loop through existing players in the channel
    remotePlayers.forEach(_onPlayerJoined);
    onPlayerJoin.listen((R remotePlayer) {
      _onPlayerJoined(remotePlayer);
      // Create channel only for players that joined after us.
      remotePlayer.peer.createChannel('synchronization', {'protocol': 'json'});
    });

    // Remove Player from list and cancel timer if there are no more remote players
    onPlayerLeave.listen((R remotePlayer) {
      _pingablePlayers.remove(remotePlayer);
      if (_pingablePlayers.length == 0) {
        _pingTimer.cancel();
        _pingTimer = null;
      }
    });
  }

  /// A RemotePlayer [R] joined (existing ones and new ones!)
  ///
  /// Changes synchronization state to false if needed
  void _onPlayerJoined(R remotePlayer) {
    print('Player joined: $remotePlayer');
    // Whenever a new remote player joins make sure
    if (isSynchronized) {
      _isSynchronized = false;
      _onSynchronizationStateChangedController.add(isSynchronized);
    }

    remotePlayer.getSynchronizationChannel().then((JsonProtocol protocol) {
      _pingablePlayers[remotePlayer] = protocol;
    });

    _startSynchronizationTimer();
  }

  /// Starts the ping timer if it hasn't been started yet
  void _startSynchronizationTimer() {
    if (_pingTimer == null) {
      _pingTimer = new Timer.periodic(new Duration(seconds: 1), _ping);
    }
  }

  /// Get maximum ping across all remote players in this room every second
  ///
  /// If we receive a ping from all players and we can
  void _ping(Timer t) {
    // Local variable to hold the ping of all local players
    double maxPing = null;
    _maxPositiveTimeDifference = null;

    // counter to check if any player is not synchronized
    int numOfPlayersOutOfSync = 0;

    // Loop through players and
    _pingablePlayers.forEach((R remotePlayer, JsonProtocol protocol) {
      protocol.send({'ping': window.performance.now()});

      // Difference in time
      if (remotePlayer.timeDifference != null) {
        if (remotePlayer.timeDifference > 0 &&
            (_maxPositiveTimeDifference == null ||
                remotePlayer.timeDifference > _maxPositiveTimeDifference)) {
          _maxPositiveTimeDifference = remotePlayer.timeDifference;
        }
      } else {
        // If we don't know the difference of this player he is not in sync!
        numOfPlayersOutOfSync++;
      }

      // ping might be null at first run, thus set maxPing if its null or it is
      // higher
      if (remotePlayer.ping != null &&
          (maxPing == null || remotePlayer.ping > maxPing)) {
        maxPing = remotePlayer.ping;
      }
    });

    // Take the average max ping
    if (maxPing != null) {
      if (_maxPing == null || maxPing > _maxPing) {
        _maxPing = maxPing;
      } else {
        // TODO(rh): Do we need this?
        _maxPing = _maxPing * .5 + maxPing * .5;
      }

      // print('[$this] _maxPing: $_maxPing $globalTime');
      // TODO(rh): Should we provide an onMaxPing stream?
    }

    // Fire the synchronization event
    if (numOfPlayersOutOfSync == 0) {
      if (!isSynchronized) {
        _isSynchronized = true;
        _onSynchronizationStateChangedController.add(isSynchronized);
      }
    }
    // Note: The event with "false" as an argument will be fired when a [Player]
    //   joins the room.
  }

  /// Synchronizes a [GameMessage] across all players in this room and optionally
  /// delays it by [tickDelay] ticks. The [GameMessage] will be packed into a
  /// [SynchronizedGameMessage] and send to all remote players and the local player
  ///
  /// The targetTick will be
  ///      [globalTime] + 2/// [maxPing] to make
  /// to make sure we delay long enough. Then we can convert this time to
  /// globalTicks and add the optional [tickDelay].
  void synchronizeMessage(GameMessage message, {int tickDelay: 1}) {
    if (tickDelay < 1) {
      throw new ArgumentError("tickDelay cannnot less than 1!");
    }
    // All messages will always be delayed by two times the ping to make sure
    // small differences don't have an effect on the synchronization.
    double targetTime = (globalTime + 2 * maxPing);
    // Convert time to ticks and add tick delay
    int targetTick =
        targetTime ~/ (1000.0 / _gameRoomRenderer.targetTickRate) + tickDelay;
    SynchronizedGameMessage sm =
        new SynchronizedGameMessage(targetTick, message);
    // Send message to all remote players
    room.sendToProtocol('game', sm);
    // Queue message in local player
    (localPlayer as DefaultSynchronizedPlayer)._synchronizeMessage(sm);
  }

  /// Called by the [SynchronizedP2PGame], this method synchronizes and delivers
  /// messages in the queue and advances in time
  void _synchronize(double localTime) {
    // convert local to global time
    double globalTime = localTime + timeDifferenceToMaster;
    // get last tick
    int lastTick = globalTime ~/ (1000 / _gameRoomRenderer.targetTickRate);
    // generate ticks

    for (int t = _lastDeliveredTick + 1; t <= lastTick; t++) {
      // If t == next key in message queue, get list of messages and deliver each message for this tick.
      // Deliver messages for each player in the game independently

      renderer.tick(t);

      /*
      players.forEach((Player player) {
        (player as SynchronizedPlayer).tick(t);
      });
      */
      // We do not use the [players] list because it is not typed to SynchronizedPlayer
      // TODO(rh): When we can use mixins that extend from other classes fix this!
      // print('localPlayer: $localPlayer $t');
      // print('localPlayer: $localPlayer');
      localPlayer.tick(t);
      remotePlayers.forEach((R remotePlayer) {
        remotePlayer.tick(t);
      });
    }

    _lastDeliveredTick = lastTick;
  }

  void _animationFrame(num localTime) {
    _synchronize(localTime);
    super._animationFrame(localTime);
  }
}
