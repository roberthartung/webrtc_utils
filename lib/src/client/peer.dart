/**
 * A Peer on the client side. This is a remote client. The local peer is not represented as a Peer object!
 * 
 * Only Peer2Peer connections will be wrapped by the Peer class
 */

part of webrtc_utils.client;

/**
 * Peer interface class
 */

abstract class Peer<C extends P2PClient> {
  /**
   * An integer representing the global id of this peer according to the
   * [SignalingServer]. This id must be unique for each SignalingServer connection
   * but might be re-used for multiple rooms.
   */
  
  int get id;
  
  /**
   * The room this Peer belongs to.
   */
  
  PeerRoom get room;
  
  /**
   * A reference to the [P2PClient]
   */
  
  C get client;
  
  /**
   * Map of [RtcDataChannel.label] to the channel
   */
  
  Map<String, RtcDataChannel> get channels;
  
  /**
   * Can be listened to, to get notified when a stream gets added
   */
  
  Stream<MediaStreamEvent> get onAddStream;
  
  /**
   * Can be listened to, to get notified when a stream gets removed
   */
  
  Stream<MediaStreamEvent> get onRemoveStream;
  
  /**
   * Can be listened to, to get informed when a new [RtcDataChannel] was created.
   * 
   * Note: You have to wait for the [RtcDataChannel.onOpen] event to be able
   * to send messages. 
   */
  
  Stream<RtcDataChannel> get onChannel;
  
  /**
   * Signals to create a new [RtcDataChannel] with this peer.
   */
  
  void createChannel(String label, [Map options = null]);
  
  /**
   * Adds a stream to this peer
   * 
   * The [ms] can be loaded using [window.navigator.getUserMedia].
   * 
   * The [mediaConstraints] map specifies mandatory/optional constraints for
   * the stream.
   * 
   * TODO(rh): Example configuration
   */
  
  void addStream(MediaStream ms, [Map<String,String> mediaConstraints]);
  
  /**
   * Removes a stream from this peer
   */
  
  void removeStream(MediaStream ms);
}

/**
 * An interface for a protocol peer that extends the regular peer 
 */

abstract class ProtocolPeer<C extends P2PClient> extends Peer<C> {
  /**
   * Map of [RtcDataChannel.label] to a [DataChannelProtocol]
   */

  Map<String, DataChannelProtocol> get protocols;
  
  /**
   * Stream that can be listened to, to get notified when a new protocol is ready
   * to be used. This means that this stream will fire events after the
   * [RtcDataChannel.onOpen] event was fired and the underlying [RtcDataChanenl]
   * is ready to use
   */
  
  Stream<DataChannelProtocol> get onProtocol;
}

/**
 * A peer represents a machine/browser in the system. This is the internal
 * implementation of the [Peer] interface.
 */

class _Peer<C extends _P2PClient> implements Peer<C> {
  final int id;
  
  final _PeerRoom room;
  
  final RtcPeerConnection _pc;
  
  final C client;
  
  Stream<MediaStreamEvent> get onAddStream => _pc.onAddStream;
  
  Stream<MediaStreamEvent> get onRemoveStream => _pc.onRemoveStream;
  
  Stream<RtcDataChannel> get onChannel => _onChannelController.stream;
  StreamController<RtcDataChannel> _onChannelController = new StreamController.broadcast();
  
  final Map<String, RtcDataChannel> channels = {};
  
  // int _channelId = 1;
  
  /**
   * Internal constructor that is called from the [P2PClient]
   */
  
  _Peer(this.room, this.id, this.client, [Map mediaConstraints = const {'optional': const [const {'DtlsSrtpKeyAgreement': true}]}])
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
  
  void createChannel(String label, [Map options = null]) {
    // id is an unsigned unsigned short
    /*
    if(options == null) {
      options = {'id': _channelId++};
    }
    */
    _notifyChannelCreated(_pc.createDataChannel(label, options));
  }
  
  void addStream(MediaStream ms, [Map<String,String> mediaConstraints]) {
    _pc.addStream(ms);
  }
  
  void removeStream(MediaStream ms) {
    _pc.removeStream(ms);
  }
  
  String toString() => 'Peer#$id';
}

/**
 * The [_ProtocolPeer] extends [_Peer] that by adding a [DataChannelProtocol] on top to the [RtcDataChannel].
 * It uses the [RtcDataChannel.protocol] property and a [ProtocolProvider] to provide application
 * specific protocols.
 */

class _ProtocolPeer extends _Peer<_ProtocolP2PClient> implements ProtocolPeer<_ProtocolP2PClient> {
  Stream<DataChannelProtocol> get onProtocol => _onProtocolController.stream;
  StreamController<DataChannelProtocol> _onProtocolController = new StreamController.broadcast();
  
  final Map<String, DataChannelProtocol> protocols = {};
  
  /**
   * Library-internal constructor
   */
  
  _ProtocolPeer(room, id, client) : super(room, id, client);
  
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