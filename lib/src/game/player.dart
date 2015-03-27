/**
 * Player based classes for the game library
 */

part of webrtc_utils.game;

/**
 * A mixin to give [Player]s a name
 */

abstract class NamedPlayer {
  String get name;
}

/**
 * A Player in the game
 */

abstract class Player<R extends GameRoom> {
  final R room;
  
  final int id;
  
  bool get isLocal => this is LocalPlayer;
  
  //bool get isAlive;
  
  Player(this.room, this.id);
  
  void tick(double time);
}

/**
 * Local Player
 */

abstract class LocalPlayer<R extends GameRoom> extends Player<R> {
  LocalPlayer(R room, int id) : super(room, id);
}

/**
 * A remote player
 */

abstract class RemotePlayer<R extends GameRoom, P extends ProtocolPeer> extends Player<R> {
  /**
   * The peer connection to this player
   */
  
  final P peer;
  
  Completer<DataChannelProtocol> _gameChannelCompleter = new Completer();
  
  DataChannelProtocol _gameProtocol;
  
  Stream get onGameMessage => _onGameMessageController.stream;
  StreamController _onGameMessageController = new StreamController.broadcast();
  
  RemotePlayer(R room, P peer) : super(room, peer.id), this.peer = peer {
    // Create game channel for each remote player with protocol 'game'
    peer.onProtocol.firstWhere((DataChannelProtocol protocol) => protocol.channel.label == 'game').then((DataChannelProtocol protocol) {
      _gameProtocol = protocol;
      _gameChannelCompleter.complete(_gameProtocol);
      _gameChannelCompleter = null;
      // Pipe messages from game protocol to game message stream
      _onGameMessageController.addStream(_gameProtocol.onMessage);
    });
  }
  
  Future<DataChannelProtocol> getGameChannel() {
    if(_gameChannelCompleter == null) {
      return new Future.value(_gameProtocol);
    }
    
    return _gameChannelCompleter.future;
  }
}

abstract class SynchronizedRemotePlayer /*<R extends SynchronizedGameRoom>*/ extends RemotePlayer<SynchronizedGameRoom, ProtocolPeer> {
  SynchronizedRemotePlayer(SynchronizedGameRoom room, ProtocolPeer peer)
      : super(room, peer) {
    // Wait for synchronization protocol
    // TODO(rh): Can we cancel the subscription afterwards?
  }
  
  double _timeDifference = null;
  double get timeDifference => _timeDifference;
  
  double _ping = null;
  double get ping => _ping;
  
  void _startSynchronization(JsonProtocol protocol) {
    protocol.onMessage.listen((Object message) => _onSynchronizationProtocolMessage(protocol, message));
  }
  
  /**
   * Received a message from the synchronization channel
   */
  
  void _onSynchronizationProtocolMessage(JsonProtocol protocol, Map data) {
    if(data.containsKey('ping')) {
      _timeDifference = window.performance.now() - data['ping'];
      // if diff is smaller than "0"
      protocol.send({'pong': data['ping']});
    } else if(data.containsKey('pong')) {
      // Calculate ping
      double rtt = window.performance.now() - data['pong'];
      if(_ping == null) {
        _ping = rtt / 2;
      } else {
        _ping = (rtt / 2) * .5 + _ping * .5;
      }
    }
  }
}

abstract class SynchronizedLocalPlayer /*<R extends SynchronizedGameRoom>*/ extends LocalPlayer<SynchronizedGameRoom> {
  /**
   * When executing events locally, they are scheduled with a delay
   */
  
  SynchronizedLocalPlayer(SynchronizedGameRoom room, int id) : super(room, id) {
    
  }
}

/**
 * A Mixin that can be used to have a ready state within a player, use this for both the remote and local player
 */

abstract class ReadyPlayer {
  /**
   * Abstract getters for ready state
   */
  
  bool get _ready;
  bool get isReady => _ready;
  
  /**
   * Stream of bool values to identify if this player is ready or not
   */
  
  Stream<bool> get onReadyStateChanged => _readyStateChangedController.stream;
  StreamController<bool> _readyStateChangedController = new StreamController<bool>.broadcast();
}

/**
 * A mixin to have a ready state on the local player. use together with [ReadyPlayer]
 */

abstract class LocalReadyPlayer {
  /**
   * Internal ready state
   */
  
  bool _ready = false;
  
  /**
   * Abstract getter for the [P2PGame]
   */
  
  // P2PGame get game;
  
  GameRoom get room;
  
  /**
   * Abstract getter for [StreamController] of ready events 
   */
  
  StreamController<bool> get _readyStateChangedController;
  
  /**
   * Toggle internal ready state (good for use with a button)
   */
  
  void toggleReady() {
    setReady(!_ready);
  }
  
  /**
   * Sets the ready state
   */
  
  void setReady(bool ready) {
    if(_ready != ready) {
      _ready = ready;
      _readyStateChangedController.add(_ready);
      // We're local, so notify other players
      sendReadyState();
    }
  }
  
  /**
   * Sends local player's ready state to remote players
   */
  
  void sendReadyState() {
    // TODO(rh): Use broadcast send of room
    // game.send();
    /*
    game.remotePlayers.forEach((RemoteReadyPlayer remotePlayer) {
      remotePlayer.sendLocalReadyStatus(this);
    });
    */
  }
}

/**
 * A mixin to have a ready state on the remote player. use together with [ReadyPlayer]
 */

abstract class RemoteReadyPlayer {
  /**
   * Concrete ready state implementation
   */
  
  bool _ready = false;
  
  /**
   * Abstract getter
   */
  
  StreamController<bool> get _readyStateChangedController;
  
  /**
   * Toggle state
   */
  
  void toggleReady() {
    setReady(!_ready);
  }
  
  /**
   * Sets the ready state without sending it to other players
   */
  
  void setReady(bool ready) {
    if(_ready != ready) {
      _ready = ready;
      _readyStateChangedController.add(_ready);
    }
  }
  
  /**
   * Abstract method to send a [LocalReadyPlayer]s status to this remote player
   */
  
  void sendLocalReadyStatus(LocalReadyPlayer player);
}

/**
 * A pingable player (measures time in ms) - should be used on [RemotePlayer]s only
 */

@deprecated
abstract class PingablePlayer {
  /**
   * Timer to used for periodic pinging
   */
  
  Timer _pingTimer;
  
  /**
   * Last time of ping
   */
    
  int _pingTime;
  
  /**
   * Stream of int that represent the ping time in ms
   */
  
  Stream<int> get onPing => _onPingStreamController.stream;
  StreamController<int> _onPingStreamController = new StreamController.broadcast();
  
  void startPingTimer([int periodInSeconds = 1]) {
    stopPingTimer();
    
    _pingTimer = new Timer.periodic(new Duration(seconds: periodInSeconds), (_) {
      if(_pingTime == null) {
        sendPing();
        _pingTime = new DateTime.now().millisecondsSinceEpoch;
      }
      // TODO(rh): Print warning here? Indicates really high ping
    });
  }
  
  /**
   * Stop the timer
   */
  
  bool stopPingTimer() {
    if(_pingTimer != null) {
      _pingTimer.cancel();
      _pingTimer = null;
      return true;
    }
    
    return false;
  }
  
  /**
   * Should be called when a ping message is received 
   */
  
  void pingReceived() => sendPong();
  
  /**
   * Should be called when a pong message is received
   */
  
  void pongReceived() {
    // Difference will be the round trip time so divide by 2 to get the actual ping
    int diff = (new DateTime.now().millisecondsSinceEpoch) - _pingTime;
    _onPingStreamController.add(diff ~/ 2);
    _pingTime = null;
  }
  
  /**
   * Abstract method that should send a ping message
   */
  
  void sendPing();
  
  /**
   * Abstract method that should send a pong message
   */
  
  void sendPong();
}