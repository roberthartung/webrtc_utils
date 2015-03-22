part of webrtc_utils.signaling;

class RoomJoinedMessage extends SignalingMessage {
  static const String TYPE = 'room_joined';
  String get type => TYPE;
  final String name;
  
  final List<int> peers;
  
  RoomJoinedMessage.fromObject(Map message) :
    super.fromObject(message),
    name = message['name'],
    peers = message['peers'];
}

class RoomLeftMessage extends SignalingMessage {
  static const String TYPE = 'room_left';
  String get type => TYPE;
  final String name;
  RoomLeftMessage.fromObject(Map message) :
    super.fromObject(message),
    name = message['name'];
}