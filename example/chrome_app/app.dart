import 'dart:html';
import 'package:chrome/chrome_ext.dart';
import 'package:webrtc_utils/client.dart';

/*
  // contextMenus: Share links/pictures directly with users
  // omnibox: register keyword in adress bar
  // , "omnibox"
*/

final String url = 'ws://signaling.roberthartung.de:28080';
P2PClient client;

void _peerJoined(Peer peer) {
  print('Peer joined $peer');
  // Open Dialog
  desktopCapture.chooseDesktopMedia(['screen', 'window'], (String streamId) {
    if(streamId == null || streamId == '') {
      print('No access');
      return;
    }

    print('streamId: $streamId');
    window.navigator.getUserMedia(video: {'mandatory': {'maxWidth': 1920, 'maxHeight': 1080, 'minFrameRate': 15, 'maxFrameRate': 30, 'chromeMediaSource': "desktop", 'chromeMediaSourceId': streamId }}).then((MediaStream ms) {
      peer.addStream(ms);
      ms.getTracks().forEach((MediaStreamTrack track) {
        print('Track $track ${track.kind} ${track.id} ${track.label}');

      });
      VideoElement video = querySelector('#preview');
      video.autoplay = true;
      video.src = Url.createObjectUrlFromStream(ms);
    });
  });
}

void main() {
  client = new WebSocketP2PClient(url, rtcConfiguration);

  client.onDisconnect.listen((d) {
    print('Disconnected: $d');
  });

  client.onError.listen((r) {
    print('Error: $r');
  });

  client.onConnect.listen((localId) {
    print('I am connected. Joining room.');
    client.join('demo');
  });

  client.onJoinRoom.listen((PeerRoom room) {
    print('Joined room');
    room.peers.forEach(_peerJoined);
    room.onPeerJoin.listen(_peerJoined);
  });

  identity.getAccounts().then((List<AccountInfo> accounts) {
    print(accounts);
  });

  identity.onSignInChanged.listen((OnSignInChangedEvent ev) {
    if(ev.signedIn) {
      print('User logged in.');
      identity.getProfileUserInfo().then((ProfileUserInfo info) {
        print('RoomName: ${info.email} Password: ${info.id}');
        client.join(info.email, info.id);
        InputElement a = querySelector('#localroomname');
        a.value = 'http://webrtc.rhscripts.de/example/video.html#' + Uri.encodeFull(info.email);
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