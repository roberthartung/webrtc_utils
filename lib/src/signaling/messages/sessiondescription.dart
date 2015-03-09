part of webrtc_utils.signaling;

class SessionDescriptionMessage extends SignalingMessage {
  static const String TYPE = 'rtc_session_description';
  
  String get type => TYPE;
  
  static const String KEY = 'desc';
  
  final RtcSessionDescription description;
  
  SessionDescriptionMessage(this.description, int id) : super(id);

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