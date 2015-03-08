part of webrtc_utils.signaling;

class RoomMessage extends SignalingMessage {
  static const String TYPE = 'room';
  String get type => TYPE;
  final String name;
  
  final List<int> peers;
  
  // Only From Server
  // RoomMessage(this.room, int id) : super(id);
  
  RoomMessage.fromObject(Map message) :
    super.fromObject(message),
    name = message['name'],
    peers = message['peers'];
  /*
  Object toObject() {
    Map m = super.toObject();
    m[KEY_ROOM] = room;
    return m;
  }
  */
}