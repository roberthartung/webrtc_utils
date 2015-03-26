/**
 * A synchronized game that synchronizes messages 
 */

part of webrtc_utils.game;

abstract class SynchronizedRemotePlayer<R extends SynchronizedGameRoom> extends RemotePlayer<R, ProtocolPeer> {
  SynchronizedRemotePlayer(R room, ProtocolPeer peer) : super(room, peer);
}

abstract class SynchronizedLocalPlayer<R extends SynchronizedGameRoom> extends LocalPlayer<R> {
  SynchronizedLocalPlayer(R room, int id) : super(room, id);
}

abstract class SynchronizedP2PGame<L extends SynchronizedLocalPlayer, R extends SynchronizedRemotePlayer> extends P2PGame<L, R> {
  SynchronizedP2PGame(String webSocketUrl,
        Map rtcConfiguration
      )
      : super(webSocketUrl, rtcConfiguration);
  
  @override
  SynchronizedGameRoom createGameRoom(Room room);/* {
    return new SynchronizedGameRoom<SynchronizedP2PGame, L,R>(this, room);
  }*/
}