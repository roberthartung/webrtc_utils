/// Player part of the game library. Provides different types of players:
///
/// [Player] is the basic class that all players extend from. Then there are
/// [LocalPlayer]s and [RemotePlayer]s where the local player is the one using
/// the local browser and the remote player is any other player in the game. The
/// main difference is that the remote player will have a reference to a [Peer] object.
///
/// For the synchronized version of a game there are the corresponding classes
/// called [SynchronizedLocalPlayer] and [SynchronizedRemotePlayer].
part of webrtc_utils.game;

/*
/// A mixin to give [Player]s a name
abstract class NamedPlayer {
  String get name;
}
*/

/// General interface of any player in the game
abstract class Player<R extends GameRoom> {
  /// Returns the room for this player
  R get room;

  /// Returns the global id of this player
  int get id;

  /// Check if this player is local
  bool get isLocal;
}

///
abstract class LocalPlayer<R extends GameRoom> extends Player<R> {}

/// Interface of a remote player
abstract class RemotePlayer<R extends GameRoom, P extends ProtocolPeer, C extends DataChannelProtocol>
    extends Player<R> {
  /// Stream of game messages
  Stream get onGameMessage;

  /// Returns the peer object
  /// TODO(rh): Do we need this?
  P get peer;

  /// A method to retrieve the game channel
  Future<C> getGameChannel();
}

/// Interface for each synchronized player in the game
abstract class SynchronizedPlayer {
  /// Getter method to retrieve the room
  SynchronizedGameRoom get room;

  /// Called by the [SynchronizedGameRoom] for each step (tick).
  void tick(int tick);

  /// Called by a [SynchronizedGameRoom] after a message that has been passed to
  /// [SynchronizedGameRoom.synchronizeMessage] has been synchronized across
  /// all players.
  void handleMessage(GameMessage message);
}

/// Interface for a local player in a synchronized game
abstract class SynchronizedLocalPlayer extends LocalPlayer<SynchronizedGameRoom>
    with SynchronizedPlayer {}

/// Interface for a synchronized remote player
abstract class SynchronizedRemotePlayer<C extends DataChannelProtocol>
    extends RemotePlayer<SynchronizedGameRoom, ProtocolPeer, C>
    with SynchronizedPlayer {
  /// Returns the difference in time between the local time and the remote's
  /// player time
  num get timeDifference;

  /// Returns the ping to this player
  num get ping;

  /// A method that can be used to retrieve the synchronization channel. It will
  /// return a [Future] that will have a [JsonProtocol] as an argument.
  Future<JsonProtocol> getSynchronizationChannel();
}

/// A general player in the game that belongs to a room and has an id
/// This is an implementation that the application might extend
abstract class DefaultPlayer<R extends GameRoom> {
  bool get isLocal => this is LocalPlayer;

  /// The room this player belongs to
  final R room;

  /// The id assigned by the signaling server.
  ///
  /// NOTE: The id might be the same across more than one room if a
  /// client joins more than one room.
  final int id;

  /// Constructor
  DefaultPlayer(this.room, this.id);
}

/// A remote player that will use a [_Peer] and we will automatically create a
/// [RtcDataChannel] using the label 'game'.
abstract class DefaultRemotePlayer<R extends GameRoom, P extends ProtocolPeer, C extends DataChannelProtocol>
    extends DefaultPlayer<R> implements RemotePlayer<R, P, C> {
  /// The peer connection to this player
  final P peer;

  /// Internal completer to notify all listeners that the game channel is now open
  Completer<C> _gameChannelCompleter = new Completer();

  /// Internal var holding the game protocol
  C _gameProtocol;

  /// Stream of messages from the game channel
  Stream get onGameMessage => _onGameMessageController.stream;
  StreamController _onGameMessageController = new StreamController.broadcast();

  /// Constructor
  DefaultRemotePlayer(R room, P peer)
      : super(room, peer.id),
        this.peer = peer {
    print('[$this] Peer: ${P}/${peer.runtimeType}');
    peer.onProtocol
        .firstWhere(
            (DataChannelProtocol protocol) => protocol.channel.label == 'game')
        .then((C protocol) {
      _gameProtocol = protocol;
      _gameChannelCompleter.complete(_gameProtocol);
      _gameChannelCompleter = null;
      // Pipe messages from game protocol to game message stream
      _onGameMessageController.addStream(_gameProtocol.onMessage);
    });
  }

  Future<C> getGameChannel() {
    if (_gameChannelCompleter == null) {
      return new Future.value(_gameProtocol);
    }

    return _gameChannelCompleter.future;
  }
}

/// Basic class for the local and remote synchronized player
abstract class DefaultSynchronizedPlayer implements SynchronizedPlayer {
  /// The message queue holding on to the messages until the point in time is reached.
  MessageQueue<GameMessage> _messageQueue = new MessageQueue<GameMessage>();

  /// Method that gets called at a fixed rate that can be configured using
  /// [SynchronizedP2PGame.targetTickRate] which is set in the constructor
  void tick(int tick) {
    while (!_messageQueue.isEmpty && _messageQueue.peekKey() < tick) {
      // print('[$this] Dropped delayed messages: ${_messageQueue.peekKey()} < $tick');
      _messageQueue.poll().forEach((message) {
        handleMessage(message);
      });
    }

    if (!_messageQueue.isEmpty && _messageQueue.peekKey() == tick) {
      _messageQueue.poll().forEach((message) {
        handleMessage(message);
      });
    }
  }

  /// Internally synchronizes a message. This gets called either directly via the
  /// rooms [synchronizeMessage] method or by the remote player if a message is
  /// received from the remote peer.
  void _synchronizeMessage(SynchronizedGameMessage message) {
    if (!room.isSynchronized) {
      throw new StateError(
          "Room is not synchronized. Unable to synchronize message $message for $this");
    }
    _messageQueue.add(message.tick, message.message);
  }
}

/// Basic class for a synchronized version of a remote player.
///
/// The generic type is the GameProtocol type you are using
abstract class DefaultSynchronizedRemotePlayer<P extends DataChannelProtocol>
    extends DefaultRemotePlayer<SynchronizedGameRoom, ProtocolPeer, P>
    with DefaultSynchronizedPlayer implements SynchronizedRemotePlayer<P> {
  Completer<JsonProtocol> _synchronizationChannelCompleter = new Completer();

  JsonProtocol _synchronizationProtocol;

  double _timeDifference = null;
  double get timeDifference => _timeDifference;

  double _ping = null;
  double get ping => _ping;

  DefaultSynchronizedRemotePlayer(SynchronizedGameRoom room, ProtocolPeer peer)
      : super(room, peer) {
    // Wait for first protocol with correct label
    // then listen for messages on that protocol

    peer.onProtocol
        .firstWhere((DataChannelProtocol protocol) =>
            protocol.channel.label == 'synchronization')
        .then((JsonProtocol protocol) {
      _synchronizationProtocol = protocol;
      _synchronizationChannelCompleter.complete(_synchronizationProtocol);
      _synchronizationChannelCompleter = null;
      // Send two ping messages so we get
      protocol.send({'ping': window.performance.now()});
      protocol.send({'ping': window.performance.now()});
      // Pipe messages from game protocol to game message stream
      protocol.onMessage.listen((Object message) =>
          _onSynchronizationProtocolMessage(protocol, message));
    });

    // Get game channel (label: game) from player and listen for messages
    // If a message is received, it will be synchronized by putting it into
    // this players message queue
    getGameChannel().then((P gameChannel) {
      gameChannel.onMessage.listen((SynchronizedGameMessage message) =>
          _messageQueue.add(message.tick, message.message));
    });
  }

  /// Received a message from the synchronization channel
  void _onSynchronizationProtocolMessage(JsonProtocol protocol, Map data) {
    if (data.containsKey('ping')) {
      // Send response message
      protocol.send({'pong': data['ping']});

      // When we receive a ping, we can use the timestamp in the ping message
      // to calculate the difference between the local time and the peer's time
      // because the messages take a few milliseconds to be delivered to us
      // we have to wait until we have a ping to actually calculate the
      // difference correctly
      if (ping != null) {
        // if positive, then we're behind this peer
        // add ping to time, because this makes it an additional shift in time
        _timeDifference = (data['ping'] + ping) - window.performance.now();
      }
    }
    // We received a ping message, so we can calculate the ping to this player
    else if (data.containsKey('pong')) {
      double rtt = window.performance.now() - data['pong'];
      if (_ping == null) {
        _ping = rtt / 2;
      } else {
        _ping = (rtt / 2) * .25 + _ping * .75;
      }
    }
  }

  /// Can be called to get a Future that completes when the synchronization
  /// channel is initialized and opened (meaning ready to take messages).
  Future<JsonProtocol> getSynchronizationChannel() {
    if (_synchronizationChannelCompleter == null) {
      return new Future.value(_synchronizationProtocol);
    }

    return _synchronizationChannelCompleter.future;
  }
}

/// Basic class for the synchronized player
abstract class DefaultSynchronizedLocalPlayer
    extends DefaultPlayer<SynchronizedGameRoom<_SynchronizedP2PGame, SynchronizedLocalPlayer, SynchronizedRemotePlayer, Player>>
    with DefaultSynchronizedPlayer implements SynchronizedLocalPlayer {

  /// When executing events locally, they are scheduled with a delay
  DefaultSynchronizedLocalPlayer(SynchronizedGameRoom room, int id)
      : super(room, id) {}
}

/// A Message Queue for the [SynchronizedGameRoom]
class MessageQueue<M> {
  /// Use a SplayTreeMap so we can sort by time
  SplayTreeMap<int, Queue<M>> queue = new SplayTreeMap();

  /// Getter if this queue is empty
  bool get isEmpty => queue.isEmpty;

  /// Adds a message at the given point in time
  void add(int time, M message) {
    queue.putIfAbsent(time, () => new Queue<M>()).add(message);
  }

  /// Retrieve and remove the element, throws StateError if this queue is empty
  Queue<M> poll() {
    if (queue.isEmpty) {
      throw new StateError("MessageQueue is empty");
    }

    return queue.remove(peekKey());
  }

  /// Peeks at the next key, throws StateError if this queue is empty
  int peekKey() {
    if (queue.isEmpty) {
      throw new StateError("MessageQueue is empty");
    }

    return queue.firstKey();
  }
}
