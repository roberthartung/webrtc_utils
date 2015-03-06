part of webrtc_utils.connections;

class Peer {
  final int _id;
  
  final RtcPeerConnection _pc;
  
  final TargetedSignalingChannel _signalingChannel;
  
  int get id => _id;
  
  StreamController<RtcDataChannel> _onChannelCreatedController = new StreamController.broadcast();
  
  Stream<RtcDataChannel> get onChannelCreated => _onChannelCreatedController.stream;
  
  Peer(this._id, this._pc, this._signalingChannel);
  
  /* Future<RtcDataChannel> */
  void createChannel(String label) {
    //Completer completer = new Completer();
    _pc.onNegotiationNeeded.listen((Event ev) { 
      print('Connection.negotiationNeeded');
      // Send offer to the other peer
      _pc.createOffer({}).then((RtcSessionDescription desc) {
        _pc.setLocalDescription(desc).then((_) {
          _signalingChannel.send({'rtc_session_description': _pc.localDescription}, _id);
        });
      }).catchError((err) {
        print('error at offer: $err');
      });
    });
    RtcDataChannel channel = _pc.createDataChannel(label);
    /*
    channel.onOpen.listen((_) {
      print('Channel opened');
      completer.complete(channel);
    });
    */
    _initChannel(channel);
    //return completer.future;
  }
  
  void addStream(MediaStream ms, [Map<String,String> mediaConstraints]) {
    print('[Peer] Add Stream');
    _pc.addStream(ms, mediaConstraints);
    _initStream(ms);
  }
  
  void _initStream(MediaStream ms) {
    print('[Peer] Stream received');
    VideoElement video = new VideoElement();
    video.src = Url.createObjectUrlFromStream(ms);
    video.controls = true;
    video.autoplay = true;
    document.body.append(video);
  }
  
  void _initChannel(RtcDataChannel channel) {
    _onChannelCreatedController.add(channel);
    //_channel = channel;
    /*
    channel.onOpen.listen((Event ev) {
      print('Channel.open');
      // enableCommunication()
      // channel.send('testMessage');
    });
    */
    //_channelMessageController.addStream(channel.onMessage);
    /*
    channel.onMessage.listen((MessageEvent ev) {
      print('Channel.message: ${ev.data}');
    });
    */
    channel.onClose.listen((Event ev) {
      print('Channel.close');
    });
    channel.onError.listen((Event ev) {
      print('Channel.error');
    });
  }
}

class MultiplePeerConnection {
  TargetedSignalingChannel _signalingChannel;
  
  Map<int, Peer> peers = {};
  
  Map _rtcConfiguration;
  
  int get localPeerId => _signalingChannel.source;
  
  StreamController<Peer> _onPeerConnectedController = new StreamController.broadcast();
  
  Stream<Peer> get onPeerConnected => _onPeerConnectedController.stream;
  
  MultiplePeerConnection(this._rtcConfiguration, this._signalingChannel) {
    _signalingChannel.onTargetedMessage.listen(_onTargetedSignalingMessage);
  }
  
  void _onTargetedSignalingMessage(TargetedSignalingMessage message) {
    if(message.message != null) {
      SignalingMessage signalingMessage = message.message;
      print('SignalingMessage: $signalingMessage from ${message.source}');
      
      Peer peer = peers[message.source];
      RtcPeerConnection pc = peer._pc;
      
      if(signalingMessage is RtcSessionDescriptionMessage) {
        RtcSessionDescription desc = signalingMessage.description;
        if(desc.type == 'offer') {
          pc.onDataChannel.listen((RtcDataChannelEvent ev) {
            print('Channel received');
            peer._initChannel(ev.channel);
          });
          
          pc.onAddStream.listen((MediaStreamEvent ev) {
            peer._initStream(ev.stream);
          });
          
          print('offer received');
          pc.setRemoteDescription(desc).then((_) {
            pc.createAnswer().then((RtcSessionDescription answer) {
              pc.setLocalDescription(answer).then((_) {
                _signalingChannel.send({'rtc_session_description': pc.localDescription}, message.source);
              });
            });
          });
        } else {
          print('answer received');
          pc.setRemoteDescription(desc);
        }
        return;
      } else if(signalingMessage is RtcIceCandidateMessage) {
        pc.addIceCandidate(signalingMessage.candidate, () {
          
        }, (error) {
          print('Unable to add IceCandidateMessage: $error');
        });
        return;
      }
    } else if(message.data != null) {
      int peerId = message.source;
      if(_signalingChannel.source == null) {
        _signalingChannel.source = peerId;
        print('Received local peer id: ${_signalingChannel.source}');
        return;
      } else {
        print('New Peer ID received: $peerId');
        
        RtcPeerConnection pc = new RtcPeerConnection(_rtcConfiguration);
        pc.onIceCandidate.listen((RtcIceCandidateEvent ev) {
          if(ev.candidate != null) {
            _signalingChannel.send({'rtc_ice_candidate': ev.candidate}, peerId);
          } else {
            print('No more candidates');
          }
        });
        Peer peer = new Peer(peerId, pc, _signalingChannel);
        peers[peerId] = peer;
        _onPeerConnectedController.add(peer);
        return;
      }

      // print('Raw message received: ${message.source}');
      return;
    }
    
    print('Unknown SignalingMessage: $message (${message.source}, ${message.data})');
  }
}