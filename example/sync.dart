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
import 'package:webrtc_utils/game.dart';
import 'dart:html';
import 'dart:math';
import 'dart:async';

final String webSocketUrl = 'ws://${window.location.hostname}:28080';

const TICKS_PER_SECONDS = 10;

/**
 * Shared logic
 */

class Circle {
  final Point middle;
  
  Circle(this.middle);
  
  int _opacity = 100;
  
  int _radius = 0;
  
  bool tick() {
    _opacity -= 4;
    _radius += 1;
    return _opacity <= 0;
  }
  
  void render(CanvasRenderingContext2D ctx) {
    ctx.save();
    ctx.fillStyle = 'red';
    ctx.globalAlpha = _opacity / 100.0;
    ctx.beginPath();
    ctx.arc(middle.x, middle.y, _radius, 0, 2 * PI);
    ctx.fill();
    ctx.restore();
  }
}

abstract class DemoPlayer {
  SynchronizedGameRoom get room;
  
  List<Circle> circles = [];
  
  /**
   * Listener on the game room that waits for synchronized messages
   */
  
  void _setupListener() {
    room.onSynchronizedMessage.listen((Map message) {
      Point p = new Point(message['click']['x'], message['click']['y']);
      _click(p);
    });
  }
  
  void _click(Point p) {
    circles.add(new Circle(p));
  }
  
  void tick(int tick) {
    List<Circle> finishedCircles = [];
    circles.forEach((Circle c) {
      if(c.tick()) {
        finishedCircles.add(c);
      }
    });
    circles.removeWhere((Circle c) => finishedCircles.contains(c));
  }
  
  void render(CanvasRenderingContext2D ctx) {
    circles.forEach((Circle c) => c.render(ctx));
  }
}

/**
 * An example of a local player
 */

class MyLocalPlayer extends SynchronizedLocalPlayer with DemoPlayer {
  CanvasElement _canvas;
  
  MyLocalPlayer(SynchronizedGameRoom gameRoom, int id) : super(gameRoom, id) {
    _setupListener();
    _canvas = querySelector('#canvas');
    _canvas.onClick.listen((MouseEvent ev) {
      // TODO(rh): To Global Time
      // window.performance.now()
      gameRoom.synchronizeMessage({'click': {'x': ev.offset.x, 'y': ev.offset.y}, 'time': (window.performance.now() + gameRoom.maxPing * 2)});
    });
  }
}

/**
 * An example of a remote player
 */

class MyRemotePlayer extends SynchronizedRemotePlayer with DemoPlayer {
  MyRemotePlayer(SynchronizedGameRoom room, Peer peer) : super(room, peer) {
    _setupListener();
  }
}

/**
 * Protocol provider that handles message serialization
 */

class MyProtocolProvider extends DefaultProtocolProvider {
  DataChannelProtocol provide(Peer peer, RtcDataChannel channel) {
    if(channel.protocol == 'game') {
      return new JsonProtocol(channel);
    }
    
    return super.provide(peer, channel);
  }
}

/**
 * A synchronized game example. Overrides only the createGameRoom method so
 * you can create a game specific room
 */

class SynchronizedGame extends SynchronizedP2PGame<MyLocalPlayer,MyRemotePlayer>
  /* with AlivePlayerGame<MyLocalPlayer, MyRemotePlayer>*/ {
  
  CanvasElement canvas;
  
  CanvasRenderingContext2D ctx;
  
  int fpsCounter = 0;
  
  SynchronizedGame(String webSocketUrl, Map rtcConfiguration)
    : super(webSocketUrl, rtcConfiguration) {
    setProtocolProvider(new MyProtocolProvider());
    
    canvas = querySelector('#canvas');
    ctx = canvas.getContext('2d');
    startAnimation();
    new Timer.periodic(new Duration(seconds: 1), (Timer t) {
      querySelector('#fps').text = '$fpsCounter';
      fpsCounter = 0;
    });
  }
  
  // TODO(rh): Do not initialize to 0! Wait for onSynchronized event and take global time for initialization
  // double _lastTickTime = 0.0;
  int lastTick = 0;
  
  void _tick(double localTime) {
    fpsCounter++;
    // Make tick in each room to update the room-global time
    gameRooms.forEach((SynchronizedGameRoom room) {
      room.tick(localTime);
    });
    
    // Rendering...
    // TODO(rh): Decouple these two steps!
    ctx.clearRect(0,0, canvas.width, canvas.height);
    gameRooms.forEach((SynchronizedGameRoom room) {
      double globalTime = room.timeDifferenceToMaster + localTime;
      int currentTick = globalTime ~/ TICKS_PER_SECONDS;
      querySelector('#globaltime').text = '${globalTime}';
      room.players.forEach((Player player) {
        for(int t=lastTick+1;t<=currentTick;t++) {
          player.tick(t);
        }
        if(player is DemoPlayer) {
          (player as DemoPlayer).render(ctx);
        }
      });
      
      lastTick = currentTick;
    });
    
    startAnimation();
  }
  
  void startAnimation() {
    window.requestAnimationFrame(_tick);
  }
  
  @override
  MyLocalPlayer createLocalPlayer(GameRoom room, int localId) {
    return new MyLocalPlayer(room, localId);
  }
  
  @override
  MyRemotePlayer createRemotePlayer(GameRoom room, Peer peer) {
    return new MyRemotePlayer(room, peer);
  }
}

/**
 * Main method that will create the game ([SynchronizedGame]) and
 * join a room once connected to the signaling server
 */

void main() {
  /*
  MessageQueue queue = new MessageQueue<String>();
  queue.add(5, '5');
  queue.add(4, '4');
  queue.add(6, '6');
  queue.add(5, '5');
  print(queue.poll());
  print(queue.poll());
  print(queue.poll());
  print(queue.poll());
  print(queue.poll());
  */
  
  final SynchronizedP2PGame game = new SynchronizedGame(webSocketUrl, rtcConfiguration);
  
  game.onConnect.listen((_) {
    print('Connected');
    game.join('room1');
  });
}