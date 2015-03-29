/**
 * Communication part of the game library
 * 
 * Provides basic communication classes like [GameMessage] and an interface for serializing gamemessages
 */

part of webrtc_utils.game;

/**
 * The message factory unserializes and serializes messages
 */

abstract class MessageFactory<M> {
  M unserialize(dynamic data);
  dynamic serialize(M message);
}

/**
 * A message based protocol on top of a [RtcDataChannel] that is used to exchance information between peers
 * 
 * To leave implementation, definition and serialization of messages up to the user, the concept of a [MessageFactory] is used
 */

class MessageProtocol<M> implements DataChannelProtocol<M> {
  /**
   * The underlying [RtcDataChannel]
   */
  
  final RtcDataChannel channel;
  
  /**
   * The P2P Game instance, used to get the [GameMessageFactory] from
   */
  
  final MessageFactory<M> messageFactory;
  
  Stream<M> get onMessage => _onMessageController.stream;
  StreamController<M> _onMessageController = new StreamController<M>.broadcast();
  
  MessageProtocol(this.channel, this.messageFactory) {
    // Data will be transfered as ArrayBuffer (TypedData -> ByteBuffer instance)
    // NOTE: blob is not supported at the moment!
    // channel.binaryType = 'arraybuffer';
    channel.onMessage.listen((MessageEvent ev) => _onMessage(ev.data));
  }
  
  /**
   * Sends a game message
   */
  
  void send(M m) {
    channel.send(messageFactory.serialize(m));
  }
  
  /**
   * Internal message handler
   */
  
  void _onMessage(dynamic message) {
    _onMessageController.add(messageFactory.unserialize(message));
  }
}

/**
 * Interface for a game message
 */

abstract class GameMessage {
  
}

/**
 * Interface for a synchronized game message. Actual message format
 * will be defined by the user.
 */

/*
abstract class SynchronizedGameMessage {
  int get tick;
  GameMessage get message;
}
*/

class SynchronizedGameMessage/* implements SynchronizedGameMessage*/ {
  final int tick;
  
  final GameMessage message;
  
  /*_*/SynchronizedGameMessage(this.tick, this.message);
}