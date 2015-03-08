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
  
  final StreamController<SignalingMessage> _messageController = new StreamController<SignalingMessage>(); 
    
  Stream<SignalingMessage> get onMessage => _messageController.stream;
  
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
    print('ws opened');
  }
  
  void _onClose(CloseEvent ev) {
    print('ws closed');
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