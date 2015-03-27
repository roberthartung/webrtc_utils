/**
 * A Peer on the client side. This is a remote client. The local peer is not represented as a Peer object!
 * 
 * Only Peer2Peer connections will be wrapped by the Peer class
 */

part of webrtc_utils.client;

class Peer<C extends P2PClient> {
  // The id of this peer. This ID is assigned by the signaling server
  final int id;
  
  // The room this peer belongs to
  final Room room;
  
  // The RtcPeerConnection
  final RtcPeerConnection _pc;
  
  // The P2PClient of this peer
  final C client;
  
  // EventStream when the remote peer adds a stream
  Stream<MediaStreamEvent> get onAddStream => _pc.onAddStream;
  
  // EventStream when the remote peer removes a stream
  Stream<MediaStreamEvent> get onRemoveStream => _pc.onRemoveStream;
  
  // Notifies when a new data channel was created locally or remotely
  Stream<RtcDataChannel> get onChannel => _onChannelController.stream;
  StreamController<RtcDataChannel> _onChannelController = new StreamController.broadcast();
  
  /**
   * Map of [RtcDataChannel] labels to their channels
   * TODO(rh): Do we actually need a map to save protocols?
   */
  
  final Map<String, RtcDataChannel> channels = {};
  
  // int _channelId = 1;
  
  /**
   * Internal constructor that is called from the [P2PClient]
   */
  
  Peer._(this.room, this.id, this.client, [Map mediaConstraints = const {'optional': const [const {'DtlsSrtpKeyAgreement': true}]}])
    : _pc = new RtcPeerConnection(rtcConfiguration, mediaConstraints) {
    _pc.onNegotiationNeeded.listen((Event ev) { 
      print('[$this] Connection.negotiationNeeded');
      // Send offer to the other peer
      _pc.createOffer({}).then((RtcSessionDescription desc) {
        _pc.setLocalDescription(desc).then((_) {
          client._signalingChannel.send(new SessionDescriptionMessage(room.name, id, desc));
        });
      }).catchError((err) {
        print('[$this] Error at offer: $err');
      });
    });
    
    _pc.onIceCandidate.listen((RtcIceCandidateEvent ev) {
      if(ev.candidate != null) {
        client._signalingChannel.send(new IceCandidateMessage(room.name, id, ev.candidate));
      }
    });
    
    _pc.onDataChannel.listen((RtcDataChannelEvent ev) {
      _notifyChannelCreated(ev.channel);
    });
    
//    // DEBUG
//    _pc.onSignalingStateChange.listen((Event ev) {
//      print('[Event] SignalingStateChange: ${_pc.signalingState}');
//    });
//    
//    _pc.onIceConnectionStateChange.listen((Event ev) {
//      print('[Event] IceConnectionStateChange: ${_pc.iceConnectionState} (${_pc.iceGatheringState})');
//    });
  }
  
  void _notifyChannelCreated(RtcDataChannel channel) {
    channels[channel.label] = channel;
    channel.onClose.listen((Event ev) {
      channels.remove(channel.label);
    });
    //print('[$this] Channel created: ${channel.label} with protocol ${channel.protocol}');
    _onChannelController.add(channel);
  }
  
  /**
   * Create a new RtcDataChannel with a given label
   */
  
  void createChannel(String label, [Map options = null]) {
    // id is an unsigned unsigned short
    /*
    if(options == null) {
      options = {'id': _channelId++};
    }
    */
    _notifyChannelCreated(_pc.createDataChannel(label, options));
  }
  
  /**
   * Adds a stream to this Peer (e.g. Webcam)
   * 
   * TODO(rh): Spec of mediaConstraints?
   */
  
  void addStream(MediaStream ms, [Map<String,String> mediaConstraints]) {
    _pc.addStream(ms);
  }
  
  /**
   * Removes a stream from this Peer
   */
  
  void removeStream(MediaStream ms) {
    _pc.removeStream(ms);
  }
  
  /**
   * Returns a string representation for this Peer
   */
  
  String toString() => 'Peer#$id';
}

/**
 * The [ProtocolPeer] extends [Peer] that by adding a [DataChannelProtocol] on top to the [RtcDataChannel].
 * It uses the [RtcDataChannel.protocol] property and a [ProtocolProvider] to provide application
 * specific protocols.
 */

class ProtocolPeer extends Peer<ProtocolP2PClient> {
  Stream<DataChannelProtocol> get onProtocol => _onProtocolController.stream;
  StreamController<DataChannelProtocol> _onProtocolController = new StreamController.broadcast();
  
  /**
   * Map of [RtcDataChannel] labels to their protocols
   * TODO(rh): Do we actually need a map to save protocols?
   */
  
  final Map<String, DataChannelProtocol> protocols = {};
  
  /**
   * Library-internal constructor
   */
  
  ProtocolPeer._(room, id, client) : super._(room, id, client);
  
  @override
  void _notifyChannelCreated(RtcDataChannel channel) {
    super._notifyChannelCreated(channel);
    DataChannelProtocol protocol = client._protocolProvider.provide(this, channel);
    print('[$this] Protocol: $protocol');
    if(protocol != null) {
      channel.onOpen.listen((Event ev) {
        print('Channel is open: ${channel.label}');
        _onProtocolController.add(protocol);
      });
      protocols[protocol.channel.label] = protocol;
    } else {
      throw "Protocol returned by ProtocolProvider ${client._protocolProvider} should not be null";
    }
  }
  
  /**
   * Returns a string representation for this ProtocolPeer
   */
  
  String toString() => 'ProtocolPeer#$id';
}