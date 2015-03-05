part of webrtc_utils.signaling;

abstract class WebRtcSignalingHandler {
  void connect(String signalingServerUrl);
  
  Stream<IceCandidateMessage> get onIceCandidate;
}