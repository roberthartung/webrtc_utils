import 'dart:html';
import 'package:chrome/chrome_ext.dart';
import 'package:webrtc_utils/client.dart';

const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://localhost:28080';
P2PClient client;

void _peerJoined(Peer peer) {
  print('Peer joined $peer');
  desktopCapture.chooseDesktopMedia(['screen'], (String streamId) {
    if(streamId == null || streamId == '') {
      print('No access');
      return;
    }
    
    print('streamId: $streamId');
    window.navigator.getUserMedia(video: {'mandatory': {'maxWidth': 1920, 'maxHeight': 1080, 'minFrameRate': 1, 'maxFrameRate': 60, 'chromeMediaSource': "desktop", 'chromeMediaSourceId': streamId }}).then((MediaStream ms) {
      peer.addStream(ms);
      VideoElement video = querySelector('#preview');
      video.autoplay = true;
      video.src = Url.createObjectUrlFromStream(ms);
    });
  });
}

void main() {
  client = new WebSocketP2PClient(url, rtcConfiguration);
  
  client.onConnect.listen((localId) {
    client.join('demo');
  });
  
  client.onJoinRoom.listen((Room room) {
    room.peers.forEach(_peerJoined);
    room.onJoin.listen(_peerJoined);
  });
  /*
  
  
  identity.getAccounts().then((List<AccountInfo> accounts) {
    print(accounts);
  });
  */
  
  identity.onSignInChanged.listen((OnSignInChangedEvent ev) {
    if(ev.signedIn) {
      identity.getProfileUserInfo().then((ProfileUserInfo info) {
        //print(info.id);
        print(info.email);
      });
    } else {
      print('User logged out.');
    }
  });
}

/*
VideoElement video = querySelector('#preview');
video.onPlay.listen((ev) {
  print('Width: ${video.videoWidth} Height: ${video.videoHeight}');
});

video.onLoadedMetadata.listen((ev) {
  print('Width: ${video.videoWidth} Height: ${video.videoHeight}');
});

desktopCapture.chooseDesktopMedia(['screen'], (String streamId) {
  print('streamId: $streamId');
  // 'minWidth': 1920, 'minHeight': 1080,
  window.navigator.getUserMedia(video: {'mandatory': {'maxWidth': 1920, 'maxHeight': 1080, 'chromeMediaSource': "desktop", 'chromeMediaSourceId': streamId }}).then((MediaStream ms) {
    video.autoplay = true;
    video.src = Url.createObjectUrlFromStream(ms);
  }).catchError((err) {
    if(err is NavigatorUserMediaError) {
      print('Message: ${err.message} ${err.name} ${err.constraintName}');
    } else {
      print('Unknown Error: $err');
    }
  });
});
 */