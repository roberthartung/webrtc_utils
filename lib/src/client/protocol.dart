/**
 * A set of protocols supported by the data channel
 * 
 * TODO(rh): How can the users add their own protocols 
 */

part of webrtc_utils.client;

/**
 * Abstract
 */

abstract class DataChannelProtocol<M> {
  void send(dynamic data);
}

/**
 * Raw protocol that deliver's the raw messages
 */

class RawProtocol<M> implements DataChannelProtocol<M> {
  final RtcDataChannel channel;
  
  Stream<M> get onMessage => _onMessageController.stream;
  StreamController<M> _onMessageController = new StreamController<M>.broadcast();
  
  RawProtocol(this.channel) {
    channel.onMessage.listen((MessageEvent ev) {
      _onMessage(ev.data);
    });
  }
  
  void _onMessage(dynamic data) {
    _onMessageController.add(data);
  }
  
  void send(M message) {
    channel.send(message);
  }
}

/**
 * String protocol that delivers string
 */

class StringProtocol extends RawProtocol<String> {
  StringProtocol(RtcDataChannel channel) : super(channel);
}

/**
 *
 */

abstract class ProtocolProvider {
  DataChannelProtocol provide(RtcDataChannel channel);
}