part of webrtc_utils.server;

class Room {
  final String name;
  
  Map<int, Peer> peers = {};
  
  Room(this.name);
}