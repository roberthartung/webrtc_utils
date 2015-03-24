library webrtc_utils.client;

import 'dart:async';
import 'signaling.dart';
import 'converter.dart';
// JsonProtocol
import 'dart:convert';
// Rtc*
import 'dart:html';

part 'src/client/peer.dart';
part 'src/client/room.dart';
part 'src/client/p2p.dart';
part 'src/client/protocol.dart';

part 'src/client/signaling/channel.dart';
part 'src/client/signaling/websocket.dart';

part 'src/client/converter/message.dart';

const List iceServers = const [
  const {'url':'stun:stun01.sipphone.com'},
  const {'url':'stun:stun.ekiga.net'},
  const {'url':'stun:stun.fwdnet.net'},
  const {'url':'stun:stun.ideasip.com'},
  const {'url':'stun:stun.iptel.org'},
  const {'url':'stun:stun.rixtelecom.se'},
  const {'url':'stun:stun.schlund.de'},
  const {'url':'stun:stun.l.google.com:19302'}, 
  const {'url':'stun:stun1.l.google.com:19302'},
  const {'url':'stun:stun2.l.google.com:19302'},
  const {'url':'stun:stun3.l.google.com:19302'},
  const {'url':'stun:stun4.l.google.com:19302'},
  const {'url':'stun:stunserver.org'},
  const {'url':'stun:stun.softjoys.com'},
  const {'url':'stun:stun.voiparound.com'},
  const {'url':'stun:stun.voipbuster.com'},
  const {'url':'stun:stun.voipstunt.com'},
  const {'url':'stun:stun.voxgratia.org'},
  const {'url':'stun:stun.xten.com'}
];

const Map rtcConfiguration = const {"iceServers": iceServers};