part of webrtc_utils.signaling;

/**
 * This is the basic signaling class that handles basic information
 */

class RtcIceCandidateMessage extends SignalingMessage {
  final RtcIceCandidate candidate;
  
  RtcIceCandidateMessage(this.candidate);
}

class RtcSessionDescriptionMessage extends SignalingMessage {
  final RtcSessionDescription description;
  
  RtcSessionDescriptionMessage(this.description);
}

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