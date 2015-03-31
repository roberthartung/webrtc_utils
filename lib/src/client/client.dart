part of webrtc_utils.client;

/// Interface for the most simple peer-to-peer client
abstract class P2PClient<R extends PeerRoom> {
  /// Local ID assigned by the signaling server 
  int get id;
  
  Stream<int> get onConnect;
  
  Stream get onDisconnect;
  
  Stream<R> get onJoinRoom;
  
  Stream<R> get onLeaveRoom;
  
  void join(String roomName, [String password = null]);
}

/// Interface for 
abstract class ProtocolP2PClient<R extends ProtocolPeerRoom>
    extends P2PClient<R> {
  void setProtocolProvider(ProtocolProvider provider);
}

/// Basic P2P Client class
abstract class _P2PClient<R extends _PeerRoom, P extends _Peer> implements P2PClient<R> {
  /// The signaling channel to use for establishing a connection
  
  final SignalingChannel _signalingChannel;
  
  /// The rtcConfiguration Map that specifies iceServers

  final Map _rtcConfiguration;
  
  int _id;
  int get id => _id;
  
  /// List of rooms the client is participating in
  
  final Map<String, _PeerRoom> rooms = {};
  
  /// Event stream for when the connection to the signaling server is established
  
  Stream<int> get onConnect => _onConnectController.stream;
  final StreamController<int> _onConnectController = new StreamController.broadcast();
  
  /// Event stream for when the connection to the signaling server is established
  
  Stream get onDisconnect => _onDisconnectController.stream;
  final StreamController _onDisconnectController = new StreamController.broadcast();
  
  /// Event stream when you join a room
  
  Stream<_PeerRoom> get onJoinRoom => _onJoinRoomController.stream;
  final StreamController<_PeerRoom> _onJoinRoomController = new StreamController.broadcast();
  
  /// Event stream when you leave a room
  
  Stream<_PeerRoom> get onLeaveRoom => _onLeaveRoomController.stream;
  final StreamController<_PeerRoom> _onLeaveRoomController = new StreamController.broadcast();
  
  /// Constructor
  
  _P2PClient(this._signalingChannel, this._rtcConfiguration) {
    _signalingChannel.onMessage.listen(_onSignalingMessage);
    _signalingChannel.onClose.listen((int reason) => _onDisconnectController.add(reason));
  }
  
  /// Joins a [room] with an optional [password]
  
  void join(String roomName, [String password = null]) {
    _signalingChannel.send(new JoinRoomMessage(roomName, password, _id));
  }
  
  /// Internal handler for when new receive a [SignalingMessage]
  
  void _onSignalingMessage(SignalingMessage sm) {
    // Welcome message
    if(sm is WelcomeMessage) {
      _id = sm.peerId;
      _onConnectController.add(_id);
      return;
    } else if(sm is RoomJoinedMessage) {
      // Local peer joined a room -> create room locally
      _PeerRoom room = createRoom(sm.roomName);
      sm.peers.forEach((int peerId) {
        P peer = createPeer(room, peerId);
        room._peers[peer.id] = peer; 
      });
      rooms[room.name] = room;
      _onJoinRoomController.add(room);
      return;
    } else if(sm is JoinMessage) {
      // A peer joined a room
      _PeerRoom room = rooms[sm.roomName];
      P peer = createPeer(room, sm.peerId);
      // Use add method to create onPeerJoin event
      room.addPeer(peer);
      return;
    } else if(sm is LeaveMessage) {
      // A peer left a room
      _PeerRoom room = rooms[sm.roomName];
      room.removePeer(sm.peerId);
      return;
    } else if(sm is RoomMessage) {
      // Delegate message handling to room
      print('Room message received: $sm');
      _PeerRoom room = rooms[sm.roomName];
      room.onSignalingMessage(sm);
    } else {
      throw "Unknown SignalingMessage received: $sm.";
    }
  }
  
  /// Create peer, function declared here instead of in [R] so we can override it easily!
  
  P createPeer(_PeerRoom room, int peerId) {
    return new _Peer(room, peerId, this);
  }
  
  _PeerRoom createRoom(String name) {
    return new _PeerRoom<_Peer, _P2PClient>(this, name);
  }
}

/// A P2PClient that uses a [DataChannelProtocol] on top of a [_Peer]s [RtcDataChannel]
class _ProtocolP2PClient extends _P2PClient<_ProtocolPeerRoom, _ProtocolPeer> implements ProtocolP2PClient<_ProtocolPeerRoom> {
  /// Instance of a protocol provider that is used to instantiate protocols for
  /// the data channel
  ProtocolProvider _protocolProvider = new DefaultProtocolProvider();
  
  /// Library-Internal constructor. For arguments see [P2PClient]
  _ProtocolP2PClient(signalingChannel, rtcConfiguration) : super(signalingChannel, rtcConfiguration);
  
  /// Adds a protocol provider
  void setProtocolProvider(ProtocolProvider provider) {
    _protocolProvider = provider;
  }
  
  @override
  _ProtocolPeer createPeer(_ProtocolPeerRoom room, int peerId) {
    return new _ProtocolPeer(room, peerId, this);
  }
  
  @override
  _ProtocolPeerRoom createRoom(String name) {
    return new _ProtocolPeerRoom(this, name);
  }
}

/// A WebSocket implementation for a P2P client
class WebSocketP2PClient extends _P2PClient<_PeerRoom, _Peer> {
  WebSocketP2PClient(String webSocketUrl, Map _rtcConfiguration) : super(new WebSocketSignalingChannel(webSocketUrl), _rtcConfiguration);
}

/// A WebSocket implementation for a protocol based P2P client
class WebSocketProtocolP2PClient extends _ProtocolP2PClient {
  WebSocketProtocolP2PClient(String webSocketUrl, Map _rtcConfiguration) : super(new WebSocketSignalingChannel(webSocketUrl), _rtcConfiguration);
}