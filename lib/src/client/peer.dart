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
  
  final Map<String, ProtocolProvider> _protocolProviders;
  
  // EventStream when the remote peer adds a stream
  Stream<MediaStreamEvent> get onAddStream => _pc.onAddStream;
  
  // EventStream when the remote peer removes a stream
  Stream<MediaStreamEvent> get onRemoveStream => _pc.onRemoveStream;
  
  // Notifies yourself when a new data channel was created locally or remotely
  Stream<DataChannelProtocol> get onChannelCreated => _onChannelCreatedController.stream;
  StreamController<DataChannelProtocol> _onChannelCreatedController = new StreamController.broadcast();
  
  // int _channelId = 1;
  
  /**
   * Internal constructor that is called from the [P2PClient]
   */
  
  Peer._(this.room, this.id, this._signalingChannel, Map rtcConfiguration, this._protocolProviders, [Map mediaConstraints = const {'optional': const [const {'DtlsSrtpKeyAgreement': true}]}]) : _pc = new RtcPeerConnection(rtcConfiguration, mediaConstraints) {
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
    switch(channel.protocol) {
      case 'string' :
        _onChannelCreatedController.add(new StringProtocol(channel));
        break;
      default :
        if(_protocolProviders.containsKey(channel.protocol)) {
          _onChannelCreatedController.add(_protocolProviders[channel.protocol].provide(channel));
        } else {
          _onChannelCreatedController.add(new RawProtocol(channel));
        }
        break;
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
    RtcDataChannel channel = _pc.createDataChannel(label, options);
    _notifyChannelCreated(channel);
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