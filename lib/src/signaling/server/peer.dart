part of webrtc_utils.signaling.server;

/**
 * A peer in the system
 */

class Peer {
  int _id;
  
  int get id => _id;
  
  WebSocket _ws;
  
  WebSocket get ws => _ws;
  
  Peer(this._id, this._ws) {
    
  }
  
  void send(Object o) {
    _ws.add(JSON.encode(o));
  }
}