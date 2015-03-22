import 'dart:html';
import 'package:chrome/chrome_ext.dart';
import 'package:webrtc_utils/client.dart';

/*
  // contextMenus: Share links/pictures directly with users
  // omnibox: register keyword in adress bar
  // , "omnibox"
*/

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

final String url = 'ws://roberthartung.dyndns.org:28080';
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
  print('loaded');
  client = new WebSocketP2PClient(url, rtcConfiguration);
  
  client.onConnect.listen((localId) {
    print('I am connected. Joining room.');
    client.join('demo');
  });
  
  client.onJoinRoom.listen((Room room) {
    print('Joined room');
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