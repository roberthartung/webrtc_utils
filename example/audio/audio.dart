import 'package:webrtc_utils/client.dart';
import 'dart:html';

final String url = 'ws://${window.location.hostname}:28080';
MediaStream localStream;
bool share = false;

void _onPeerAdded(Peer peer) {
  print('Peer $peer joined');
  peer.onAddStream.listen((MediaStreamEvent ev) => appendStream(ev.stream));
  if(share) {
    peer.addStream(localStream);
  }
}

MediaElement appendStream(MediaStream ms) {
  // Check type and create video or audio
  if(ms.getVideoTracks().length > 0) {
    VideoElement video = new VideoElement();
    video.width = 300;
    video.autoplay = true;
    video.controls = true;
    video.src = Url.createObjectUrlFromStream(ms);
    document.body.append(video);
    return video;
  } else if(ms.getAudioTracks().length > 0) {
    AudioElement audio= new AudioElement();
    audio.autoplay = true;
    audio.controls = true;
    audio.src = Url.createObjectUrlFromStream(ms);
    document.body.append(audio);
    return audio;
  }
  
  throw "MediaStream $ms has no video or audio streams.";
}

void main() {
  P2PClient client = new WebSocketP2PClient(url, rtcConfiguration);
  
  ButtonElement shareButton = querySelector('#share');
  shareButton.disabled = true;
  
  client.onConnect.listen((final int id) {
    window.navigator.getUserMedia(audio: true).catchError((error) {
      window.alert('Error when initializing: $error');
    }).then((MediaStream ms) {
      localStream = ms;
      appendStream(ms).muted = true;
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
    room.peers.forEach(_onPeerAdded);
    room.onPeerLeave.listen((Peer peer) {
      print('Peer $peer left room ${room.name}');
    });
    room.onPeerJoin.listen((Peer peer) {
      _onPeerAdded(peer);
    });
  });
}