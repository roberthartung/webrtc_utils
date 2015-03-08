part of webrtc_utils.signaling;

class PeerMessage extends SignalingMessage {
  static const String TYPE = 'peer';
  String get type => TYPE;
  static const String KEY_ROOM = 'room';
  final String room;
  
  //PeerMessage(this.room, int id) : super(id);
  
  PeerMessage.fromObject(Map message) :
    super.fromObject(message),
    room = message[KEY_ROOM];
  /*
  Object toObject() {
    Map m = super.toObject();
    m[KEY_ROOM] = room;
    return m;
  }
  */
}