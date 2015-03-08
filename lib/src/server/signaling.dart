/**
 * An Example implementation of a signaling server
 * 
 * We are using a HttpServer and upgrade them to WebSockets
 * 
 * As a transfport protocol we use JSON
 */

part of webrtc_utils.server;

const String PROTOCOL = 'webrtc_signaling';

class SignalingServer {
  int _id = 0;
  
  Map<String, Room> rooms = {};
  
  Map<int, Peer> peers = {};
  
  String _protocol;
  
  SignalingServer([String this._protocol = PROTOCOL]);
  
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
    peers[peer.id] = peer;
    // Send initial welcome message
    peer.send({'type': 'welcome', 'peer': {'id': peer.id}});
    
    peer._ws.map((_) => JSON.decode(_)).listen((Map m) {
      //print('Message from Peer#${peer.id}: $m');
      switch(m['type']) {
        case 'join_room' :
          _joinRoom(peer, m);
          break;
        case "rtc_session_description" :
        case "rtc_ice_candidate" :
          // TODO(rh): How to prevent the peer from sending wrong peer IDs
          int targetPeerId = m['peer']['id'];
          // When sending the peer, it is the source 
          m['peer']['id'] = peer.id;
          peers[targetPeerId].send(m);
          break;
        default :
          print("Unknown message received!");
          break;
      }
    });
    
    ws.done.then((_) {
      peer.rooms.forEach((Room room) {
        print('Peer $peer left $room');
        room.peers.remove(peer);
        peers.remove(peer.id);
        final Map message = {'type': 'leave', 'room': room.name, 'peer': {'id': peer.id}};
        // Send LeaveMessage to all remaining clients
        room.peers.values.forEach((Peer otherPeer) {
          otherPeer.send(message);
        });
        // Remove room if there are no more peers
        if(room.peers.length == 0) {
          print('Room $room is empty. Removing.');
          rooms.remove(room.name);
        }
      });
    });
  }
  
  /**
   * Handle join request from a peer
   */
  
  void _joinRoom(Peer peer, Map m) {
    Room room = rooms.putIfAbsent(m['room'], () => new Room(m['room']));
    // Send room message with a list of current peers to the peer
    // id=null is a hack
    peer.send({'type': 'room', 'name': room.name, 'peers': room.peers.keys.toList(), 'peer': {'id': peer.id}});
    final Map message = {'type': 'join', 'room': room.name, 'peer': {'id': peer.id}};
    room.peers.values.forEach((Peer otherPeer) {
      otherPeer.send(message);
    });
    room.peers[peer.id] = peer;
    peer.rooms.add(room);
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