part of webrtc_utils.signaling.server;

/**
 * A Dual Peer Signaling Server that redirects messages between a pair of peers.
 * 
 * The url's path is taken as the 'room' name.
 */

class DualPeerSignalingServer {
  final int _port;
  
  Map<String, Room> rooms = {};
  
  DualPeerSignalingServer(this._port) {
    HttpServer.bind('0.0.0.0', _port).then((HttpServer server) {
      server.listen(_onHttpRequest);
    });
  }
  
  void _onHttpRequest(HttpRequest req) {
    final String roomName = req.requestedUri.path;
    WebSocketTransformer.upgrade(req, protocolSelector: (List<String> protocols) {
      if(protocols.contains(PROTOCOL)) {
        return PROTOCOL;
      }
      return false;
    }).catchError((err) {
      print('[ERROR] Unable to upgrade HttpRequest to WebSocket: $err');
    }).then((WebSocket ws) {
      if(ws == null || ws.protocol != PROTOCOL) {
        print('[ERROR] WebSocket not upgraded or wrong protocol.');
        return;
      }
      
      // Make sure the room is created
      Room room = rooms.putIfAbsent(roomName, () => new Room(roomName));
      // Create new Peer
      final Peer peer = new Peer(room.nextId(), ws);
      // Add peer to room
      room.addPeer(peer);
      
      // Make sure we cleanup correctly
      ws.done.then((_) {
        room.removePeer(peer);
        if(room.peers.length == 0) {
          rooms.remove(room);
        }
      });
      
      onPeerConnected(peer, room);
    });
  }
  
  /**
   * Called when a new peer has connected to a room
   */
  
  void onPeerConnected(Peer peer, Room room) {
    peer.ws.listen((json) {
      Map data = JSON.decode(json);
      // Forward message to other peer (we assume there are only two peers in the room!)
      if(data.containsKey('rtc_session_description')) {
        room.peers.values.firstWhere((Peer otherPeer) => otherPeer != peer).send(data);
      } else if(data.containsKey('rtc_ice_candidate')) {
        room.peers.values.firstWhere((Peer otherPeer) => otherPeer != peer).send(data);
      } else {
        print('Unknown message from WebSocket: $data');
      }
    });
  }
}