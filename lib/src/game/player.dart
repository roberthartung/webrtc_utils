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

abstract class Player {
  final P2PGame game;
  
  final int id;
  
  bool get isLocal => this is LocalPlayer;
  
  Player(this.game, this.id);
}

/**
 * Local Player
 */

class LocalPlayer extends Player {
  LocalPlayer(P2PGame game, int id) : super(game, id);
}

/**
 * A remote player
 */

class RemotePlayer extends Player {
  /**
   * The peer connection to this player
   */
  
  final Peer peer;
  
  RemotePlayer(P2PGame game, Peer peer) : super(game, peer.id), this.peer = peer;
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
  
  P2PGame get game;
  
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
    game.remotePlayers.forEach((RemoteReadyPlayer remotePlayer) {
      remotePlayer.sendLocalReadyStatus(this);
    });
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