part of webrtc_utils.signaling.server;

const String PROTOCOL = 'webrtc_signaling';

class SignalingServer {
  int _id = 0;
  
  Map<String, Room> rooms = {};
  
  String _protocol;
  
  SignalingServer([String this._protocol = PROTOCOL]) {
    
  }
  
  /**
   * Make sure the client sends the right protocol
   */
  
  String _protocolSelector(List<String> protocols) {
    if(protocols.contains(_protocol)) {
      return _protocol;
    }
    return null;
  }
  
  /**
   * Called for every HttpRequest
   */
  
  void _onHttpRequest(HttpRequest request) {
    WebSocketTransformer.upgrade(request, protocolSelector: _protocolSelector).then(_onWebSocket);
  }
  
  /**
   * WebSocket connected to a room
   */
  
  void _onWebSocket(WebSocket ws) {
    if(ws == null || ws.protocol != _protocol) {
      return;
    }
    
    // Create Peer
    Peer peer = new Peer(_id++, ws);
    
    
    
    /*
    ws.done.then((_) {
      room.peers.remove(peer.id);
      room.peers.forEach((int peerId, Peer otherPeer) {
        otherPeer.send({'leave': {'peer': {'id': peer.id}}});
      });
    });
    
    // Make sure the room exists
    // Room room = rooms.putIfAbsent(roomName, () => new Room(roomName));
    
    // Send current peers in the room to the peer
    peer.send({'peers': room.peers.keys.toList()});
    // Send new peer to others
    room.peers.forEach((int peerId, Peer otherPeer) {
      otherPeer.send({'join': {'peer': {'id': peer.id}}});
    });
    // Add Peer to room (make sure this is at the end!) so we don't then the peer to itself.
    room.addPeer(peer);
    
    peer.messages.first.then((Object o) {
      if(o is Map) {
        
      }
    });
    _onPeerConnected(room, peer);
    */
  }
  
  void _onPeerConnected(Room room, Peer peer) {
    // peer.messages.listen();
  }
  
  /**
   * Create a HttpServer that listens on [port]
   */
  
  Future<SignalingServer> listen(int port) {
    return HttpServer.bind('0.0.0.0', port).then((HttpServer server) {
      server.listen(_onHttpRequest);
      return this;
    });
  }
}