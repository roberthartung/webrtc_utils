/// The concept of a room is to reuse the signaling server for lots of [Peer]s.
/// A room can be password protected (server side).
///
/// The PeerRoom class holds a list of [Peer]s that are in this room
part of webrtc_utils.client;

/// Interface for a room that holds a list of peers
abstract class PeerRoom<P extends Peer/*, C extends P2PClient*/> {
  /// Name of the room
  String get name;

  /*
  /// Client instance for this room - passed to the peer to exchange signaling messages
  C get client;
  */
  /// Iterable to iterate over all peers in this room
  Iterable<P> get peers;

  /// Listen to this stream to get notified when a peer leaves the room
  Stream<P> get onPeerJoin;

  /// Listen to this stream to get notified when a peer leaves the room
  Stream<P> get onPeerLeave;

  /// Call this method when you want to send a message to all peers that have
  /// a [RtcDataChannel] with label [channelLabel]. The type of [message] should
  /// compatible with [RtcDataChannel.send].
  ///
  /// Returns the number of peers that the message was NOT delivered to.
  int sendToChannel(String channelLabel, dynamic message);
}

/// An interface that supports sending messages via a protocol to a [ProtocolPeer]
/// Use [ProtocolP2PClient.setProtocolProvider] to set the instance of your
/// [ProtocolProvider].
abstract class ProtocolPeerRoom<P extends ProtocolPeer/*, C extends ProtocolP2PClient*/> extends PeerRoom<P/*, C*/> {
  /// Call this method when you want to send a message to all peers that have
  /// a [DataChannelProtocol] with an [RtcDataChannel.label] of [channelLabel].
  ///
  /// The type of [message] should compatible with your protocol. See
  /// [DataChannelProtocol] and [ProtocolProvider]
  ///
  /// Returns the number of peers that the message was NOT delivered to.
  void sendToProtocol(String channelLabel, dynamic message);
}

/// Internal implementation of a [PeerRoom]
class _PeerRoom<P extends _Peer, C extends _P2PClient>
    implements PeerRoom<P> {
  final String name;

  final C client;

  /// Internal Map of peers
  final Map<int, P> _peers = {};

  Iterable<P> get peers => _peers.values;

  Stream<P> get onPeerJoin => _onPeerJoinController.stream;
  StreamController<P> _onPeerJoinController =
      new StreamController.broadcast();

  Stream<P> get onPeerLeave => _onPeerLeaveController.stream;
  StreamController<P> _onPeerLeaveController =
      new StreamController.broadcast();

  _PeerRoom(this.client, this.name);

  /// Signaling message received from the signaling server
  /// The argument should always be a [SessionDescriptionMessage] or
  /// [IceCandidateMessage] message. The rest is handled directly by the client
  void onSignalingMessage(SignalingMessage sm) {
    // In this case the peerId of the [SignalingMessage] is the source peerId
    final _Peer peer = _peers[sm.peerId];
    peer._handleSignalingMessage(sm);
  }

  /// Add peer to the room and fire event
  void addPeer(_Peer peer) {
    _peers[peer.id] = peer;
    _onPeerJoinController.add(peer);
  }

  /// Remove peer from room and fire event
  void removePeer(int peerId) {
    _onPeerLeaveController.add(_peers.remove(peerId));
  }

  /// Sends a message to all peers on a specific channel
  /// It will check if the channel exists and if it is open.
  ///
  /// Returns the number of peers that have not received the message
  int sendToChannel(String channelLabel, dynamic message) {
    int notSendCount = 0;
    peers.forEach((_Peer peer) {
      final RtcDataChannel channel = peer.channels[channelLabel];
      if (channel != null && channel.readyState == 'open') {
        channel.send(message);
      } else {
        notSendCount++;
      }
    });
    return notSendCount;
  }
}

/// A room consisting of [ProtocolPeers] that is a peer that's using
/// a [DataChannelProtocol] on top of [RtcDataChannel]
class _ProtocolPeerRoom extends _PeerRoom<_ProtocolPeer, _ProtocolP2PClient>
    implements ProtocolPeerRoom<_ProtocolPeer/*, _ProtocolP2PClient*/> {
  _ProtocolPeerRoom(client, name) : super(client, name);

  int sendToProtocol(String channelLabel, dynamic message) {
    int notSendCount = 0;
    peers.forEach((_ProtocolPeer peer) {
      final DataChannelProtocol protocol = peer.protocols[channelLabel];
      if (protocol != null && protocol.channel.readyState == 'open') {
        print('[$this] Sending $message to $peer/$channelLabel via $protocol');
        protocol.send(message);
      } else {
        notSendCount++;
      }
    });
    return notSendCount;
  }
}