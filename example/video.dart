import 'package:webrtc_utils/client.dart';
import 'dart:html';

// window.location.hostname
const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://roberthartung.dyndns.org:28080';
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
  peer.onChannel.listen(_setupChannel);
}

void _setupChannel(RtcDataChannel channel) {
  print('Channel created');
  channel.onOpen.listen((_) {
    print('Channel opened');
    channel.send('Hello from ${client.id}');
  });
  channel.onMessage.listen((message) {
    print('Message in Channel ${channel.label}: $message');
  });
}

void main() {
  final UListElement peerList = querySelector('#peers');
  client = new WebSocketP2PClient(url, rtcConfiguration);
  
  client.onConnect.listen((final int id) {
    print('Now connected to the server with id $id');
    // After we're connect and got our ID, we can now join rooms
    if(window.location.hash != '') {
      client.join(window.location.hash.substring(1));
    }
  });
  
  window.onHashChange.listen((Event ev) {
    if(window.location.hash != '') {
      client.join(window.location.hash.substring(1));
    }
  });
  
  client.onJoinRoom.listen((final Room room) {
    print('I joined Room ${room.name} with peers ${room.peers}');
    
    // Loop through existing peers
    room.peers.forEach(_onPeerAdded);
    
    room.onLeave.listen((Peer peer) {
      print('Peer $peer left room ${room.name}');
    });
    
    room.onJoin.listen((Peer peer) {
      print('Peer $peer joined room ${room.name}');
      _onPeerAdded(peer);
      // When some joins, when we're already in the room: Initialize Communication
      print('Creating channel "chat".');
      peer.createChannel('chat');
      // Get webcam stream
      window.navigator.getUserMedia(video: true).then((MediaStream ms) {
        peer.addStream(ms);
      });
    });
  });
  
  /*
  //new JsonSerializer();
  m.onPeerConnected.listen((Peer peer) {
    peerList.appendHtml('<li class="peer" id="peer-${peer.id}">Peer #${peer.id} - <button id="start-peer-${peer.id}">Start Camera</button></li>');
    
    LIElement li = querySelector('#peer-${peer.id}');
    ButtonElement button = querySelector('#start-peer-${peer.id}');
    
    bool cameraConnected = false;
    MediaStream camera;
    
    peer.onAddStream.listen((MediaStreamEvent ev) {
      // TODO(rh): It looks like it is not possible to receive the own stream.
      if(ev.stream == camera) {
        print('Own camera stream added.');
        return;
      }
      MediaStream ms = ev.stream;
      
      String url = Url.createObjectUrlFromStream(ms);
      document.body.appendHtml('<div id="camera-peer-${peer.id}"><p>Stream for Peer #${peer.id}</p><video controls autoplay src="${url}"></video></div>');
      print('[Peer] Stream received (${url}) (${ms}) (${ms.ended})');
    });
    
    peer.onRemoveStream.listen((MediaStreamEvent ev) {
      // TODO(rh): It looks like it is not possible to receive the own stream.
      if(ev.stream == camera) {
        print('Own camera stream removed.');
        return;
      }
      print('Camera removed.');
      querySelector('#camera-peer-${peer.id}').remove();
    });
    
    button.onClick.listen((MouseEvent ev) {
      print('Button clicked');
      if(cameraConnected) {
        print('Camera connected: Now stopping');
        camera.stop();
        button.text = 'Start Camera';
        peer.removeStream(camera);
        querySelector('#preview').remove();
      } else {
        print('Camera not connected: Now starting');
        button.text = 'Stop Camera';
        // TODO(rh): It looks like the stream does not start, until it is played LOCALLY!
        // TODO(rh): Maybe it's not the local playback but the internet/network connection that keeps the stream from playing
        window.navigator.getUserMedia(video: true).then((MediaStream ms) {
          camera = ms;
          peer.addStream(ms);
          VideoElement preview = new VideoElement();
          preview.id = 'preview';
          preview.src = Url.createObjectUrlFromStream(ms);
          preview.controls = true;
          preview.autoplay = true;
          document.body.append(preview);
        });
        
        /*
        if(m.localPeerId < peer.id) {
          peer.createChannel('test');
        }
        */
      }
      cameraConnected = !cameraConnected;
    });
    
    print('Peer connected: ${peer.id}');
    peer.onChannelCreated.listen((RtcDataChannel channel) {
      channel.onMessage.listen((MessageEvent ev) {
        print('Message from Peer ${peer.id}: ${ev.data}');
      });
      
      channel.onOpen.listen((Event ev) {
        channel.send('Hello from ${m.localPeerId}');
      });
    });
  });
  */
}