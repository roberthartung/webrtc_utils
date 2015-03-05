part of webrtc_utils.signaling;

/**
 * Transforms messages to json
 */

class JsonSignalingTransformer implements SignalingChannelTransformer {
  dynamic serialize(Object o) {
    return JSON.encode(o, toEncodable: (dynamic o) {
      if(o is RtcSessionDescription) {
        return {'sdp' : o.sdp, 'type' : o.type};
      } else if(o is RtcIceCandidate) {
        return {'candidate' : o.candidate, 'sdpMid' : o.sdpMid, 'sdpMLineIndex' : o.sdpMLineIndex};
      }
      
      throw 'Unable to JSON.encode $o';
    });
  }
  
  Object unserialize(dynamic o) {
    return JSON.decode(o, reviver: (key, value) {
      if(key == 'rtc_session_description') {
        return new RtcSessionDescription(value);
      } else if(key == 'rtc_ice_candidate') {
        return new RtcIceCandidate(value);
      }
      
      return value;
    });
  }
}