library webrtc_utils.connections;

// Rtc*
import 'dart:html';
// StreamController
import 'dart:async';

import 'signaling.dart';

part 'src/connections/dual_peer.dart';
part 'src/connections/multiple_peer.dart';

/*
const Map configuration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};

WebSocket signalingWebSocket;

String gameId = "test";

Map<int,RtcPeerConnection> connections = {};

RtcPeerConnection connection;

int myClientId = null;
bool initializer = null;
RtcDataChannel channel;
*/

/*
void connectToClient(int id, bool initiate) {
  initializer = initiate;
  connection = new RtcPeerConnection(configuration);
  connections[id] = connection;
  
  connection.onAddStream.listen((MediaStreamEvent ev) {
    print('Connection.addStream');
  });
  
  connection.onIceConnectionStateChange.listen((Event ev) {
    print('Connection.iceConnectionStateChange');
  });
  
  connection.onIceCandidate.listen((RtcIceCandidateEvent ev) {
    if(ev.candidate != null) {
      RtcIceCandidate candidate = ev.candidate;
      print('${candidate.candidate} - ${candidate.sdpMid} - ${candidate.sdpMLineIndex}');
      signalingWebSocket.sendString(JSON.encode({'type': 'candidate', 'candidate': {'candidate': candidate.candidate, 'sdpMid': candidate.sdpMid, 'sdpMLineIndex': candidate.sdpMLineIndex}}));
    } else {
      print('No more candidates');
    }
  });
  
  connection.onNegotiationNeeded.listen((Event ev) {
    print('Connection.negotiationNeeded');
    // Send offer to the other peer
    connection.createOffer({}).then((RtcSessionDescription desc) {
      connection.setLocalDescription(desc).then((_) {
        signalingWebSocket.send(JSON.encode({ "type" : "sdp", "sdp": {'sdp': connection.localDescription.sdp, 'type': connection.localDescription.type}}));
      });
    }).catchError((err) {
      print('error at offer: $err');
    });
  });
  
  bool sendDescription = false;
  
  // Called for both changes in remote and local description changes
  // Ignore the event for the answer! for now we use a flag ([sendDescription])
  // Maybe use .first here?
  /*
  connection.onSignalingStateChange.listen((Event ev) {
    print('Connection.signalingStateChange');
    if(initializer && !sendDescription) {
      sendDescription = true;
      signalingWebSocket.send(JSON.encode({ "type" : "sdp", "sdp": {'sdp': connection.localDescription.sdp, 'type': connection.localDescription.type}}));
    }
  });
  */
  
  if(initiate) {
    // Preserve order
    channel = connection.createDataChannel('game', {'ordered': true});
    print('channel: $channel');
    setupChannel();
  } else {
    connection.onDataChannel.listen((RtcDataChannelEvent ev) {
      print('Connection.dataChannel');
      channel = ev.channel;
      setupChannel();
    });
  }
}

void setupChannel() {
  channel.onOpen.listen((Event ev) {
    print('Channel.open');
    // enableCommunication()
    channel.send('testMessage');
  });
  
  channel.onMessage.listen((MessageEvent ev) {
    print('Channel.message: ${ev.data}');
  });
  
  channel.onClose.listen((Event ev) {
    print('Channel.close');
  });
  
  channel.onError.listen((Event ev) {
    print('Channel.error');
  });
}
*/

// part 'src/connections/helper.dart';

enum MessageFormat {JSON}
enum SignalingType {WEBSOCKET}