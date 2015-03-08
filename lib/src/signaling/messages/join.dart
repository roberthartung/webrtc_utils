part of webrtc_utils.signaling;

class JoinMessage extends SignalingMessage {
  static const String TYPE = 'join';
  String get type => TYPE;
  static const String KEY_ROOM = 'room';
  final String room;
  
  JoinMessage.fromObject(Map message) :
    super.fromObject(message),
    room = message[KEY_ROOM];
}