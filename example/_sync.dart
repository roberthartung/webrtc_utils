/**
 * A helper class that helps synchronizing events.
 */

/*
class SynchronizedBroadcastChannel {
  /**
   * The data channel name
   * TODO(rh): Should we make this a parameter?
   */
  
  static const String CHANNEL_NAME = 'synchronization';
  
  static const int INTERVAL = 1;
  
  /**
   * The room to synchronize
   */
  
  final Room _room;
  
  /**
   * Max ping in the last second
   */
  
  double _maxPing = null;
  
  /**
   * Average ping (continuous measurement)
   */
  
  double get maxAveragePing => _maxAveragePing;
  double _maxAveragePing = null;
  
  /**
   * Max offset within the last second
   */
  
  double _maxOffset = null;
  
  /**
   * Max average offset (continuous)
   */
  
  double get maxAverageOffset => _maxAverageOffset;
  double _maxAverageOffset = null;
  
  bool get isValid => maxAverageOffset != null && maxAveragePing != null; 
  
  /**
   * Timer for average calculation (once per seconds)
   */
  
  Timer _averageTimer = null;
  
  Stream get onStart => _onStartStreamController.stream;
  StreamController _onStartStreamController = new StreamController.broadcast();
  
  SynchronizedBroadcastChannel(this._room) {
    _room.peers.forEach(_onPeerJoined);
    
    _room.onPeerJoin.listen((Peer peer) {
      _onPeerJoined(peer);
      peer.createChannel(CHANNEL_NAME, {'protocol': 'json'});
    });
    
    _room.onPeerLeave.listen((Peer peer) {
      _onPeerLeft(peer);
    });
  }
  
  void _startTimer() {
    if(_averageTimer == null) {
      _averageTimer = new Timer.periodic(new Duration(seconds: INTERVAL), (Timer t) {
        if(_maxOffset != null) {
          if(_maxAverageOffset == null) {
            _maxAverageOffset = _maxOffset;
          } else {
            _maxAverageOffset = _maxAverageOffset * .75 + _maxOffset * .25;
          }
          // Reset values for next "round"
          _maxOffset = null;
        }
        
        if(_maxPing != null) {
          if(_maxAveragePing == null) {
            _maxAveragePing = _maxPing;
          } else {
            _maxAveragePing = _maxAveragePing * .75 + _maxPing * .25;
          }
          // Reset values for next "round"
          _maxPing = null;
        }
      });
    }
  }
  
  void _onPeerJoined(ProtocolPeer peer) {
    _startTimer();
    print('Peer ${peer.id} joined.');
    
    // Local variables for this peer
    double averagePing = null;
    // Wait for protocol/channel
    peer.onProtocol.where((DataChannelProtocol protocol) => (protocol.channel.label == CHANNEL_NAME)).listen((final JsonProtocol protocol) {
      final Timer pingTimer = new Timer.periodic(new Duration(seconds: INTERVAL), (Timer t) {
        protocol.send({'ping': window.performance.now()});
      });
      
      // When channel is closed -> stop ping
      protocol.channel.onClose.listen((_) {
        pingTimer.cancel();
      });
      
      // A message within the synchronisation
      protocol.onMessage.listen((final Map message) {
        if(message.containsKey('start')) {
          _onStartStreamController.add(null);
          _startAnimation();
          // Start local timer after we know what's the average ping of all peers
        } else if(message.containsKey('ping')) {
          protocol.send({'pong': message['ping']});
          
          // Calculate time difference
          double offset = ((message['ping'] + (averagePing == null ? 0 : averagePing)) - window.performance.now());
          if(_maxOffset == null || offset > _maxOffset) {
            _maxOffset = offset;
          }
        } else if(message.containsKey('pong')) {
          double diff = (window.performance.now() - message['pong']) / 2;
          if(averagePing == null) {
            averagePing = diff;
          } else {
            averagePing = averagePing * 0.75 + diff * .25;
          }
          if(_maxPing == null || diff > _maxPing) {
            _maxPing = diff;
          }
        }
      });
    });
  }
  
  void _onPeerLeft(Peer peer) {
    if(_room.peers.length == 1) {
      _averageTimer.cancel();
      _averageTimer = null; 
    }
    // TODO(rh): Do we need this?
    print('Peer ${peer.id} left.');
  }
  
  /**
   * Internal function that starts the animation
   */
  
  void _startAnimation() {
    window.requestAnimationFrame(_animate);
  }
  
  num toGlobalTime(num time) => (maxAverageOffset > 0 ? time + maxAverageOffset : time);
  
  void _animate(num time) {
    time = toGlobalTime(time);
    CanvasElement canvas = querySelector('#canvas') as CanvasElement;
    CanvasRenderingContext2D ctx = canvas.getContext('2d');
    ctx.clearRect(0,0, canvas.width, canvas.height);
    ctx.fillStyle = 'black';
    /**
     * The global time is the:
     *  [now] + [maximum amount of time I am behind someone else]
     */
    if(isValid) {
      ctx.fillText('max ping: ${maxAveragePing}', 50, 50);
      ctx.fillText('now: ${window.performance.now()}', 50, 70);
      ctx.fillText('offset: ${maxAverageOffset}', 50, 90);
      ctx.fillText('global time: ${time}', 50, 110);
      
      ctx.beginPath();
      ctx.fillStyle = 'red';
      ctx.arc(200, 200, 100, 0, ((time / 2000.0) % 1.0) / 1.0 * 2 * PI);
      ctx.fill();
    }
    _startAnimation();
  }
  
  // Start game
  void start() {
    _onStartStreamController.add(null);
    // The leader sends a start event
    _room.peers.forEach((ProtocolPeer peer) {
      peer.channels[CHANNEL_NAME].send({'start': true});
    });
    _startAnimation();
  }
}
*/
/*
abstract class AlivePlayer {
  bool get isAlive;
}

abstract class AlivePlayerGame<L extends AlivePlayer, R extends AlivePlayer> {
  void tick() {
    
  }
}

abstract class PowerUpMixin<G extends SynchronizedP2PGame<SynchronizedLocalPlayer, SynchronizedRemotePlayer>> {
  void test(G game) {
    // game.players
  }
}
*/