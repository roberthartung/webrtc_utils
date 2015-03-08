/**
 * A Peer on the client side. This is a remote client. The local peer is not represented as a Peer object!
 */

part of webrtc_utils.client;

class Room {
  final String name;
  
  StreamController<Peer> _onPeerJoinedController = new StreamController();
    
  Stream<Peer> get onPeerJoined => _onPeerJoinedController.stream;
  
  final List<Peer> _peers = [];
  
  List<Peer> get peers => _peers;
  
  Room._(this.name);
  
  void _addPeer(Peer peer) {
    _peers.add(peer);
    _onPeerJoinedController.add(peer);
  }
}