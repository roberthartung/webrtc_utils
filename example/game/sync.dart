/**
 * An example on how to create a synchronized game. The game consists of a [CanvasElement]
 * that each user can click on. 
 */

import 'package:stack_trace/stack_trace.dart';
import 'package:webrtc_utils/client.dart';
import 'package:webrtc_utils/game.dart';
import 'dart:html';
import 'dart:math';
import 'dart:async';
import 'dart:convert';

final String webSocketUrl = 'ws://${window.location.hostname}:28080';

/**
 * Demo Shape that will exchanged / changed synchronously 
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

/**
 * Shared logic
 */

abstract class DemoPlayer {
  SynchronizedGameRoom get room;
  
  List<Circle> circles = [];
  
  /**
   * Handle a synchronized message
   */
  
  void handleMessage(GameMessage message) {
    if(message is ClickMessage) {
      circles.add(new Circle(message.point));
    }
  }
  
  void render(CanvasRenderingContext2D ctx) {
    circles.forEach((Circle c) => c.render(ctx));
  }
}

class ClickMessage implements GameMessage {
  final Point point;
  ClickMessage(this.point);
}

/**
 * An example of a local player
 */

class MyLocalPlayer extends DefaultSynchronizedLocalPlayer with DemoPlayer {
  CanvasElement _canvas;
  
  MyLocalPlayer(SynchronizedGameRoom gameRoom, int id) : super(gameRoom, id) {
    //_setupListener();
    _canvas = querySelector('#canvas');
    _canvas.onClick.listen((MouseEvent ev) {
      gameRoom.synchronizeMessage(new ClickMessage(ev.offset));
    });
  }
  
  /**
   * Method called by the room, will make a tick on each circle/object in the game
   */
  
  void tick(int tick) {
    super.tick(tick);
    List<Circle> finishedCircles = [];
    circles.forEach((Circle c) {
      if(c.tick()) {
        finishedCircles.add(c);
      }
    });
    circles.removeWhere((Circle c) => finishedCircles.contains(c));
  }
}

/**
 * An example of a remote player
 */

class MyRemotePlayer extends DefaultSynchronizedRemotePlayer with DemoPlayer {
  MyRemotePlayer(SynchronizedGameRoom room, Peer peer) : super(room, peer);
  
  /**
   * Method called by the room, will make a tick on each circle/object in the game
   */
  
  void tick(int tick) {
    super.tick(tick);
    List<Circle> finishedCircles = [];
    circles.forEach((Circle c) {
      if(c.tick()) {
        finishedCircles.add(c);
      }
    });
    circles.removeWhere((Circle c) => finishedCircles.contains(c));
  }
}

/**
 * Handles serialization of messages from [SynchronizedGameMessage] to [Map]
 */

class GameProtocol extends JsonProtocol {
  GameProtocol(RtcDataChannel channel) : super(channel);
  
  @override
  SynchronizedGameMessage handleMessage(String data) {
    Object o = super.handleMessage(data);
    GameMessage gm;
    if(o is Map) {
      if(o.containsKey('click')) {
        gm = new ClickMessage(new Point(o['click']['x'], o['click']['y']));
      } else {
        throw "Unknown message: $o";
      }
      
      return new SynchronizedGameMessage(o['tick'], gm);
    }
    
    throw "Unknown message: $o";
  }
  
  @override
  void send(SynchronizedGameMessage sm) {
    Map map = {'tick': sm.tick};
    if(sm.message is ClickMessage) {
      ClickMessage m = sm.message as ClickMessage;
      map['click'] = {'x': m.point.x, 'y': m.point.y};
    } else {
      throw "Unable to send message ${sm.message}";
    }
    super.send(map);
  }
}

/**
 * Protocol provider that handles message serialization
 */

class MyProtocolProvider extends DefaultProtocolProvider {
  DataChannelProtocol provide(Peer peer, RtcDataChannel channel) {
    if(channel.protocol == 'game') {
      return new GameProtocol(channel);
    }
    
    return super.provide(peer, channel);
  }
}

class MyPlayerFactory implements PlayerFactory<MyLocalPlayer, MyRemotePlayer> {
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
 * A synchronized game example. Overrides only the createGameRoom method so
 * you can create a game specific room
 */

class MyGame extends SynchronizedWebSocketP2PGame<MyLocalPlayer, MyRemotePlayer> {
  CanvasElement _canvas;
  
  CanvasRenderingContext2D _ctx;
  
  int _fpsCounter = 0;
  
  MyGame(String webSocketUrl, Map rtcConfiguration)
    : super(webSocketUrl, rtcConfiguration) {
    setProtocolProvider(new MyProtocolProvider());
    setPlayerFactory(new MyPlayerFactory());
    
    _canvas = querySelector('#canvas');
    _ctx = _canvas.getContext('2d');
    startAnimation();
    new Timer.periodic(new Duration(seconds: 1), (Timer t) {
      querySelector('#fps').text = '$_fpsCounter';
      //querySelector('#maxping').text = '$_maxPing';
      //querySelector('#maxdifference').text = '$_maxPositiveTimeDifference';
      _fpsCounter = 0;
    });
    
    onGameRoomCreated.listen((SynchronizedGameRoom gameRoom) {
      print('[$this] GameRoom created: $gameRoom');
      gameRoom.onSynchronizationStateChanged.listen((bool state) {
        print('Synchronization state changed: $state');
      });
    });
  }
  
  @override
  void render() {
    _fpsCounter++;
    _ctx.clearRect(0,0, _canvas.width, _canvas.height);
    // Render each room
    // TODO(rh): This is kind of ugly
    gameRooms.forEach((SynchronizedGameRoom room) {
      room.players.forEach((Player player) {
        (player as DemoPlayer).render(_ctx);
      });
    });
  }
}

/**
 * Main method that will create the [MyGame] and
 * join a room once connected to the signaling server
 */

void main() {
  final SynchronizedWebSocketP2PGame game = new MyGame(webSocketUrl, rtcConfiguration);
  
  Chain.capture(() {
    game.onConnect.listen((_) {
      print('Connected');
      game.join('example/game/sync');
    });
  }, onError: (error, stack) {
    print(error);
    print(stack);
  });
}