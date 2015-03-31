part of webrtc_utils.client;

/// Interface for the signaling channel. The signaling channel is used to exchange
/// data between two peers.
abstract class SignalingChannel {
  Stream<SignalingMessage> get onMessage;
  Stream<int> get onClose;
  Stream get onOpen;
  void send(SignalingMessage message);
}

/// An internal class that is used to convert objects to JSON format
abstract class _JsonConverter implements _Converter {
  String encode(Object o) {
    return JSON.encode(o);
  }
  
  Object decode(String s) {
    return JSON.decode(s);
  }
}

/// An interface to encode and decode data
abstract class _Converter {
  /// Encode message
  dynamic encode(dynamic o);
  
  /// Decode message
  dynamic decode(dynamic o);
}

/// Internal class used to decode/encode [SignalingMessage]s
class _MessageConverter extends _JsonConverter {
  String encode(SignalingMessage message) {
    return super.encode(message.toObject());
  }
  
  SignalingMessage decode(String s) {
    Map m = super.decode(s);
    if(m['type'] == SessionDescriptionMessage.TYPE) {
      return new SessionDescriptionMessage.fromObject(m);
    } else if(m['type'] == IceCandidateMessage.TYPE) {
      return new IceCandidateMessage.fromObject(m);
    } else if(m['type'] == WelcomeMessage.TYPE) {
      return new WelcomeMessage.fromObject(m);
    } else if(m['type'] == RoomJoinedMessage.TYPE) {
      return new RoomJoinedMessage.fromObject(m);
    } else if(m['type'] == RoomLeftMessage.TYPE) {
      return new RoomLeftMessage.fromObject(m);
    } else if(m['type'] == JoinMessage.TYPE) {
      return new JoinMessage.fromObject(m);
    } else if(m['type'] == LeaveMessage.TYPE) {
      return new LeaveMessage.fromObject(m);
    }
    
    throw "Unable to decode string '$s'.";
  }
}

/// A WebSocket implementation for the client side [SignalingChannel]
class WebSocketSignalingChannel implements SignalingChannel {
  /// WebSocket instance
  final WebSocket _ws;
  
  /// Encoder to be used to convert a SignalingMessage for the WebSocket
  final _MessageConverter _converter = new _MessageConverter();
  
  /// StreamController for streams of messages from the websocket
  final StreamController<SignalingMessage> _messageController = new StreamController.broadcast(); 
  Stream<SignalingMessage> get onMessage => _messageController.stream;
  
  /// Stream of close events of this signaling channel
  Stream<int> get onClose => _onCloseController.stream;
  final StreamController<int> _onCloseController = new StreamController.broadcast();
  
  /// Stream of open events of this signaling channel
  Stream get onOpen => _onOpenController.stream;
  final StreamController _onOpenController = new StreamController.broadcast(); 
  
  /// Constructor: Tales a websocket Url and creates a connection using the "webrtc_signaling" protocol
  WebSocketSignalingChannel(String webSocketUrl) :
    _ws = new WebSocket(webSocketUrl, 'webrtc_signaling') {
    // Setup message listener
    _ws.onMessage.listen(_onMessage);
    _ws.onOpen.listen(_onOpen);
    _ws.onClose.listen(_onClose);
    _ws.onError.listen(_onError);
  }
  
  void _onOpen(Event ev) {
    _onOpenController.add(null);
  }
  
  void _onClose(CloseEvent ev) {
    //print('[$this] Closed: ${ev.reason}');
    _onCloseController.add(ev.code);
  }
  
  void _onError(Event ev) {
    //print('[$this] Error');
  }
  
  /// Sends a SignalingMessage through the WebSocket as a JSON string
  void send(SignalingMessage message) {
    if(_ws == null || _ws.readyState != WebSocket.OPEN) {
      throw "Unable to send message. WebSocket is not opened.";
    }
    
    _ws.send(_converter.encode(message));
  }
  
  /// Message handler that decodes a JSON string to SignalingMessage
  void _onMessage(MessageEvent ev) {
    _messageController.add(_converter.decode(ev.data));
  }
}