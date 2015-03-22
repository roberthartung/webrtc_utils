part of webrtc_utils.signaling;

class JoinRoomMessage extends SignalingMessage {
  static const String TYPE = 'join_room';
  static const String KEY_ROOM = 'room';
  static const String KEY_PASSWORD = 'password';
  String get type => TYPE;
  
  final String room;
  
  final String password;
  
  JoinRoomMessage(this.room, this.password, int id) : super(id);
  
  JoinRoomMessage.fromObject(Map message) :
    super.fromObject(message),
    room = message[KEY_ROOM],
    password = message[KEY_PASSWORD];
  
  Object toObject() {
    Map m = super.toObject();
    m[KEY_ROOM] = room;
    m[KEY_PASSWORD] = password;
    return m;
  }
}