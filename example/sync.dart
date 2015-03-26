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

import 'package:webrtc_utils/game.dart';
import 'dart:html';
//import 'dart:async';
//import 'dart:math';

final String webSocketUrl = 'ws://${window.location.hostname}:28080';

class MyLocalPlayer extends SynchronizedLocalPlayer<MySynchronizedRoom> {
  MyLocalPlayer(SynchronizedGameRoom room, int id) : super(room, id);
  
  void tick(int tickCount) {
    
  }
}

class MyRemotePlayer extends SynchronizedRemotePlayer<MySynchronizedRoom> {
  MyRemotePlayer(SynchronizedGameRoom room, Peer peer) : super(room, peer);
  
  void tick(int tickCount) {
    
  }
}

class MySynchronizedRoom extends SynchronizedGameRoom<SynchronizedGame,MyLocalPlayer,MyRemotePlayer> {
  MySynchronizedRoom(SynchronizedGame game, Room room) : super(game, room);
  
  @override
  MyLocalPlayer createLocalPlayer(int localId) {
    return new MyLocalPlayer(this, localId);
  }
  
  @override
  MyRemotePlayer createRemotePlayer(Peer peer) {
    return new MyRemotePlayer(this, peer);
  }
}

class SynchronizedGame extends SynchronizedP2PGame<MyLocalPlayer,MyRemotePlayer>/* with AlivePlayerGame<MyLocalPlayer, MyRemotePlayer>*/ {
  SynchronizedGame(String webSocketUrl, Map rtcConfiguration)
    : super(webSocketUrl, rtcConfiguration);
  
  SynchronizedGameRoom createGameRoom(Room room) {
    return new MySynchronizedRoom(this, room);
  }
}

void main() {
  final SynchronizedP2PGame game = new SynchronizedGame(webSocketUrl, rtcConfiguration);
  // final P2PClient client = new WebSocketP2PClient(webSocketUrl, rtcConfiguration);
  
  game.onConnect.listen((_) {
    print('Connected');
    game.join('room1');
    //game.join('room2');
  });
}