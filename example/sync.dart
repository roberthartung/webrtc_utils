/**
 * When developing a P2P Game that relies on time or points in time
 * there are two problems:
 * 
 *      - clock drift    (problem over time)
 *      - clock offset   (initial / adjusted)
 * 
 * To get rid of these two side effects and make synchronisation more easy
 * I created this example to test and demonstrate how to overcome this issues.
 * 
 * -----------------------------------------------
 * 
 * In a browser based P2P game you usually use [window.requestAnimationFrame] to get a
 * stable 60 fps. The callback takes one argument: A double that represents a
 * high precision timestamp. It starts measuring time when the document is loaded. So this
 * time naturally differs between each pair of peers. Thus the difference between these times
 * has to be measured between pairs.
 * 
 * The clock offset can be approximated by measuring the ping that is
 * 
 *      ping := (Round Trip Time (RTT)  / 2)
 * 
 * We take the average ping to all peers. This does give a good appoximation,
 * however we don't know the ping between the other peers. Thus we assume the
 * worst case behaviour
 * 
 *      A <-- PingAB --> B <-- PingBC --> C
 * 
 * and we assume that the ping between A and C is twice the maximum ping between
 * A and B and B and C so: 
 * 
 *      maxping := 2 * max( PingAB, PingBC )
 * 
 * This will be the initial delay and it can be adjusted (if needed) later in time if needed.
 * 
 * -----------------------------------------------
 * 
 * In a P2P Game you might generate (synchronized) events on all peers. If a peer
 * wishes to generate an event it takes the local time and adds the offset (maxping) to it.
 * This way the events should occur almost at the same point in time from a global point of view.
 * 
 * -----------------------------------------------
 * 
 * As there might be a clock drift between pairs of peers the difference has to be measured.
 * To get an accurate result we use [window.performance.now]. 
 */

import 'package:webrtc_utils/client.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';

final String url = 'ws://${window.location.hostname}:28080';
P2PClient client;

/**
 * A helper class that helps synchronizing events.
 */

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
    
    _room.onJoin.listen((Peer peer) {
      _onPeerJoined(peer);
      peer.createChannel(CHANNEL_NAME, {'protocol': 'json'});
    });
    
    _room.onLeave.listen((Peer peer) {
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
  
  void _onPeerJoined(Peer peer) {
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
    _room.peers.forEach((Peer peer) {
      peer.channels[CHANNEL_NAME].send({'start': true});
    });
    _startAnimation();
  }
}

int fpsCounter = 0;

void main() {
  client = new WebSocketP2PClient(url, rtcConfiguration);
  
  // Join a room like you would normally do.
  client.onConnect.listen((final int localPeerId) {
    client.join('synctest');
  });
  
  client.onJoinRoom.listen((final Room room) {
    print('Room ${room.name} joined');
    SynchronizedBroadcastChannel chan = new SynchronizedBroadcastChannel(room);
    
    /*
    chan.onStart.listen((_) {
      new Timer.periodic(new Duration(milliseconds: 250), (Timer t) {
        fpsCounter = 0;
      });
    });
    */
    
    // Owner
    if(room.peers.length == 0) {
      // TODO(rh): Enable button after there are enough peers and enough measurements
      ButtonElement button = new ButtonElement();
      button.text = 'Start game';
      button.onClick.listen((MouseEvent ev) {
        chan.start();
      });
      document.body.append(button);
    } else {
      document.body.appendHtml('Waiting for other peers and start.');
    }
  });
}