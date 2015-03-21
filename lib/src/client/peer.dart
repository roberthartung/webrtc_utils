/**
 * A Peer on the client side. This is a remote client. The local peer is not represented as a Peer object!
 * 
 * Only Peer2Peer connections will be wrapped by the Peer class
 */

part of webrtc_utils.client;

class Peer {
  // The id of this peer. This ID is assigned by the signaling server
  final int id;
  
  // The room this peer belongs to
  final Room room;
  
  // The RtcPeerConnection
  final RtcPeerConnection _pc;
  
  // The signaling channel to send data to
  final SignalingChannel _signalingChannel;
  
  final ProtocolProvider _protocolProvider;
  
  // EventStream when the remote peer adds a stream
  Stream<MediaStreamEvent> get onAddStream => _pc.onAddStream;
  
  // EventStream when the remote peer removes a stream
  Stream<MediaStreamEvent> get onRemoveStream => _pc.onRemoveStream;
  
  // Notifies when a new data channel was created locally or remotely
  Stream<RtcDataChannel> get onChannel => _onChannelController.stream;
  StreamController<RtcDataChannel> _onChannelController = new StreamController.broadcast();
  
  Stream<DataChannelProtocol> get onProtocol => _onProtocolController.stream;
  StreamController<DataChannelProtocol> _onProtocolController = new StreamController.broadcast();
  
  /**
   * Map of [RtcDataChannel] labels to their protocols
   * 
   * TODO(rh): Do we need a map to save channels in the peer?
   */
  
  final Map<String, DataChannelProtocol> channels = {};
  
  // int _channelId = 1;
  
  /**
   * Internal constructor that is called from the [P2PClient]
   */
  
  Peer._(this.room, this.id, this._signalingChannel, Map rtcConfiguration, this._protocolProvider, [Map mediaConstraints = const {'optional': const [const {'DtlsSrtpKeyAgreement': true}]}]) : _pc = new RtcPeerConnection(rtcConfiguration, mediaConstraints) {
    _pc.onNegotiationNeeded.listen((Event ev) { 
      print('Connection.negotiationNeeded');
      // Send offer to the other peer
      _pc.createOffer({}).then((RtcSessionDescription desc) {
        _pc.setLocalDescription(desc).then((_) {
          _signalingChannel.send(new SessionDescriptionMessage(desc, id));
        });
      }).catchError((err) {
        print('error at offer: $err');
      });
    });
    
    _pc.onIceCandidate.listen((RtcIceCandidateEvent ev) {
      if(ev.candidate != null) {
        _signalingChannel.send(new IceCandidateMessage(ev.candidate, id));
      }
    });
    
    _pc.onDataChannel.listen((RtcDataChannelEvent ev) {
      _notifyChannelCreated(ev.channel);
    });
    
    /*
    _pc.onSignalingStateChange.listen((Event ev) {
      print('[Event] SignalingStateChange: ${_pc.signalingState}');
    });
    
    _pc.onIceConnectionStateChange.listen((Event ev) {
      print('[Event] IceConnectionStateChange: ${_pc.iceConnectionState} (${_pc.iceGatheringState})');
    });
    */
  }
  
  void _notifyChannelCreated(RtcDataChannel channel) {
    print('[$this] Channel created: ${channel.label} with protocol ${channel.protocol}');
    _onChannelController.add(channel);
    DataChannelProtocol protocol = _protocolProvider.provide(this, channel);
    if(protocol != null) {
      channel.onOpen.listen((Event ev) {
        _onProtocolController.add(protocol);
        print('[$this] Channel ${channel.label} is open.');
      });
      channels[protocol.channel.label] = protocol;
      print('[$this] Protocol: $protocol');
    } else {
      throw "Protocol returned by ProtocolProvider $_protocolProvider should not be null";
    }
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