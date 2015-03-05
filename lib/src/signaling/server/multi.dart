part of webrtc_utils.signaling.server;

/**
 * The Multi Peer Signaling Server uses the ID of each peer
 */

class MultiPeerSignalingServer extends DualPeerSignalingServer {
  MultiPeerSignalingServer(port) : super(port);
  
  // Override onPeerConnected method
  void onPeerConnected(Peer peer, Room room) {
    // Send peer to all other peers
    
    print('[Peer#${peer.id}] Connected');
    
    // Make sure the first peer message is from the peer itself
    peer.send({'peer': {'id': peer.id}});
    // Send other peer ids
    room.peers.values.where((Peer otherPeer) => otherPeer != peer).forEach((Peer otherPeer) {
      otherPeer.send({'peer': {'id': peer.id}});
      peer.send({'peer': {'id': otherPeer.id}});
    });
    
    peer.ws.listen((json) {
      Map message = JSON.decode(json);
      print('data: $message');
      // When receiving the peer, it is the target
      int targetPeerId = message['peer']['id'];
      // When sending the peer, it is the source 
      message['peer']['id'] = peer.id;
      
      // Forward message to target peer
      if(message.containsKey('rtc_session_description')) {
        room.peers[targetPeerId].send(message);
        // room.peers.firstWhere((Peer otherPeer) => otherPeer != peer).send(data);
      } else if(message.containsKey('rtc_ice_candidate')) {
        room.peers[targetPeerId].send(message);
        // room.peers.firstWhere((Peer otherPeer) => otherPeer != peer).send(data);
      } else {
        print('Unknown message from WebSocket: $message');
      }
    });
  }
}