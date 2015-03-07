part of webrtc_utils.signaling;

/**
 * Ice Candidate message
 */

class IceCandidateMessage extends SignalingMessage {
  // final clientId;
  final RtcIceCandidate candidate;
  //  clientId = message['client']['source']['id']
  IceCandidateMessage._fromObject(Map message) : super.fromObject(message), candidate = new RtcIceCandidate(message['candidate']);
}