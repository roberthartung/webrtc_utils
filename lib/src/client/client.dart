part of webrtc_utils.client;

/// Interface for the most simple peer-to-peer client
abstract class P2PClient<R extends PeerRoom> {
  /// Local ID assigned by the signaling server
  int get id;

  /// A map representing the rtcConfiguration that is used by the [Peer]s.
  Map get rtcConfiguration;

  /// Stream of ints that indicate that we are connected to the signaling server
  /// the int represents the local id
  Stream<int> get onConnect;

  /// Stream of events that indicate that we were disconnected from the signaling
  /// server
  Stream<int> get onDisconnect;

  /// Stream of ints that represent errors while connecting to the server
  Stream<int> get onError;

  /// Stream of rooms that we have joined
  Stream<R> get onJoinRoom;

  /// Stream of rooms that we have left
  Stream<R> get onLeaveRoom;

  /// Method to request to join a room
  void join(String roomName, [String password = null]);
}

/// Interface for a protocol based peer2peer client
abstract class ProtocolP2PClient<R extends ProtocolPeerRoom>
    extends P2PClient<R> {
  /// Sets the instance of an [ProtocolProvider] that is used to create
  /// protocol instances for each peer/channel.
  void setProtocolProvider(ProtocolProvider provider);
}

/// Basic P2P Client class
abstract class _P2PClient<R extends _PeerRoom, P extends _Peer> {
  /// The signaling channel to use for establishing a connection
  final SignalingChannel _signalingChannel;

  /// The rtcConfiguration Map that specifies iceServers
  final Map rtcConfiguration;

  /// An int representing the local id assigned by the [SignalingServer]
  int get id => _id;
  int _id;

  /// List of rooms the client is participating in
  final Map<String, _PeerRoom> rooms = {};

  /// Event stream for when the connection to the signaling server is established
  Stream<int> get onConnect => _onConnectController.stream;
  final StreamController<int> _onConnectController =
      new StreamController.broadcast();

  Stream<int> get onError => _onErrorStreamController.stream;
  final StreamController<int> _onErrorStreamController =
      new StreamController.broadcast();

  /// Event stream for when the connection to the signaling server is established
  Stream get onDisconnect => _onDisconnectController.stream;
  final StreamController _onDisconnectController =
      new StreamController.broadcast();

  /// Event stream when you join a room
  Stream<R> get onJoinRoom => _onJoinRoomController.stream;
  final StreamController<R> _onJoinRoomController =
      new StreamController.broadcast();

  /// Event stream when you leave a room
  Stream<R> get onLeaveRoom => _onLeaveRoomController.stream;
  final StreamController<R> _onLeaveRoomController =
      new StreamController.broadcast();

  /// Constructor
  _P2PClient(this._signalingChannel, this.rtcConfiguration) {
    _signalingChannel.onMessage.listen(_onSignalingMessage);
    _onDisconnectController.addStream(_signalingChannel.onClose);
    _onErrorStreamController.addStream(_signalingChannel.onError);
  }

  /// Joins a [room] with an optional [password]
  void join(String roomName, [String password = null]) {
    _signalingChannel.send(new JoinRoomMessage(roomName, password, _id));
  }

  /// Internal handler for when new receive a [SignalingMessage]
  void _onSignalingMessage(SignalingMessage sm) {
    // Welcome message
    if (sm is WelcomeMessage) {
      _id = sm.peerId;
      _onConnectController.add(_id);
      return;
    } else if (sm is RoomJoinedMessage) {
      // Local peer joined a room -> create room locally
      _PeerRoom room = createRoom(sm.roomName);
      sm.peers.forEach((int peerId) {
        P peer = createPeer(room, peerId);
        room._peers[peer.id] = peer;
      });
      rooms[room.name] = room;
      _onJoinRoomController.add(room);
      return;
    } else if (sm is JoinMessage) {
      // A peer joined a room
      _PeerRoom room = rooms[sm.roomName];
      P peer = createPeer(room, sm.peerId);
      // Use add method to create onPeerJoin event
      room.addPeer(peer);
      return;
    } else if (sm is LeaveMessage) {
      // A peer left a room
      _PeerRoom room = rooms[sm.roomName];
      room.removePeer(sm.peerId);
      return;
    } else if (sm is RoomMessage) {
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

  /// Method to create a new room
  R createRoom(String name) {
    return new _PeerRoom<_Peer, _P2PClient>(this, name);
  }
}

/// A P2PClient that uses a [DataChannelProtocol] on top of a [_Peer]s [RtcDataChannel]
class _ProtocolP2PClient extends _P2PClient<_ProtocolPeerRoom, _ProtocolPeer> {
  /// Instance of a protocol provider that is used to instantiate protocols for
  /// the data channel
  ProtocolProvider _protocolProvider = new DefaultProtocolProvider();

  /// Library-Internal constructor. For arguments see [P2PClient]
  _ProtocolP2PClient(signalingChannel, rtcConfiguration)
      : super(signalingChannel, rtcConfiguration);

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
class WebSocketP2PClient extends _P2PClient<_PeerRoom, _Peer>
    implements P2PClient<PeerRoom> {
  WebSocketP2PClient(String webSocketUrl, Map _rtcConfiguration)
      : super(new WebSocketSignalingChannel(webSocketUrl), _rtcConfiguration);
}

/// A WebSocket implementation for a protocol based P2P client
class WebSocketProtocolP2PClient extends _ProtocolP2PClient
    implements ProtocolP2PClient<ProtocolPeerRoom> {
  WebSocketProtocolP2PClient(String webSocketUrl, Map _rtcConfiguration)
      : super(new WebSocketSignalingChannel(webSocketUrl), _rtcConfiguration);
}
