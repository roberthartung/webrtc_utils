part of webrtc_utils.signaling.server;

/**
 * A peer in the system
 */

class Peer /*implements Stream, StreamSink*/ {
  int _id;
  
  int get id => _id;
  
  WebSocket _ws;
  
  WebSocket get ws => _ws;
  
  Stream _messages;
  
  Stream<dynamic> get messages => _messages;
  
  Peer(this._id, this._ws) {
    // Turn stream into a broadcasted JSON stream
    _messages = _ws.asBroadcastStream().map((String s) => JSON.decode(s));
  }
  
  void send(Object o) {
    _ws.add(JSON.encode(o));
  }
  
  /**
   * Stream
   */
  
  get single => _messages.single;
  
  /**
   * StreamSink
   */
  
  get done => _ws.done;
}