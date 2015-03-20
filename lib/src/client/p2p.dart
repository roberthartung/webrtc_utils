part of webrtc_utils.client;

/**
 * Basic P2P Client class
 */

abstract class P2PClient {
  /**
   * The signaling channel to use for establishing a connection
   */
  
  final SignalingChannel _signalingChannel;
  
  /**
   * The rtcConfiguration Map that specifies iceServers
   */
    
  final Map _rtcConfiguration;
  
  /**
   * Protocol providers
   */
  
  ProtocolProvider _protocolProvider = new DefaultProtocolProvider();
  // ProtocolProvider get protocolProvider => _protocolProvider;
  
  /**
   * Local ID assigned by the signaling server 
   */
  
  int _id;
  int get id => _id;
  
  /**
   * List of rooms the client is participating in
   */
  
  Map<String, Room> rooms = {};
  
  /**
   * List of all other peers
   */
  
  Map<int, Peer> peers = {};
  
  /**
   * Event stream for when the connection to the signaling server is established
   */
  
  Stream<int> get onConnect => _onConnectController.stream;
  StreamController<int> _onConnectController = new StreamController();
  
  /**
   * Event stream when you join a room
   */
  
  Stream<Room> get onJoinRoom => _onJoinRoomController.stream;
  StreamController<Room> _onJoinRoomController = new StreamController();
  
  /**
   * Constructor
   */
  
  P2PClient(this._signalingChannel, this._rtcConfiguration) {
    _signalingChannel.onMessage.listen(_onSignalingMessage);
  }
  
  /**
   * Adds a protocol provider
   */
  
  void setProtocolProvider(ProtocolProvider provider) {
    _protocolProvider = provider;
  }
  
  /**
   * Joins a [room] with an optional [password]
   */
  
  void join(String room, [String password = null]) {
    _signalingChannel.send(new JoinRoomMessage(room, password, _id));
  }
  
  /**
   * Internal handler for when nwe receive a [SignalingMessage]
   */
  
  void _onSignalingMessage(SignalingMessage sm) {
    // Get Peer and PeerConnection from SignalMessage's peerId
    if(sm is WelcomeMessage) {
      _id = sm.peerId;
      _onConnectController.add(_id);
      return;
    } else if(sm is RoomMessage) {
      // Joined a room
      Room room = new Room._(sm.name);
      rooms[room.name] = room;
      // TODO(rh): We should create an event for the initial peer list.
      sm.peers.forEach((int peerId) {
        Peer peer = new Peer._(room, peerId, _signalingChannel, _rtcConfiguration, _protocolProvider);
        room._peers.add(peer);
        peers[peer.id] = peer;
      });
      _onJoinRoomController.add(room);
      return;
    } else if(sm is JoinMessage) {
      // A peer joined a room
      Room room = rooms[sm.room];
      Peer peer = new Peer._(room, sm.peerId, _signalingChannel, _rtcConfiguration, _protocolProvider);
      peers[peer.id] = peer;
      room._addPeer(peer);
      return;
    } else if(sm is LeaveMessage) {
      // A peer left a room
      Room room = rooms[sm.room];
      Peer peer = peers[sm.peerId];
      room._removePeer(peer);
      peers.remove(sm.peerId);
      return;
    }
    
    final Peer peer = peers[sm.peerId];
    final RtcPeerConnection pc = peer._pc;
    
    // print('[P2P._onSignalingMessage:$peer] SignalingMessage $sm received.');
    if(sm is SessionDescriptionMessage) {
      RtcSessionDescription desc = sm.description;
      if(desc.type == 'offer') {
        //print('offer received');
        pc.setRemoteDescription(desc).then((_) {
          pc.createAnswer().then((RtcSessionDescription answer) {
            pc.setLocalDescription(answer).then((_) {
              // {'rtc_session_description': pc.localDescription}, message.source
              _signalingChannel.send(new SessionDescriptionMessage(answer, peer.id));
            });
          });
        });
      } else {
        //print('answer received');
        pc.setRemoteDescription(desc);
      }
    } else if(sm is IceCandidateMessage) {
      pc.addIceCandidate(sm.candidate, () {
        //print('Candidate ${sm.candidate.candidate} added');
      }, (error) {
        print('[ERROR] Unable to add IceCandidateMessage: $error');
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