part of webrtc_utils.server;

class Peer {
  final int id;
  
  final WebSocket _ws;
  
  final List<Room> rooms = [];
  
  Peer(this.id, this._ws) {
    
  }
  
  void send(Object o) {
    _ws.add(JSON.encode(o));
  }
}