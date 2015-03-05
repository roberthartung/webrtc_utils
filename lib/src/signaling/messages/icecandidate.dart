part of webrtc_utils.signaling;

class IceCandidateMessage {
  final clientId;
  
  final RtcIceCandidate candidate;
  
  IceCandidateMessage._fromObject(Map message) : clientId = message['client']['source']['id'], candidate = new RtcIceCandidate(message['candidate']);
}