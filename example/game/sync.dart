/**
 * An example on how to create a synchronized game. The game consists of a [CanvasElement]
 * that each user can click on.
 */

import 'package:webrtc_utils/client.dart';
import 'package:webrtc_utils/game.dart';
import 'dart:html';
import 'dart:math';
import 'dart:async';

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
    _canvas = querySelector('div[data-room-name="${gameRoom.room.name}"] .canvas');
    _canvas.onClick.listen((MouseEvent ev) {
      gameRoom.synchronizeMessage(new ClickMessage(ev.offset));
    });
  }

  /// Method called by the room, will make a tick on each circle/object in the game
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

/// An example of a remote player
class MyRemotePlayer extends DefaultSynchronizedRemotePlayer with DemoPlayer {
  MyRemotePlayer(SynchronizedGameRoom room, Peer peer) : super(room, peer);

  /// Method called by the room, will make a tick on each circle/object in the game
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

/// Handles serialization of messages from [SynchronizedGameMessage] to [Map]
class GameProtocol extends JsonProtocol {
  GameProtocol(RtcDataChannel channel) : super(channel);

  @override
  SynchronizedGameMessage handleMessage(String data) {
    Object o = super.handleMessage(data);
    GameMessage gm = null;
    if(o is Map) {
      if(o.containsKey('click')) {
        gm = new ClickMessage(new Point(o['click']['x'], o['click']['y']));
      } else {
        throw "Unknown message: $o";
      }

      // TODO(rh): Can we do this better? E.g. using a factory?
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

class MyGameRoomRendererFactory<G extends SynchronizedGameRoom> implements GameRoomRendererFactory<G> {
  GameRoomRenderer<G> createRenderer(G room) {
    return new MyGameRoomRenderer(room);
  }
}

class MyGameRoomRenderer<G extends SynchronizedGameRoom> implements GameRoomRenderer<G> {
  /// An integer representing the target tick rate (FPS) for the game.
  ///
  /// [window.animationFrame] might not generate accurate 60 fps, thus we can
  /// only rely on the time passed to the callback.
  final int targetTickRate = 60;

  CanvasElement _canvas;

  CanvasRenderingContext2D _ctx;

  int _fpsCounter = 0;

  final G gameRoom;

  MyGameRoomRenderer(this.gameRoom) {
    document.body.appendHtml('''<div class="room" data-room-name="${gameRoom.room.name}">
  <div>fps: <span class="fps"></span></div>
  <canvas class="canvas" width="400" height="300"></canvas>
<div>max ping: <span class="maxping"></span> [ms]</div>
<div>diff to master: <span class="maxdifference"></span> [ms]</div>
<div>global: <span class="globaltime"></span> [ms]</div>
</div>''');

    DivElement div = querySelector('div[data-room-name="${gameRoom.room.name}"]');
    SpanElement fpsElement = div.querySelector('.fps');
    SpanElement pingElement = div.querySelector('.maxping');
    SpanElement diffElement = div.querySelector('.maxdifference');
    SpanElement timeElement = div.querySelector('.globaltime');

    _canvas = div.querySelector('.canvas');
    _ctx = _canvas.getContext('2d');
    new Timer.periodic(new Duration(seconds: 1), (Timer t) {
      fpsElement.text = '$_fpsCounter';
      pingElement.text = '${gameRoom.maxPing}';
      diffElement.text = '${gameRoom.timeDifferenceToMaster}';
      timeElement.text = '${gameRoom.globalTime}';
      _fpsCounter = 0;
    });

    gameRoom.startAnimation();
  }

  void render() {
    _fpsCounter++;
    _ctx.clearRect(0,0, _canvas.width, _canvas.height);
    gameRoom.players.forEach((Player player) {
      (player as DemoPlayer).render(_ctx);
    });
  }
}

/**
 * Main method that will create the [MyGame] and
 * join a room once connected to the signaling server
 */

void main() {
  final SynchronizedWebSocketP2PGame game = new SynchronizedWebSocketP2PGame(webSocketUrl, rtcConfiguration);
  game.setGameRoomRendererFactory(new MyGameRoomRendererFactory());
  game.setProtocolProvider(new MyProtocolProvider());
  game.setPlayerFactory(new MyPlayerFactory());

  game.onConnect.listen((_) {
    print('Connected');
    game.join('example/game/sync');
  });
}