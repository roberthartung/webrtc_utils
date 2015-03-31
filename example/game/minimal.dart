/**
 * An minimal example for a game
 */

import 'package:webrtc_utils/client.dart';
import 'package:webrtc_utils/game.dart';
import 'dart:html';

final String webSocketUrl = 'ws://${window.location.hostname}:28080';

/**
 * Shared for both local and remote player
 */

abstract class CommonPlayer {
  /**
   * Handle a synchronized message
   */
  
  void handleMessage(GameMessage message) {
    // handle message
  }
}

/**
 * An example of a local player
 */

class MyLocalPlayer extends DefaultSynchronizedLocalPlayer with CommonPlayer {
  MyLocalPlayer(SynchronizedGameRoom gameRoom, int id) : super(gameRoom, id) {
    // gameRoom.synchronizeMessage(...);
  }
  
  /**
   * Method called by the room
   */
  
  void tick(int tick) {
    super.tick(tick);
    // ...
  }
}

/**
 * An example of a remote player
 */

class MyRemotePlayer extends DefaultSynchronizedRemotePlayer with CommonPlayer {
  MyRemotePlayer(SynchronizedGameRoom room, Peer peer) : super(room, peer) {
  }
  
  /**
   * Method called by the room, will make a tick on each circle/object in the game
   */
  
  void tick(int tick) {
    super.tick(tick);
    // ...
  }
}

/**
 * A synchronized game example. Overrides only the createGameRoom method so
 * you can create a game specific room
 */

class MyGame extends SynchronizedWebSocketP2PGame {
  MyGame(String webSocketUrl, Map rtcConfiguration) : super(webSocketUrl, rtcConfiguration);
}

/*
class MySynchronizedGame extends SynchronizedP2PGame<MyLocalPlayer,MyRemotePlayer> {
  int _fpsCounter = 0;
  
  MySynchronizedGame(String webSocketUrl, Map rtcConfiguration)
    : super(webSocketUrl, rtcConfiguration) {
    startAnimation();
  }
  
  @override
  MyLocalPlayer createLocalPlayer(GameRoom room, int localId) {
    return new MyLocalPlayer(room, localId);
  }
  
  @override
  MyRemotePlayer createRemotePlayer(GameRoom room, Peer peer) {
    return new MyRemotePlayer(room, peer);
  }
  
  void render() {
    
  }
}
*/

/**
 * Main method that will create the [MySynchronizedGame] and
 * join a room once connected to the signaling server
 */

void main() {
  final SynchronizedWebSocketP2PGame game = new MyGame(webSocketUrl, rtcConfiguration);
  
  game.onConnect.listen((_) {
    print('Connected');
    game.join('room1');
  });
  
  game.onGameRoomCreated.listen((SynchronizedGameRoom gameRoom) {
    
  });
}