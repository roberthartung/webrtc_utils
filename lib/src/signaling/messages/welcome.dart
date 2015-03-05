part of webrtc_utils.signaling;

class WelcomeMessage {
  final clientId;
  
  WelcomeMessage._fromObject(Map message) : clientId = message['id'];
}