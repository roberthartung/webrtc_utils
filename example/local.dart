import 'dart:html';
import 'package:webrtc_utils/client.dart';
import 'dart:async';

class PeerConnection {
  Stream<RtcSessionDescription> get descriptions => _descriptionsController.stream;
  StreamController<RtcSessionDescription> _descriptionsController = new StreamController.broadcast();
  
  Stream<RtcIceCandidate> get candidates => _candidatesController.stream;
  StreamController<RtcIceCandidate> _candidatesController = new StreamController.broadcast();
  
  RtcPeerConnection pc;
  
  PeerConnection([Map mediaConstraints = const {'optional': const [const {'DtlsSrtpKeyAgreement': true}]}]) {
    pc = new RtcPeerConnection(rtcConfiguration, mediaConstraints);
    
    pc.onNegotiationNeeded.listen((Event ev) {
      print('Negotiation needed');
      createOffer();
    });
    
    pc.onIceCandidate.listen((RtcIceCandidateEvent ev) {
      print(ev.candidate);
      if(ev.candidate != null) {
        _candidatesController.add(ev.candidate);
      }
    });
  }
  
  void createOffer() {
    pc.createOffer({}).then((RtcSessionDescription offer) {
      pc.setLocalDescription(offer).then((_) {
        _descriptionsController.add(offer);
      });
    }).catchError((err) {
      print('error at offer: $err');
    });
  }
  
  void setOffer(RtcSessionDescription offer) {
    pc.setRemoteDescription(offer).then((_) {
      pc.createAnswer().then((RtcSessionDescription answer) {
        pc.setLocalDescription(answer).then((_) {
          _descriptionsController.add(answer);
        });
      });
    });
  }
  
  Future<RtcDataChannel> createChannel(String label) {
    return new Future.value(pc.createDataChannel(label));
  }
  
  void addIceCandidate(RtcIceCandidate candidate) {
    pc.addIceCandidate(candidate, () {
      
    }, (_) {
      print('Error');
    });
  }
}

void main() {
  PeerConnection peerA = new PeerConnection();
  PeerConnection peerB = new PeerConnection();
  
  // Connect peer connections
  peerA.descriptions.listen((RtcSessionDescription offer) {
    print('PeerA: $offer');
    peerB.setOffer(offer);
  });
  
  peerB.descriptions.listen((RtcSessionDescription answer) {
    print('PeerB: $answer');
    peerA.pc.setRemoteDescription(answer);
  });
  
  peerA.candidates.listen(peerB.addIceCandidate);
  peerB.candidates.listen(peerA.addIceCandidate);
  
  peerB.pc.onDataChannel.listen((RtcDataChannelEvent ev) {
    print('ChannelB: ${ev.channel} ${ev.channel.id}');
    
    ev.channel.onOpen.listen((Event ev) {
      print('Channel@B open');
    });
    
    ev.channel.onMessage.listen((MessageEvent ev) {
      print('Channel@B: ${ev.data}');
    });
  });
  
  int _id = 0;
  
  new Timer.periodic(new Duration(seconds: 5), (Timer _) {
    peerA.createChannel('test').then((RtcDataChannel channel) {
      //peerA.createOffer(); // SHOULD NOT BE NEEDED - FIREFOX DOES NOT FIRE NEGOTIATIONNEEDED!
      final int id = _id++;
      print('Channel@A: ${channel.id} ${channel.negotiated}');
      channel.onOpen.listen((Event ev) {
        print('Channel@A open');
        new Timer.periodic(new Duration(seconds: 1), (Timer t) {
          channel.send(id);
        });
      });
    });
  });
}