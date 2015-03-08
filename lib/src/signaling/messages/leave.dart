part of webrtc_utils.signaling;

class LeaveMessage extends SignalingMessage {
  static const String TYPE = 'leave';
  String get type => TYPE;
  static const String KEY_ROOM = 'room';
  final String room;
  
  LeaveMessage.fromObject(Map message) :
    super.fromObject(message),
    room = message[KEY_ROOM];
}