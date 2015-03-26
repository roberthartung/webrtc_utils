import 'package:webrtc_utils/client.dart';
import 'dart:html';

const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://${window.location.hostname}:28080';
P2PClient client;

void _onAddStream(Peer peer, MediaStream ms) {
  print('Stream added from Peer#${peer.id}: $ms');
  VideoElement video = new VideoElement();
  video.autoplay = true;
  video.controls = true;
  video.src = Url.createObjectUrlFromStream(ms);
  document.body.append(video);
}

void _onPeerAdded(Peer peer) {
  peer.onAddStream.listen((MediaStreamEvent ev) => _onAddStream(peer, ev.stream));
  
  window.navigator.getUserMedia(audio: true).then((MediaStream ms) {
    peer.addStream(ms);
  });
  
  //peer.onChannelCreated.listen(_setupChannel);
}

void main() {
  final UListElement peerList = querySelector('#peers');
  client = new WebSocketP2PClient(url, rtcConfiguration);
  
  client.onConnect.listen((final int id) {
    client.join('krypto');
  });
  
  client.onJoinRoom.listen((final Room room) {
    print('I joined Room ${room.name} with peers ${room.peers}');
    
    // Loop through existing peers
    room.peers.forEach(_onPeerAdded);
    
    room.onPeerLeave.listen((Peer peer) {
      print('Peer $peer left room ${room.name}');
    });
    
    room.onPeerJoin.listen((Peer peer) {
      print('Peer $peer joined room ${room.name}');
      _onPeerAdded(peer);
    });
  });
}