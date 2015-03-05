part of webrtc_utils.signaling;

/**
 * This is the basic signaling class that handles basic information
 */

class WebSocketSignalingChannel implements SignalingChannel {
  WebSocket _ws;
  
  SignalingChannelTransformer _transformer;
  
  final StreamController<SignalingMessage> _messageController = new StreamController<SignalingMessage>(); 
  
  Stream<SignalingMessage> get onMessage => _messageController.stream;
  
  WebSocketSignalingChannel(String url, this._transformer) {
    _ws = new WebSocket(url, 'webrtc_signaling');
    _ws.onMessage.listen(_onMessage);
  }
  
  /**
   * Sends a message to the signaling server
   */
  
  void send(Object message) {
    if(_ws == null || _ws.readyState != WebSocket.OPEN) {
      throw "Unable to send message. WebSocket is not opened.";
    }
    
    _ws.send(_transformer.serialize(message));
  }
  
  /**
   * Message received from the signaling server
   */
  
  void _onMessage(MessageEvent ev) {
    Map message = _transformer.unserialize(ev.data);
    
    if(message.containsKey('rtc_session_description')) {
      _messageController.add(new RtcSessionDescriptionMessage(message['rtc_session_description']));
    } else if(message.containsKey('rtc_ice_candidate')) {
      _messageController.add(new RtcIceCandidateMessage(message['rtc_ice_candidate']));
    } else {
      print('message received: $message');
    }
  }
}

class TargetedWebSocketSignalingChannel extends WebSocketSignalingChannel implements TargetedSignalingChannel {
  int source;
  
  TargetedSignalingChannelTransformer _transformer;
  
  final StreamController<TargetedSignalingMessage> _targetedMessageController = new StreamController<TargetedSignalingMessage>(); 
  
  Stream<TargetedSignalingMessage> get onTargetedMessage => _targetedMessageController.stream;
  
  TargetedWebSocketSignalingChannel(String url, transformer) : super(url, transformer) {
    _transformer = transformer;
  }
  
  /**
   * Sends a message to the signaling server
   */
  
  void send(Object message, [int target]) {
    if(_ws == null || _ws.readyState != WebSocket.OPEN) {
      throw "Unable to send message. WebSocket is not opened.";
    }
    
    _ws.send(_transformer.serialize(message, target));
  }
  
  /**
   * Message received from the signaling server
   */
  
  void _onMessage(MessageEvent ev) {
    TargetedSignalingMessage message = _transformer.unserialize(ev.data);
    if(message.data != null) {
      if(message.data.containsKey('rtc_session_description')) {
        message.message = new RtcSessionDescriptionMessage(message.data['rtc_session_description']);
      } else if(message.data.containsKey('rtc_ice_candidate')) {
        message.message = new RtcIceCandidateMessage(message.data['rtc_ice_candidate']);
      }
    }
    _targetedMessageController.add(message);
  }
}