# webrtc_utils

The *webrtc_utils* package will help you to use WebRTC (See: [Official Website](http://www.webrtc.org/), [W3C](http://www.w3.org/TR/webrtc/)) in your Dart applications. It offers different wrappers and extension points to help you with your application and to make your life easier. The purpose of this package is to hide necessary details from the user's application, but also give you the the ability and freedom to use your own extensions.

## What is WebRTC

WebRTC is a concept supported by Chrome, Opera and Firefox to enable **Web** based **R**eal **T**ime **C**ommunication. WebRTC will establish a Peer-to-Peer (P2P) connection (*RtcPeerConnection*) between two browsers. This connection can be used to exchange data. The following types of data exchange are supported:

1. **Streams** (like video or audio captured from a webcam or the desktop, later requires your app to be a (chrome) extensions) 
2. **List of bytes** (any type of messages using *RtcDataChannel*, like strings (chat messages) or other information that can be represented as a series of bytes)

### Concept & Architecture

WebRTC needs a server to exchance initial connection information. There information are called *signaling* messages. The server that handles these messages is called the *signaling* server. A WebRTC connection is always established between two peers (computers, browsers). WebRTC uses the [ICE protocol](en.wikipedia.org/wiki/Interactive_Connectivity_Establishment) to find your public IP address. These implementation details are hidden from the user. The only exception is that you have to provide a *RtcConfiguration*, usually this is a map listing [TURN](http://en.wikipedia.org/wiki/Traversal_Using_Relays_around_NAT) servers. Note that there are a lot of public servers that you can use.

## Purpose of webrtc_utils

The webrtc_utils package will help you with ...

- **Establishing P2P connections**: Using an abstract implementation of *Peer*, *Room* and *P2PClient*
- **Using protocols for byte based data channels**: *webrtc_utils* uses the concept of a protocol that is implemented on top of a *RtcDataChannel*. The protocol wraps messages into a transferrable format.
- **Setting up a SignalingServer**: *webrtc_utils* comes with an example implementation of a WebSocket based SignalingServer that provides both the server and client side.

## Concepts

### Rooms

*webrtc_utils* uses the concept of rooms. A room is a set of peers that is identified by a name (String). When you are connected to the signaling server you can join rooms (using an optional password). You can listen to the *onJoinRoom* stream of *P2PClient* when you want to get notified about joining a channel. Example:

### Protocols

Usually a *RtcDataChannel* can transfer only native types of data (like Blobs, ByteBuffers/ArrayBuffers or strings). To make it easier to handle more complex data, *webrtc_utlils* uses the concept of protocols. A general interface called *DataChannelProtocol* is provided. A *RtcDataChannel* comes already with a [protocol property](http://w3c.github.io/webrtc-pc/#widl-RTCDataChannel-protocol). 

## Implementations

### P2PClient

The P2PClient is the abstract client side endpoint that should be used as the interface for all of your implementations. *webrtc_utils* comes with a concrete WebSocket implementation **WebSocketP2PClient** that can be used along with the WebSocketSignalingServer to create a WebRTC based application very fast. The *P2PClient* class provides a set of methods and streams to be used directly in your application. The *P2PClient* class supports both *rooms* and *protocols*. To join a room call the *join(name, [password])* method. The *onJoinRoom* stream will notify you when you successfully joined a room. To support your own protocols the *P2PClient* provides a method called *addProtocolProvider(String, ProtocolProvider)* that let's you assign a protocol provider to a protocol. When a *RtcDataChannel* a *protocol* property set, it will try to get the corresponding ProtocolProvider and will return te concrete implementation of a *DataChannelProtocol*. If not it will return a *RawProtocol*.

## Examples

There are a lot of examples included with the package. Just browse them and see how easy it is to use this package. Example applications that have been implemented are:

### P2PClient

```dart
const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
P2PClient client = new WebSocketP2PClient('ws://${window.location.hostname}:28080', rtcConfiguration);

client.onConnect.listen((_) {
  client.join('room');
  // client.join('room', 'password');
});

client.onJoinRoom.listen((Room room) {
  // Successfully connected to a room
  // room.peers contains a list of Peers that are connected to this channel
  // room.onJoin is a stream of peers that joined this channel after you
});
```

### Minimal (example/minimal)

A minimal example showing the minimal needed code.

### Webcam chat (example/video)

All users of a room share their webcam with others using the *getUserMedia* [API](http://w3c.github.io/mediacapture-main/getusermedia.html).

### Audo chat (example/audio)

All users of a room share their microphone

### File transfer (example/filetransfer)

A peer-to-peer file transfer implementation that uses HTML5 drag and drop to transfer files between two browsers. It partitions the file into chunks (16KB, needed because of UDP) and uses the ChunkedBlob protocol to re-assemble the chunks back to a file and downloads the file in the remote peer's browser.

### Signaling server

A sample implementation of a signaling server (bin/server.dart) that uses WebSockets for signaling.
