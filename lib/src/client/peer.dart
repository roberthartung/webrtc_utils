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
  
  // EventStream when the remote peer adds a stream
  Stream<MediaStreamEvent> get onAddStream => _pc.onAddStream;
  
  // EventStream when the remote peer removes a stream
  Stream<MediaStreamEvent> get onRemoveStream => _pc.onRemoveStream;
  
  // Notifies yourself when a new data channel was created locally or remotely
  Stream<RtcDataChannel> get onChannelCreated => _onChannelCreatedController.stream;
  StreamController<RtcDataChannel> _onChannelCreatedController = new StreamController.broadcast();
  
  // int _channelId = 1;
  
  /**
   * Internal constructor that is called from the [P2PClient]
   */
  
  Peer._(this.room, this.id, this._signalingChannel, Map rtcConfiguration, [Map mediaConstraints = const {'optional': const [const {'DtlsSrtpKeyAgreement': true}]}]) : _pc = new RtcPeerConnection(rtcConfiguration, mediaConstraints) {
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
      //print('[$this.EVENT:onDataChannel] ${ev.channel}');
      _onChannelCreatedController.add(ev.channel);
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
    print('[$this] Channel created: ${channel.label}');
    _onChannelCreatedController.add(channel);
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