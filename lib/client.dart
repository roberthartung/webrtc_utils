/**
 * The client library of this package. Provides several implementations that
 * can be used in a variety of applications and use cases.
 * 
 * For an introduction to WebRTC and a good architecture overview see the README.md
 * 
 * See [P2PClient]/[ProtocolP2PClient], [WebSocketP2PClient]/[WebSocketProtocolP2PClient]
 * for main entry points used by your app.
 * 
 * See also [Peer]/[ProtocolPeer] and [PeerRoom]/[ProtocolPeerRoom]
 * 
 * If you want to build a browser based, P2P game see the game library of this package
 */

library webrtc_utils.client;

import 'dart:async' show Future, Stream, StreamController;
import 'signaling.dart';
import 'dart:convert' show JSON;
import 'dart:html' show RtcDataChannel, RtcDataChannelEvent, RtcPeerConnection, Event, RtcIceCandidate, RtcIceCandidateEvent, MessageEvent, CloseEvent, WebSocket, RtcSessionDescription, MediaStream, MediaStreamEvent;

part 'src/client/peer.dart';
part 'src/client/room.dart';
part 'src/client/client.dart';
part 'src/client/protocol.dart';
part 'src/client/signaling.dart';

/**
 * A const list of iceServers that you can use to determine the client's public
 * IP address
 */

const List iceServers = const [
  //const {'url':'stun:stun01.sipphone.com'},
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

/**
 * A sample rtcConfiguration that you can use
 */

const Map rtcConfiguration = const {"iceServers": iceServers};