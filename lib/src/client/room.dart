/**
 * The concept of a room is to reuse the signaling server for lots of [Peer]s.
 * A room can be password protected (server side).
 * 
 * The PeerRoom class holds a list of [Peer]s that are in this room 
 */

part of webrtc_utils.client;

class PeerRoom<P extends Peer, C extends P2PClient> {
  /**
   * Name of the room
   */
  
  final String name;

  /**
   * Client instance for this room - passed to the peer to exchange signaling messages
   */
  
  final C client;
  
  /**
   * Internal Map of peers
   */
  
  final Map<int, P> _peers = {};
  
  /**
   * Getter of Peers
   */
  
  Iterable<P> get peers => _peers.values;

  /**
   * Stream of [P] objects who joined the channel
   */
  
  Stream<P> get onPeerJoin => _onPeerJoinController.stream;
  StreamController<P> _onPeerJoinController = new StreamController.broadcast();
  
  /**
   * Stream of [P] objects who left this channel
   */
  
  StreamController<P> _onPeerLeaveController = new StreamController.broadcast();
  Stream<P> get onPeerLeave => _onPeerLeaveController.stream;

  /**
   * Library internal constructor
   */
  
  PeerRoom._(this.client, this.name);
  
  /**
   * Signaling message received from the signaling server
   * The argument should always be a [SessionDescriptionMessage] or
   * [IceCandidateMessage] message. The rest is handled directly by the client
   */
  
  void _onSignalingMessage(SignalingMessage sm) {
    // In this case the peerId of the [SignalingMessage] is the source peerId
    final P peer = _peers[sm.peerId];
    final RtcPeerConnection pc = peer._pc;
    
    if(sm is SessionDescriptionMessage) {
      RtcSessionDescription desc = sm.description;
      if(desc.type == 'offer') {
        pc.setRemoteDescription(desc).then((_) {
          pc.createAnswer().then((RtcSessionDescription answer) {
            pc.setLocalDescription(answer).then((_) {
              client._signalingChannel.send(new SessionDescriptionMessage(name, peer.id, answer));
            });
          });
        });
      } else {
        pc.setRemoteDescription(desc);
      }
    } else if(sm is IceCandidateMessage) {
      pc.addIceCandidate(sm.candidate, () { /* ... */ }, (error) {
        print('[ERROR] Unable to add IceCandidateMessage: $error');
      });
    }
  }
  
  /**
   * Add peer to the room and fire event
   */
  
  void _addPeer(P peer) {
    _peers[peer.id] = peer;
    _onPeerJoinController.add(peer);
  }
  
  /**
   * Remove peer from room and fire event
   */
  
  void _removePeer(int peerId) {
    _onPeerLeaveController.add(_peers.remove(peerId));
  }
  
  /**
   * Sends a message to all peers on a specific channel
   * It will check if the channel exists and if it is open.
   *  
   * Returns the number of peers that have not received the message
   */
  
  int sendToChannel(String channelLabel, dynamic message) {
    int notSendCount = 0;
    peers.forEach((Peer peer) {
      final RtcDataChannel channel = peer.channels[channelLabel];
      if(channel != null && channel.readyState == 'open') {
        channel.send(message);
      } else {
        notSendCount++;
      }
    });
    return notSendCount;
  }
}

/**
 * A room consisting of [ProtocolPeers] that is a peer that's using
 * a [DataChannelProtocol] on top of [RtcDataChannel]
 */

class ProtocolPeerRoom extends PeerRoom<ProtocolPeer, ProtocolP2PClient> {
  ProtocolPeerRoom._(client, name) : super._(client, name);
  
  void sendToProtocol(String channelLabel, dynamic message) {
    peers.forEach((ProtocolPeer peer) {
      final DataChannelProtocol protocol = peer.protocols[channelLabel];
      if(protocol != null && protocol.channel.readyState == 'open') {
        print('[$this] Sending $message to $peer/$channelLabel via $protocol');
        protocol.send(message);
      }
    });
  }
}