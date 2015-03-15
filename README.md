# webrtc_utils

The *webrtc_utils* package will help you to use WebRTC in your Dart applications. It offers different wrappers and extension points to help you with your application and to make your life easier. The purpose of this package is to hide necessary details from the user's application, but also give you the the ability and freedom to use your own extensions.

## What is WebRTC

WebRTC is a concept supported by Chrome, Opera and Firefox to enable **Web** based **R**eal **T**ime **C**ommunication. WebRTC will establish a Peer-to-Peer (P2P) connection (*RtcPeerConnection*) between two browsers. This connection can be used to exchange data. The following types of data exchange are supported:

1. **Streams** (like video or audio captured from a webcam or the desktop, later requires your app to be a (chrome) extensions) 
2. **List of bytes** (any type of messages using *RtcDataChannel*, like strings (chat messages) or other information that can be represented as a series of bytes)

## Purpose of webrtc_utils

The webrtc_utils package will help you with ...

- **Establishing P2P connections**: Using an abstract implementation of *Peer*, *Room* and *P2PClient*
- **Using protocols for byte based data channels**: *webrtc_utils* uses the concept of a protocol that is implemented on top of a *RtcDataChannel*. The protocol wraps messages into a transferrable format.
- **Setting up a SignalingServer**: *webrtc_utils* comes with an example implementation of a WebSocket based SignalingServer that provides both the server and client side.

## Examples 

There are a lot of examples included with the package. Just browse them and see how easy it is to use this package.
