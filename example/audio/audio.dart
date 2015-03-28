import 'package:webrtc_utils/client.dart';
import 'dart:html';

// const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://${window.location.hostname}:28080';
P2PClient client;

void _onAddStream(Peer peer, MediaStream ms) {
  print('Stream added from Peer#${peer.id}: $ms');
  VideoElement video = new VideoElement();
  video.width = 300;
  video.autoplay = true;
  video.controls = true;
  video.src = Url.createObjectUrlFromStream(ms);
  document.body.append(video);
}

void _onPeerAdded(Peer peer) {
  print('Peer $peer joined');
  
  peer.onAddStream.listen((MediaStreamEvent ev) => _onAddStream(peer, ev.stream));
  
  if(share) {
    peer.addStream(localStream);
  }
}

MediaStream localStream;
bool share = false;

/**
 * Wasn't able to share first time
 */

void main() {
  final UListElement peerList = querySelector('#peers');
  client = new WebSocketP2PClient(url, rtcConfiguration);
  
  ButtonElement shareButton = querySelector('#share');
  shareButton.disabled = true;
  
  client.onConnect.listen((final int id) {
    window.navigator.getUserMedia(audio: true, video: true).catchError((error) {
      window.alert('Error when initializing: $error');
    }).then((MediaStream ms) {
      localStream = ms;
      VideoElement video = new VideoElement();
      video.width = 300;
      video.autoplay = true;
      video.muted = true;
      video.src = Url.createObjectUrlFromStream(localStream);
      document.body.append(video);
      client.join('audio');
    });
  });
  
  client.onJoinRoom.listen((final PeerRoom room) {
    shareButton.disabled = false;
    shareButton.onClick.listen((MouseEvent ev) {
      share = true;
      room.peers.forEach((Peer peer) {
        peer.addStream(localStream);
      });
    });
    
    print('I joined room ${room.name} with peers ${room.peers}');
    
    // Loop through existing peers
    room.peers.forEach(_onPeerAdded);
    
    room.onPeerLeave.listen((Peer peer) {
      print('Peer $peer left room ${room.name}');
    });
    
    room.onPeerJoin.listen((Peer peer) {
      _onPeerAdded(peer);
    });
  });
}