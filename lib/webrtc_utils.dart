library webrtc_utils;

export 'signaling.dart';
export 'connections.dart';

// OLD CODE

/*
class WebRtcWebSocketJsonSignalingHandler implements WebRtcSignalingHandler {
  WebSocket _ws;
  WelcomeMessage welcomeMessage;
  
  final StreamController<IceCandidateMessage> _iceCandidateStreamController = new StreamController();
  Stream<IceCandidateMessage> get onIceCandidate => _iceCandidateStreamController.stream;
  
  final StreamController<SessionDescriptionMessage> _sessionDescriptionStreamController = new StreamController();
  Stream<SessionDescriptionMessage> get onSessionDescription => _sessionDescriptionStreamController.stream;
  
  int get clientId => welcomeMessage.clientId;
  
  void connect(String signalingServerUrl) {
    _ws = new WebSocket(signalingServerUrl, ['webrtc:signaling']);
    
    _ws.onClose.listen((CloseEvent ev) {
      /*
      print('signalingWebSocket closed');
      connection.close();
      connection = null;
      */
    });
    
    _ws.onMessage.first.then((MessageEvent ev) {
      
      Map message = JSON.decode(ev.data);
      welcomeMessage = new WelcomeMessage._fromObject(message);
      // Hello message received
      
      print('hello message: $message');
      _ws.onMessage.listen((MessageEvent ev) {
        Map data = JSON.decode(ev.data);
        switch(data['type']) {
          case 'client' :
            // TODO(rh): Parse client message
            
            print('new client #${data['id']}');
            // Some other client connected, create peer-2-peer connection
            // Only lower id initializes the connection
            /*
            if(myClientId < data['id']) {
              connectToClient(data['id'], true);
            } else {
              connectToClient(data['id'], false);
            }
            */
            break;
          case "candidate" :
            _iceCandidateStreamController.add(new IceCandidateMessage._fromObject(data));
            /*
            print('Candidate for client #${data['client']['id']}: "${data['candidate']}"');
            connections[data['client']['id']].addIceCandidate(new RtcIceCandidate(data['candidate']), () {
              print('candidate added');
            }, (err) {
              print('candidate add error: $err');
            });
            */
            break;
          case "sdp" :
            
            /*
            print('SDP Received: $data');
            RtcSessionDescription desc = new RtcSessionDescription(data['sdp']);
            if(!initializer) {
              if(desc.type == 'offer') {
                // Receiver
                connection.setRemoteDescription(desc).then((_) {
                  connection.createAnswer().then((RtcSessionDescription desc) {
                    print('Answer created');
                    connection.setLocalDescription(desc).then((_) {
                      signalingWebSocket.send(JSON.encode({ "type" : "sdp", "sdp": {'sdp': desc.sdp, 'type': desc.type}}));
                    });
                  });
                });
              } else {
                print('[ERROR] SDP Received which is not an offer. This should only happen if we are the initializer');
              }
            }  else {
              // Initializer
              connection.setRemoteDescription(desc);
            }
            */
            break;
        }
      });
    });
  }
}
*/