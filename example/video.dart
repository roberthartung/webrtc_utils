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
  //new JsonSerializer();
  TargetedSignalingChannelTransformer transformer = new JsonTargetSignalingTransformer();
  TargetedSignalingChannel signalingChannel = new TargetedWebSocketSignalingChannel(url, transformer);
  MultiplePeerConnection m = new MultiplePeerConnection(rtcConfiguration, signalingChannel);
  m.onPeerConnected.listen((Peer peer) {
    print('Peer connected: ${peer.id}');
    peer.onChannelCreated.listen((RtcDataChannel channel) {
      channel.onMessage.listen((MessageEvent ev) {
        print('Message from Peer ${peer.id}: ${ev.data}');
      });
      
      channel.onOpen.listen((Event ev) {
        channel.send('Hello from ${m.localPeerId}');
      });
    });
    
    if(m.localPeerId < peer.id) {
      // Only create Channel if we got the lower ID
      window.navigator.getUserMedia(video: true).then((MediaStream stream) {
        print('Add stream');
        peer.addStream(stream);
        peer.createChannel('test');
      });
    }
  });
}