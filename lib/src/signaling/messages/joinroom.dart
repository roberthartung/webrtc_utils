part of webrtc_utils.signaling;

class JoinRoomMessage extends SignalingMessage {
  static const String TYPE = 'join_room';
  String get type => TYPE;
  static const String KEY_ROOM = 'room';
  final String room;
  
  JoinRoomMessage(this.room, int id) : super(id);
  
  JoinRoomMessage.fromObject(Map message) :
    super.fromObject(message),
    room = message[KEY_ROOM];
  
  Object toObject() {
    Map m = super.toObject();
    m[KEY_ROOM] = room;
    return m;
  }
}