part of webrtc_utils.client;

/**
 * A WebSocket implementation for the client side SignalingChannel
 */

class WebSocketSignalingChannel implements SignalingChannel {
  /**
   * WebSocket instance
   */
  
  final WebSocket _ws;
  
  /**
   * Encoder to be used to convert a SignalingMessage for the WebSocket
   */
  
  final MessageConverter _converter = new MessageConverter();
  
  /**
   * StreamController for streams of messages from the websocket
   */
  
  final StreamController<SignalingMessage> _messageController = new StreamController.broadcast(); 
  Stream<SignalingMessage> get onMessage => _messageController.stream;
  
  /**
   * Stream of close events of this signaling channel
   */

  Stream<int> get onClose => _onCloseController.stream;
  final StreamController<int> _onCloseController = new StreamController.broadcast();
  
  /**
   * Stream of open events of this signaling channel
   */

  Stream get onOpen => _onOpenController.stream;
  final StreamController _onOpenController = new StreamController.broadcast(); 
  
  /**
   * Constructor: Tales a websocket Url and creates a connection using the "webrtc_signaling" protocol
   */
  
  WebSocketSignalingChannel(String webSocketUrl) :
    _ws = new WebSocket(webSocketUrl, 'webrtc_signaling') {
    // Setup message listener
    _ws.onMessage.listen(_onMessage);
    _ws.onOpen.listen(_onOpen);
    _ws.onClose.listen(_onClose);
  }
  
  void _onOpen(Event ev) {
    _onOpenController.add(null);
  }
  
  void _onClose(CloseEvent ev) {
    _onCloseController.add(ev.code);
  }
  
  /**
   * Sends a SignalingMessage through the WebSocket as a JSON string
   */
  
  void send(SignalingMessage message) {
    if(_ws == null || _ws.readyState != WebSocket.OPEN) {
      throw "Unable to send message. WebSocket is not opened.";
    }
    
    _ws.send(_converter.encode(message));
  }
  
  /**
   * Message handler that decodes a JSON string to SignalingMessage
   */
  
  void _onMessage(MessageEvent ev) {
    _messageController.add(_converter.decode(ev.data));
  }
}