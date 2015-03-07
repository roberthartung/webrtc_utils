part of webrtc_utils.signaling;



class SessionDescriptionMessage extends SignalingMessage {
  final clientId;

  final RtcSessionDescription description;

  SessionDescriptionMessage._fromObject(Map message) : clientId = message['client']['source']['id'], description = new RtcSessionDescription(message['description']);
}