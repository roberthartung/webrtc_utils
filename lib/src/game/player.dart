/**
 * Player part of the game library. Provides different types of players:
 * 
 * [Player] is the basic class that all players extend from. Then there are
 * [LocalPlayer]s and [RemotePlayer]s where the local player is the one using
 * the local browser and the remote player is any other player in the game. The
 * main difference is that the remote player will have a reference to a [Peer] object.
 * 
 * For the synchronized version of a game there are the corresponding classes
 * called [SynchronizedLocalPlayer] and [SynchronizedRemotePlayer].
 */

part of webrtc_utils.game;

/**
 * A mixin to give [Player]s a name
 */

/*
abstract class NamedPlayer {
  String get name;
}
*/

/**
 * A general player in the game that belongs to a room and has an id
 */

abstract class Player<R extends GameRoom> {
  /**
   * The room this player belongs to
   */

  final R room;

  /**
   * The id assigned by the signaling server.
   * 
   * NOTE: The id might be the same across more than one room if a
   * client joins more than one room.
   */

  final int id;

  /**
   * Getter to check if the player is local
   */

  bool get isLocal => this is LocalPlayer;

  /**
   * Constructor
   */

  Player._(this.room, this.id);
}

/**
 * Local version of the player
 */

abstract class LocalPlayer<R extends GameRoom> extends Player<R> {
  LocalPlayer(R room, int id) : super._(room, id);
}

/**
 * A remote player that will use a [Peer] and we will automatically create a
 * [RtcDataChannel] using the label 'game'.
 */

abstract class RemotePlayer<R extends GameRoom, P extends ProtocolPeer, C extends DataChannelProtocol>
    extends Player<R> {
  /**
   * The peer connection to this player
   */

  final P peer;

  /**
   * Internal completer
   */

  Completer<C> _gameChannelCompleter = new Completer();

  C _gameProtocol;

  Stream get onGameMessage => _onGameMessageController.stream;
  StreamController _onGameMessageController = new StreamController.broadcast();

  RemotePlayer(R room, P peer)
      : super._(room, peer.id),
        this.peer = peer {
    peer.onProtocol
        .firstWhere((DataChannelProtocol protocol) => protocol.channel.label == 'game')
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

/**
 * Basic class for the local and remote synchronized player
 */

abstract class SynchronizedPlayer {
  SynchronizedGameRoom get room;
  
  /**
   * The message queue holding on to the messages until the point in time is reached.
   */

  MessageQueue _messageQueue = new MessageQueue();

  /**
   * Method that gets called at a fixed rate that can be configured using 
   * [SynchronizedP2PGame.targetTickRate] which is set in the constructor
   */
  
  void tick(int tick) {
    while(!_messageQueue.isEmpty && _messageQueue.peekKey() < tick) {
      print('[$this] Dropped delayed messages: ${_messageQueue.peekKey()} < $tick');
      _messageQueue.poll();
    }
    
    if(!_messageQueue.isEmpty && _messageQueue.peekKey() == tick) {
      _messageQueue.poll().forEach((message) {
        handleMessage(message);
      });
    }
  }
  
  /**
   * Internally synchronizes a message. This gets called either directly via the 
   * rooms [synchronizeMessage] method or by the remote player if a message is
   * received from the remote peer.
   */
  
  // void _synchronizeMessage(SynchronizedGameMessage message);
  
  /**
   * Synchronizes a message for this player
   */
  
  void _synchronizeMessage(SynchronizedGameMessage message) {
    if (!room._isSynchronized) {
      throw new StateError("Room is not synchronized. Unable to synchronize message $message for $this");
    }
    // window.performance.now() + gameRoom.maxPing * 2
    // TODO(rh): (globalTime -> ticks) + (maxPing * 2 -> ticks)
    // room.globalTime + message.tick
    _messageQueue.add(room.globalTick + message.tick, message);
  }
  
  /**
   * Handle a SynchronizedMessage
   */
  
  void handleMessage(SynchronizedGameMessage message);
}

/**
 * Basic class for a synchronized version of a remote player.
 * 
 * The generic type is the GameProtocol type you are using
 */

abstract class SynchronizedRemotePlayer<P extends DataChannelProtocol>
    extends RemotePlayer<SynchronizedGameRoom, ProtocolPeer, P>
    with SynchronizedPlayer {
      
  Completer<JsonProtocol> _synchronizationChannelCompleter = new Completer();

  JsonProtocol _synchronizationProtocol;
  
  double _timeDifference = null;
  double get timeDifference => _timeDifference;

  double _ping = null;
  double get ping => _ping;
  
  SynchronizedRemotePlayer(SynchronizedGameRoom room, ProtocolPeer peer)
      : super(room, peer) {
    // Wait for first protocol with correct label
    // then listen for messages on that protocol
 
    peer.onProtocol
        .firstWhere((DataChannelProtocol protocol) => protocol.channel.label == 'synchronization')
        .then((JsonProtocol protocol) {
      _synchronizationProtocol = protocol;
      _synchronizationChannelCompleter.complete(_synchronizationProtocol);
      _synchronizationChannelCompleter = null;
      // Send two ping messages so we get 
      protocol.send({'ping': window.performance.now()});
      protocol.send({'ping': window.performance.now()});
      // Pipe messages from game protocol to game message stream
      protocol.onMessage.listen((Object message) =>_onSynchronizationProtocolMessage(protocol, message));
    });
    
    // Get game channel (label: game) from player and listen for messages
    // If a message is received, it will be synchronized by putting it into
    // this players message queue
    getGameChannel().then((P gameChannel) {
      // Sub ping from time because it passed over network
      // _synchronizeMessage(message['time'] - remotePlayer.ping, message)
      // TODO(rh): Substract ping!!
      gameChannel.onMessage.listen((SynchronizedGameMessage message) =>
          _messageQueue.add(room.globalTick + message.tick, message));
    });
  }
  
  /**
   * Received a message from the synchronization channel
   */

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
  
  /**
   * Can be called to get a Future that completes when the synchronization
   * channel is initialized and opened (meaning ready to take messages).
   */
  
  Future<JsonProtocol> getSynchronizationChannel() {
    if (_synchronizationChannelCompleter == null) {
      return new Future.value(_synchronizationProtocol);
    }

    return _synchronizationChannelCompleter.future;
  }
}

/**
 * Basic class for the synchronized player
 */

abstract class SynchronizedLocalPlayer extends LocalPlayer<SynchronizedGameRoom>
    with SynchronizedPlayer {

  /**
   * When executing events locally, they are scheduled with a delay
   */

  SynchronizedLocalPlayer(SynchronizedGameRoom room, int id) : super(room, id) {
    
  }
}