import 'package:webrtc_utils/client.dart';
import 'dart:html';

const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://${window.location.hostname}:28080';
P2PClient client;

void main() {
  client = new WebSocketP2PClient(url, rtcConfiguration);
  
  client.onConnected.listen((final int id) {
    // Join rooms with client.join(...)
  });
  
  client.onRoomJoined.listen((final Room room) {
    // Existing peer in the channel are available in room.peers
    // Listen for room.onLeave
    // Listen for room.onJoin, to create streams and channels when a new remote client joins
  });
}