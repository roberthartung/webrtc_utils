part of webrtc_utils.client;

/**
 * Basic P2P Client class
 */

abstract class P2PClient {
  int _id;
  
  int get id => _id;
  
  Map<String, Room> rooms = {};
  
  Map<int, Peer> peers = {};
  
  StreamController<int> _onConnectedController = new StreamController();
  
  Stream<int> get onConnected => _onConnectedController.stream;
  
  StreamController<Room> _onRoomJoinedController = new StreamController();
    
  Stream<Room> get onRoomJoined => _onRoomJoinedController.stream;
  
  final SignalingChannel _signalingChannel; 
  
  final Map _rtcConfiguration;
  
  P2PClient(this._signalingChannel, this._rtcConfiguration) {
    _signalingChannel.onMessage.listen(_onSignalingMessage);
  }
  
  void join(String room) {
    _signalingChannel.send(new JoinRoomMessage(room, _id));
  }
  
  /*
  if(message.message != null) {
      SignalingMessage signalingMessage = message.message;
      print('SignalingMessage: $signalingMessage from ${message.source}');
      
      if(signalingMessage is RtcSessionDescriptionMessage) {
        
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
  */
  
  void _onSignalingMessage(SignalingMessage sm) {
    // Get Peer and PeerConnection from SignalMessage's peerId
    if(sm is WelcomeMessage) {
      _id = sm.peerId;
      _onConnectedController.add(_id);
      return;
    } else if(sm is RoomMessage) {
      // Joined a room
      Room room = new Room._(sm.name);
      rooms[room.name] = room;
      // TODO(rh): We should create an event for the initial peer list.
      sm.peers.forEach((int peerId) {
        Peer peer = new Peer._(room, peerId, _signalingChannel, _rtcConfiguration);
        print('Peer $peer created');
        room._peers.add(peer);
        peers[peer.id] = peer;
      });
      _onRoomJoinedController.add(room);
      return;
    } else if(sm is PeerMessage) {
      // A peer joined a room
      Room room = rooms[sm.room];
      Peer peer = new Peer._(room, sm.peerId, _signalingChannel, _rtcConfiguration);
      print('Peer $peer created');
      peers[peer.id] = peer;
      room._addPeer(peer);
      return;
    }
    
    final Peer peer = peers[sm.peerId];
    final RtcPeerConnection pc = peer._pc;
    
    print('[P2P._onSignalingMessage:$peer] SignalingMessage $sm received.');
    if(sm is SessionDescriptionMessage) {
      RtcSessionDescription desc = sm.description;
      if(desc.type == 'offer') {
        print('offer received');
        pc.setRemoteDescription(desc).then((_) {
          pc.createAnswer().then((RtcSessionDescription answer) {
            pc.setLocalDescription(answer).then((_) {
              // {'rtc_session_description': pc.localDescription}, message.source
              _signalingChannel.send(new SessionDescriptionMessage(answer, peer.id));
            });
          });
        });
      } else {
        print('answer received');
        pc.setRemoteDescription(desc);
      }
    } else if(sm is IceCandidateMessage) {
      pc.addIceCandidate(sm.candidate, () {
        print('Candidate ${sm.candidate.candidate} added');
      }, (error) {
        print('Unable to add IceCandidateMessage: $error');
      });
    } else {
      throw "Unknown SignalingMessage received: $sm.";
    }
  }
}

/**
 * A WebSocket implementation for a Peer-2-Peer Client
 */

class WebSocketP2PClient extends P2PClient {
  WebSocketP2PClient(String webSocketUrl, Map _rtcConfiguration) : super(new WebSocketSignalingChannel(webSocketUrl), _rtcConfiguration);
}