import 'package:webrtc_utils/webrtc_utils.dart';
import 'dart:html';
import 'dart:convert';

const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://${window.location.hostname}:28080/test';

/*
abstract class Serializer {
  dynamic serialize(dynamic o);
  dynamic unserialize(dynamic o);
}

class JsonSerializer implements Serializer {
  dynamic _toEncodable(dynamic o) {
    throw "Unable to encode $o";
  }
  
  dynamic _reviver(dynamic k, dynamic v) {
    return v; 
  }
  
  String serialize(Object o) {
    return JSON.encode(o, toEncodable: _toEncodable);
  }
  
  Object unserialize(String o) {
    return JSON.decode(o, reviver: _reviver);
  }
}

class MessageSerializer extends JsonSerializer {
  dynamic serialize(SignalingMessage m) {
    // Convert message to Map (Object)
    return super.serialize(m);
  }
  
  dynamic unserialize(dynamic o) {
    return super.unserialize(o);
  }
}
*/
void main() {
  final UListElement peerList = querySelector('#peers');
  
  //new JsonSerializer();
  TargetedSignalingChannelTransformer transformer = new JsonTargetSignalingTransformer();
  TargetedSignalingChannel signalingChannel = new TargetedWebSocketSignalingChannel(url, transformer);
  MultiplePeerConnection m = new MultiplePeerConnection(rtcConfiguration, signalingChannel);
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
}