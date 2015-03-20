part of webrtc_utils.game;

/**
 * Represents a message within the game
 */

abstract class GameMessage {
  TypedData serialize();
}

abstract class GameMessageFactory {
  GameMessage unserialize(TypedData data);
}

/**
 * The protocol on top of a [RtcDataChannel] that is used to exchance game information between peers
 */

class GameProtocol implements DataChannelProtocol<GameMessage> {
  
  /**
   * The underlying [RtcDataChannel]
   */
  
  final RtcDataChannel channel;
  
  /**
   * The P2P Game instance, used to get the [GameMessageFactory] from
   */
  
  final P2PGame game;
  
  Stream<GameMessage> get onMessage => _onMessageController.stream;
  StreamController<GameMessage> _onMessageController = new StreamController<GameMessage>.broadcast();
  
  GameProtocol(this.game, this.channel) {
    // Data will be transfered as ArrayBuffer (ByteBuffer)
    // NOTE: blob is not supported at the moment!
    channel.binaryType = 'arraybuffer';
    channel.onMessage.listen((MessageEvent ev) => _onMessage(ev.data));
  }
  
  /**
   * Sends a game message
   */
  
  void send(GameMessage m) {
    channel.send(m.serialize());
  }
  
  /**
   * Internal message handler
   */
  
  void _onMessage(Object message) {
    if(message is ByteBuffer) {
      ByteData data = message.asByteData();
      _onMessageController.add(game.messageFactory.unserialize(data));
    } else {
      throw "Unsupported message in GameProtocol: $message";
    }
  }
}