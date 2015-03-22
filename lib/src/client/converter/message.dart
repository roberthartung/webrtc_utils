part of webrtc_utils.client;

class MessageConverter extends JsonConverter {
  String encode(SignalingMessage message) {
    return super.encode(message.toObject());
  }
  
  SignalingMessage decode(String s) {
    Map m = super.decode(s);
    if(m['type'] == SessionDescriptionMessage.TYPE) {
      return new SessionDescriptionMessage.fromObject(m);
    } else if(m['type'] == IceCandidateMessage.TYPE) {
      return new IceCandidateMessage.fromObject(m);
    } else if(m['type'] == WelcomeMessage.TYPE) {
      return new WelcomeMessage.fromObject(m);
    } else if(m['type'] == RoomJoinedMessage.TYPE) {
      return new RoomJoinedMessage.fromObject(m);
    } else if(m['type'] == RoomLeftMessage.TYPE) {
      return new RoomLeftMessage.fromObject(m);
    } else if(m['type'] == JoinMessage.TYPE) {
      return new JoinMessage.fromObject(m);
    } else if(m['type'] == LeaveMessage.TYPE) {
      return new LeaveMessage.fromObject(m);
    }
    
    throw "Unable to decode string '$s'.";
  }
  
  /*
  dynamic _reviver(String key, dynamic value) {
    if(key == 'rtc_session_description') {
      return new RtcSessionDescription(value);
    } else if(key == 'rtc_ice_candidate') {
      return new RtcIceCandidate(value);
    }
    
    return value;
  }
  
  dynamic _toEncodable(dynamic o) {
    if(o is RtcSessionDescription) {
      return {};
    } else if(o is RtcIceCandidate) {
      return {};
    }
    
    throw 'Unable to JSON.encode $o';
  }
  */
}