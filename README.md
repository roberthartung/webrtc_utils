# webrtc_utils

The *webrtc_utils* package will help you to use WebRTC (See: [Official Website](http://www.webrtc.org/), [W3C](http://www.w3.org/TR/webrtc/)) in your [Dart](http://www.dartlang.org) applications. It offers various extension points and basic implentations to help you with your application and to make your life easier. The purpose of this package is to hide necessary details from the user's application, but also give you the the ability and freedom to use your own extensions where necessary.

There are three important libraries in the package: *game*, *client* and *server*. For an explanation of these see [Purpose of webrtc_utils](#purpose-of-webrtc_utils).

## Architecture Overview

The architecture of the *webrtc_utils* is shown below. You can see the different classes that the package provides. Note that the architecture does not include the *server* library.

![](https://github.com/roberthartung/webrtc_utils/raw/master/doc/architecture.png)

# What is WebRTC

WebRTC is a concept supported by Chrome, Opera and Firefox to enable **Web** based **R**eal **T**ime **C**ommunication. WebRTC will establish a Peer-to-Peer (P2P) connection (*RtcPeerConnection*) between two browsers. This connection can be used to exchange data. The following types of data exchange are supported:

1. **Streams** (like video or audio captured from a webcam or the desktop, later requires your app to be an extensions/addon (at least in chrome)) 
2. **List of bytes** (any type of messages using *RtcDataChannel*, like strings (chat messages) or other information that can be represented as a series of bytes)

For more information please refer to the official websites and sources.

### Concept & Architecture

WebRTC needs a server to exchance initial connection information. There information are called *signaling* messages. The server that handles these messages is called the *signaling server*. A WebRTC connection is always established between two peers (computers, browsers). Thus they need to exchange their public IP Addresses. WebRTC uses the [ICE protocol](en.wikipedia.org/wiki/Interactive_Connectivity_Establishment) to find these. These implementation details are hidden from the user. The only exception is that you have to provide a *RtcConfiguration*, usually this is a map listing [TURN](http://en.wikipedia.org/wiki/Traversal_Using_Relays_around_NAT) servers. Note that there are a lot of public servers that you can use and the *client* library already has such a list you can use.

Note that the *webrtc_utils* package uses a lot of interfaces that are provided to you. The actual implementations are private to the library.

## Purpose of webrtc_utils
The webrtc_utils package will help you with ...

### server
- **Setting up a SignalingServer**: *webrtc_utils* comes with an example implementation of a WebSocket based SignalingServer.

### client
- **Establishing basic P2P connections**: Using [*Peer*](http://www.dartdocs.org/documentation/webrtc_utils/latest/index.html#webrtc_utils/webrtc_utils-client.Peer), *PeerRoom* and *P2PClient*
- **Using protocols for byte based data channels**: *webrtc_utils* uses the concept of a protocol that is implemented on top of a *RtcDataChannel*. The protocol wraps messages into a transferrable format. You should use *ProtocolPeer*, *ProtocolPeerRoom* and *ProtocolP2PClient* for these. Implement your own *ProtocolProvider* to provide *DataChannelProtocol*s for a *RtcDataChannel*.

### game
- **Creating P2P games**: *webrtc_utils* uses the concept of a *local* and a *remote* player. The according instances have to be implemented by your application. Just implement a *PlayerFactory* and pass it to the game.
- **Creating synchronized P2P games**: A synchronized game adds global time to a game. This is helpful if you need to rely on time or ticks. The *synchronized* versions of the *P2PGame* classes will automatically synchronize the time and ticks for all players.

## Concepts

### Rooms

*webrtc_utils* uses the concept of rooms. A room is a set of peers that is identified by a name (string). When you are connected to the signaling server you can join rooms (using an optional password). You can listen to the *onJoinRoom* stream of *P2PClient* when you want to get notified about joining a channel. The same applies to the protocol version of the room.

### Protocols

Usually a *RtcDataChannel* can transfer only native types of data (like Blobs, ByteBuffers/ArrayBuffers or Strings). To make it easier to handle more complex data, *webrtc_utlils* uses the concept of protocols. A general interface called *DataChannelProtocol* is provided. A *RtcDataChannel* comes already with a [protocol property](http://w3c.github.io/webrtc-pc/#widl-RTCDataChannel-protocol) that is used to exchange the name (type) of the protocol internally. A protocol has to implement the *DataChannelProtocol* interface and has to be instantiated in a *ProtocolProvider* that you will implement for your application.

## Implementations / Entry points

There are only a few entry points you will use directly in your application (e.g. creating objects from or extending them). These are:

### WebSocketP2PClient

An implementation of the *P2PClient* interface that uses a websocket to exchange signaling messages.

### WebSocketProtocolP2PClient

An implementation of the *ProtocolP2PClient* client that will use protocols on top of each DataChannel.

### WebSocketP2PGame

A basic implementation of a websocket based P2P game.

### SynchronizedWebSocketP2PGame

An exteion of *WebSocketP2PGame* that will automatically synchronize time across all players (peers).

## Examples

There are a lot of examples included with the package. Just browse them and see how easy it is to use this package.
