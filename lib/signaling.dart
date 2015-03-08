/**
 * This library contains stuff 
 */

library webrtc_utils.signaling;

// Rtc*
import 'dart:html';

part 'src/signaling/messages/icecandidate.dart';
part 'src/signaling/messages/sessiondescription.dart';
part 'src/signaling/messages/joinroom.dart';
part 'src/signaling/messages/welcome.dart';
part 'src/signaling/messages/room.dart';
part 'src/signaling/messages/join.dart';
part 'src/signaling/messages/leave.dart';

/**
 * A signaling message that is transferred between peers
 */

abstract class SignalingMessage {
  String get type;
  
  // TODO(rh): Should we name it source?
  final int _peerId;
  
  int get peerId => _peerId;
  
  SignalingMessage(this._peerId);
  
  SignalingMessage.fromObject(Map data) : _peerId = data['peer']['id'];
  
  Object toObject() {
    return {'type': type, 'peer': {'id': peerId}};
  }
}