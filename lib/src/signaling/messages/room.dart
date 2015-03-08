part of webrtc_utils.signaling;

class RoomMessage extends SignalingMessage {
  static const String TYPE = 'room';
  String get type => TYPE;
  final String name;
  
  final List<int> peers;
  
  RoomMessage.fromObject(Map message) :
    super.fromObject(message),
    name = message['name'],
    peers = message['peers'];
}