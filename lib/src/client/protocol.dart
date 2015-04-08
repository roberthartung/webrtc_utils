/// A set of protocols supported by the data channel
part of webrtc_utils.client;

/// Protocol interface: send method and message stream
abstract class DataChannelProtocol<M> {
  RtcDataChannel get channel;
  Stream<M> get onMessage;
  void send(dynamic data);
}

/// Raw protocol that deliver's the raw messages as they come in.
///
/// NOTE: Chrome does not supporting sending Blobs at the moment so sending Blogs might fail at the moment
class RawProtocol<M> implements DataChannelProtocol<M> {
  /// The [RtcDataChannel] instance to send message to and receive messages from
  final RtcDataChannel channel;

  /// Concrete message stream
  Stream<M> get onMessage => _onMessageController.stream;
  StreamController<M> _onMessageController =
      new StreamController<M>.broadcast();

  /// Constructor
  RawProtocol(this.channel) {
    channel.onMessage.listen(
        (MessageEvent ev) => _onMessageController.add(handleMessage(ev.data)));
  }

  /// Internal function that listens for incoming messages
  M handleMessage(data) {
    return data;
  }

  /// Sends a message [M] to the channel
  void send(message) {
    channel.send(message);
  }
}

/// String protocol that delivers string
class StringProtocol extends RawProtocol<String> {
  StringProtocol(RtcDataChannel channel) : super(channel);
}

/// Interface that provides an instance of [DataChannelProtocol]
/// Assignment from protocol to [ProtocolProvider] is done using [P2PClient.addProtocolProvider]
abstract class ProtocolProvider {
  DataChannelProtocol provide(Peer peer, RtcDataChannel channel);
}

/// Default implementation of a [ProtocolProvider] that always returns a RawProtocol
class DefaultProtocolProvider implements ProtocolProvider {
  DataChannelProtocol provide(_Peer peer, RtcDataChannel channel) {
    if (channel.protocol == 'json') {
      return new JsonProtocol(channel);
    }

    return new RawProtocol(channel);
  }
}

/// A Protcol that encodes objects from/to json
class JsonProtocol extends RawProtocol<Object> {
  JsonProtocol(RtcDataChannel channel) : super(channel);

  @override
  Object handleMessage(String data) {
    return JSON.decode(data);
  }

  @override
  void send(Object value) {
    super.send(JSON.encode(value));
  }
}
