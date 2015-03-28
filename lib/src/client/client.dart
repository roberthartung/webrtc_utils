part of webrtc_utils.client;

/**
 * Basic P2P Client class
 */

abstract class P2PClient<R extends PeerRoom, P extends Peer> {
  /**
   * The signaling channel to use for establishing a connection
   */
  
  final SignalingChannel _signalingChannel;
  
  /**
   * The rtcConfiguration Map that specifies iceServers
   */
    
  final Map _rtcConfiguration;
  
  /**
   * Local ID assigned by the signaling server 
   */
  
  int _id;
  int get id => _id;
  
  /**
   * List of rooms the client is participating in
   */
  
  final Map<String, R> rooms = {};
  
  /**
   * Event stream for when the connection to the signaling server is established
   */
  
  Stream<int> get onConnect => _onConnectController.stream;
  final StreamController<int> _onConnectController = new StreamController.broadcast();
  
  /**
   * Event stream for when the connection to the signaling server is established
   */
  
  Stream get onDisconnect => _onDisconnectController.stream;
  final StreamController _onDisconnectController = new StreamController.broadcast();
  
  /**
   * Event stream when you join a room
   */
  
  Stream<R> get onJoinRoom => _onJoinRoomController.stream;
  final StreamController<R> _onJoinRoomController = new StreamController.broadcast();
  
  /**
   * Event stream when you leave a room
   */
  
  Stream<R> get onLeaveRoom => _onLeaveRoomController.stream;
  final StreamController<R> _onLeaveRoomController = new StreamController.broadcast();
  
  /**
   * Constructor
   */
  
  P2PClient(this._signalingChannel, this._rtcConfiguration) {
    _signalingChannel.onMessage.listen(_onSignalingMessage);
    _signalingChannel.onClose.listen((int reason) => _onDisconnectController.add(reason));
  }
  
  /**
   * Joins a [room] with an optional [password]
   */
  
  void join(String roomName, [String password = null]) {
    _signalingChannel.send(new JoinRoomMessage(roomName, password, _id));
  }
  
  /**
   * Internal handler for when new receive a [SignalingMessage]
   */
  
  void _onSignalingMessage(SignalingMessage sm) {
    // Welcome message
    if(sm is WelcomeMessage) {
      _id = sm.peerId;
      _onConnectController.add(_id);
      return;
    } else if(sm is RoomJoinedMessage) {
      // Local peer joined a room -> create room locally
      R room = _createRoom(sm.roomName);
      sm.peers.forEach((int peerId) {
        P peer = _createPeer(room, peerId);
        room._peers[peer.id] = peer; 
      });
      rooms[room.name] = room;
      _onJoinRoomController.add(room);
      return;
    } else if(sm is JoinMessage) {
      // A peer joined a room
      R room = rooms[sm.roomName];
      P peer = _createPeer(room, sm.peerId);
      // Use add method to create onPeerJoin event
      room._addPeer(peer);
      return;
    } else if(sm is LeaveMessage) {
      // A peer left a room
      R room = rooms[sm.roomName];
      room._removePeer(sm.peerId);
      return;
    } else if(sm is RoomMessage) {
      // Delegate message handling to room
      print('Room message received: $sm');
      R room = rooms[sm.roomName];
      room._onSignalingMessage(sm);
    } else {
      throw "Unknown SignalingMessage received: $sm.";
    }
  }
  
  /**
   * Create peer, function declared here instead of in [R] so we can override it easily!
   */
  
  P _createPeer(R room, int peerId) {
    P peer = new Peer._(room, peerId, this);
    return peer;
  }
  
  R _createRoom(String name) {
    return new PeerRoom<P, P2PClient>._(this, name);
  }
}

/**
 * A P2PClient that uses a [DataChannelProtocol] on top of a [Peer]s [RtcDataChannel]
 */

class ProtocolP2PClient<R extends ProtocolPeerRoom> extends P2PClient<R, ProtocolPeer> {
  /**
   * Protocol provider
   */
  
  ProtocolProvider _protocolProvider = new DefaultProtocolProvider();
  
  /**
   * Library-Internal constructor. For arguments see [P2PClient]
   */
  
  ProtocolP2PClient(signalingChannel, rtcConfiguration) : super(signalingChannel, rtcConfiguration);
  
  /**
   * Adds a protocol provider
   */
  
  void setProtocolProvider(ProtocolProvider provider) {
    _protocolProvider = provider;
  }
  
  ProtocolPeer _createPeer(R room, int peerId) {
    return new ProtocolPeer._(room, peerId, this);
  }
  
  ProtocolPeerRoom _createRoom(String name) {
    return new ProtocolPeerRoom._(this, name);
  }
}

/**
 * A WebSocket implementation for a P2P client
 */

class WebSocketP2PClient<R extends PeerRoom, P extends Peer> extends P2PClient<R, P> {
  WebSocketP2PClient(String webSocketUrl, Map _rtcConfiguration) : super(new WebSocketSignalingChannel(webSocketUrl), _rtcConfiguration);
}

/**
 * A WebSocket implementation for a protocol based P2P client
 */

class WebSocketProtocolP2PClient<R extends ProtocolPeerRoom> extends ProtocolP2PClient<R> {
  WebSocketProtocolP2PClient(String webSocketUrl, Map _rtcConfiguration) : super(new WebSocketSignalingChannel(webSocketUrl), _rtcConfiguration);
}