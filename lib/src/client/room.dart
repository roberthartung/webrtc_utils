/**
 * A Peer on the client side. This is a remote client. The local peer is not represented as a Peer object!
 */

part of webrtc_utils.client;

class Room {
  final String name;
  
  StreamController<Peer> _onJoinController = new StreamController();
  Stream<Peer> get onJoin => _onJoinController.stream;
  
  StreamController<Peer> _onLeaveController = new StreamController();
  Stream<Peer> get onLeave => _onLeaveController.stream;
  
  final List<Peer> _peers = [];
  
  List<Peer> get peers => _peers;
  
  Room._(this.name);
  
  void _addPeer(Peer peer) {
    _peers.add(peer);
    _onJoinController.add(peer);
  }
  
  void _removePeer(Peer peer) {
    _peers.remove(peer);
    _onLeaveController.add(peer);
  }
}