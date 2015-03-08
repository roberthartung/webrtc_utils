part of webrtc_utils.signaling;

class WelcomeMessage extends SignalingMessage {
  static const String TYPE = 'welcome';
  String get type => TYPE;
  WelcomeMessage(int id) : super(id);
  WelcomeMessage.fromObject(Map message) : super.fromObject(message);
}