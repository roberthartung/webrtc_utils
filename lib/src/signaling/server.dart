part of webrtc_utils.signaling.server;

const String PROTOCOL = 'webrtc_signaling';

class SignalingServer {
  Map<String, Room> rooms = {};
  
  SignalingServer() {
    
  }
  
  /**
   * Make sure the client sends the right protocol
   */
  
  String _protocolSelector(List<String> protocols) {
    if(protocols.contains(PROTOCOL)) {
      return PROTOCOL;
    }
    return null;
  }
  
  /**
   * Called for every HttpRequest
   */
  
  void _onHttpRequest(HttpRequest request) {
    // TODO(rh): Where to get roomName from? Initial/Welcome message or from the HttpRequest's path?
    // For now we use the path as the room name
    WebSocketTransformer.upgrade(request, protocolSelector: _protocolSelector).then((WebSocket ws) => _onWebSocket(request.requestedUri.path, ws));
  }
  
  /**
   * WebSocket connected to a room
   */
  
  void _onWebSocket(String roomName, WebSocket ws) {
    if(ws == null || ws.protocol != PROTOCOL) {
      return;
    }
    
    // Make sure the room exists
    Room room = rooms.putIfAbsent(roomName, () => new Room(roomName));
    // Create Peer
    Peer peer = new Peer(room.nextId(), ws);
    
    ws.done.then((_) {
      room.peers.remove(peer.id);
      room.peers.forEach((int peerId, Peer otherPeer) {
        otherPeer.send({'leave': {'peer': {'id': peer.id}}});
      });
    });
    
    // Send current peers in the room to the peer
    peer.send({'peers': room.peers.keys.toList()});
    // Send new peer to others
    room.peers.forEach((int peerId, Peer otherPeer) {
      otherPeer.send({'join': {'peer': {'id': peer.id}}});
    });
    // Add Peer to room (make sure this is at the end!) so we don't then the peer to itself.
    room.addPeer(peer);
    _onPeerConnected(room, peer);
  }
  
  void _onPeerConnected(Room room, Peer peer) {
    
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