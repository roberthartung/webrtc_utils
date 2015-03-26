part of webrtc_utils.signaling;

abstract class SignalingMessage {
  String get type;
  
  // TODO(rh): Should we name it source?
  final int _peerId;
  
  int get peerId => _peerId;
  
  SignalingMessage(this._peerId);
  
  SignalingMessage.fromObject(Map data) : _peerId = data['peer']['id'];
  
  Map toObject() {
    return {'type': type, 'peer': {'id': peerId}};
  }
}

/**
 * A message that belongs to a room
 */

abstract class RoomMessage extends SignalingMessage {
  final String roomName;
  
  RoomMessage(roomName, int peerId) : super(peerId), this.roomName = roomName;
  
  RoomMessage.fromObject(Map data) : super.fromObject(data), roomName = data['room']['name'];
  
  Object toObject() {
    Map data = super.toObject();
    data['room'] = {'name': roomName};
    return data;
  }
}

class WelcomeMessage extends SignalingMessage {
  static const String TYPE = 'welcome';
  String get type => TYPE;
  WelcomeMessage(int id) : super(id);
  WelcomeMessage.fromObject(Map message) : super.fromObject(message);
}

/**
 * Ice Candidate message
 */

class IceCandidateMessage extends RoomMessage {
  static const String TYPE = 'rtc_ice_candidate';
  
  String get type => TYPE;
  
  static const String KEY = 'candidate';
  
  final RtcIceCandidate candidate;
  
  IceCandidateMessage(String room, int id, this.candidate) : super(room, id);
  
  IceCandidateMessage.fromObject(Map message) : super.fromObject(message), candidate = new RtcIceCandidate(message[KEY]);
  
  Object toObject() {
    Map m = super.toObject();
    m[KEY] = {'candidate' : candidate.candidate, 'sdpMid' : candidate.sdpMid, 'sdpMLineIndex' : candidate.sdpMLineIndex};
    return m;
  }
}

class SessionDescriptionMessage extends RoomMessage {
  static const String TYPE = 'rtc_session_description';
  String get type => TYPE;
  static const String KEY = 'desc';
  
  final RtcSessionDescription description;
  
  SessionDescriptionMessage(String roomName, int id, this.description) : super(roomName, id);

  SessionDescriptionMessage.fromObject(Map data) :
    super.fromObject(data),
    description = new RtcSessionDescription(data[KEY]);
  
  Object toObject() {
    Map m = super.toObject();
    
    String sdp = description.sdp;
    List<String> split = sdp.split("b=AS:30");
    if(split.length > 1) {
      sdp = split[0] + "b=AS:1638400" + split[1];
    }
    
    m[KEY] = {'sdp' : sdp, 'type' : description.type};
    
    return m;
  }
}

/**
 * Local client joined a room
 */

class RoomJoinedMessage extends RoomMessage {
  static const String TYPE = 'room_joined';
  String get type => TYPE;
  
  final List<int> peers;
  
  RoomJoinedMessage.fromObject(Map message) :
    super.fromObject(message),
    peers = message['peers'];
}

class RoomLeftMessage extends RoomMessage {
  static const String TYPE = 'room_left';
  String get type => TYPE;
  RoomLeftMessage.fromObject(Map message) :
    super.fromObject(message);
}

class JoinRoomMessage extends RoomMessage {
  static const String TYPE = 'join_room';
  static const String KEY_PASSWORD = 'password';
  String get type => TYPE;
  
  final String password;
  
  JoinRoomMessage(roomName, this.password, int id) : super(roomName, id);
  
  JoinRoomMessage.fromObject(Map message) :
    super.fromObject(message),
    password = message[KEY_PASSWORD];
  
  Object toObject() {
    Map m = super.toObject();
    m[KEY_PASSWORD] = password;
    return m;
  }
}

class LeaveMessage extends RoomMessage {
  static const String TYPE = 'leave';
  String get type => TYPE;
  
  LeaveMessage.fromObject(Map message) :
    super.fromObject(message);
}

class JoinMessage extends RoomMessage {
  static const String TYPE = 'join';
  String get type => TYPE;
  
  JoinMessage.fromObject(Map message) :
    super.fromObject(message);
}