# webrtc_utils

The *webrtc_utils* package will help you to use WebRTC in your Dart applications. It offers different wrappers and extension points to help you with your application.


The purpose of this package is to hide necessary details from the user's application, thus it will not give you a detailed introduction into WebRTC.

## What is WebRTC

WebRTC is a library supported by Chrome, Opera and Firefox to enable web based Real Time Communication. WebRTC will establish a Peer to Peer (P2P) connection (*RtcPeerConnection*).

## Purpose of webrtc_utils

The webrtc_utils package will help you with two things:

1. Establishing P2P connections between two clients.

2. Establishing P2P connections between multiple clients.

3. Providing a basic signaling server

### DualPeerConnection

The *DualPeerConnection* class will help you with establishing a connection between a pair of peers. This is helpful when you have communication between two parties (e.g. simple desktop sharing or a video conversation).

#### Example

```
import 'dart:html';
import 'package:webrtc_utils/connections.dart';
import 'package:webrtc_utils/signaling.dart';

void main() {
  Map configuration = { "iceServers": [{ "url": "stun:stun.l.google.com:19302" }] };
  SignalingChannel signalingChannel = new WebSocketSignalingChannel("ws://...", new JsonSignalingTransformer());
  DualPeerConnection connection = new DualPeerConnection(configuration, signalingChannel);
  
  (querySelector('#connect') as ButtonElement).onClick.listen((MouseEvent ev) {
    connection.createDataChannel('test');
  });
  
  connection.onMessage.listen((MessageEvent ev) {
    print('Message received: ${ev.data}');
  });
}
```

The example uses the DualPeerConnection and the Google STUN server, to find your public IP address. We are using a websocket as the *SignalingChannel*. You can easily write other signaling channel classes. The transformer converts dart objects to strings (JSON). The transformer can be easily exchanged to support other protocol formats. The signaling server is available in *bin/server.dart*.

### MultiplePeerConnection

The *MultiplePeerConnection* class helps you to have a P2P connection with more than one other Peer. This is helpful if you want to implement some broadcast techniques (e.g. a chat or a multiplayer game).
