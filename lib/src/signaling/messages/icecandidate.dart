part of webrtc_utils.signaling;

/**
 * Ice Candidate message
 */

class IceCandidateMessage extends SignalingMessage {
  static const String TYPE = 'rtc_ice_candidate';
  
  String get type => TYPE;
  
  static const String KEY = 'candidate';
  
  final RtcIceCandidate candidate;
  
  IceCandidateMessage(this.candidate, int id) : super(id);
  
  IceCandidateMessage.fromObject(Map message) : super.fromObject(message), candidate = new RtcIceCandidate(message[KEY]);
  
  Object toObject() {
    Map m = super.toObject();
    m[KEY] = {'candidate' : candidate.candidate, 'sdpMid' : candidate.sdpMid, 'sdpMLineIndex' : candidate.sdpMLineIndex};
    return m;
  }
}