part of webrtc_utils.connections;

class DualPeerConnection {
  SignalingChannel _signalingChannel;
  
  RtcPeerConnection _pc;
  
  RtcDataChannel channel;
  
  StreamController _channelMessageController = new StreamController<MessageEvent>();
  
  Stream<MessageEvent> get onMessage => _channelMessageController.stream;
  
  DualPeerConnection(Map rtcConfiguration, this._signalingChannel) {
    _pc = new RtcPeerConnection(rtcConfiguration);
    
    _pc.onIceCandidate.listen(_onIceCandidate);
    
    _signalingChannel.onMessage.listen((SignalingMessage message) {
      if(message is RtcSessionDescriptionMessage) {
        RtcSessionDescription desc = message.description;
        if(desc.type == 'offer') {
          _pc.onDataChannel.listen((RtcDataChannelEvent ev) {
            initChannel(ev.channel);
          });
          
          print('offer received');
          _pc.setRemoteDescription(desc).then((_) {
            _pc.createAnswer().then((RtcSessionDescription answer) {
              _pc.setLocalDescription(answer).then((_) {
                _signalingChannel.send(answer);
              });
            });
          });
        } else {
          print('answer received');
          _pc.setRemoteDescription(desc);
        }
      } else if(message is RtcIceCandidateMessage) {
        _pc.addIceCandidate(message.candidate, () {
          
        }, (error) {
          print('Unable to add IceCandidateMessage: $error');
        });
      } else {
        print('Unknown SignalingMessage: $message');
      }
    });
  }
  
  void initChannel(RtcDataChannel channel) {
    this.channel = channel;
    
    channel.onOpen.listen((Event ev) {
      print('Channel.open');
      // enableCommunication()
      channel.send('testMessage');
    });
    
    _channelMessageController.addStream(channel.onMessage);
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
  
  void createDataChannel(String label) {
    _pc.onNegotiationNeeded.listen(_onNegotiationNeeded);
    initChannel(_pc.createDataChannel(label));
  }
  
  void _onNegotiationNeeded(Event ev) {
    print('Connection.negotiationNeeded');
    // Send offer to the other peer
    _pc.createOffer({}).then((RtcSessionDescription desc) {
      _pc.setLocalDescription(desc).then((_) {
        _signalingChannel.send(_pc.localDescription);
      });
    }).catchError((err) {
      print('error at offer: $err');
    });
  }
  
  void _onIceCandidate(RtcIceCandidateEvent ev) {
    if(ev.candidate != null) {
      RtcIceCandidate candidate = ev.candidate;
      print('${candidate.candidate} - ${candidate.sdpMid} - ${candidate.sdpMLineIndex}');
      _signalingChannel.send(candidate);
    } else {
      print('No more candidates');
    }
  }
}