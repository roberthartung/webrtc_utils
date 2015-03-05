part of webrtc_utils.signaling.server;

/**
 * Room
 */

class Room {
  int _id = 0;
  
  final String _name;
  
  String get name => _name;
  
  final Map<int, Peer> peers = {};
  
  Room(this._name);
  
  void addPeer(Peer peer) {
    peers[peer.id] = peer;
  }
  
  void removePeer(Peer peer) {
    peers.remove(peer.id);
  }
  
  int nextId() {
    return _id++;
  }
}