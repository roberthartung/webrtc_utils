part of webrtc_utils.signaling;

/**
 * This is the basic signaling class that handles basic information
 */

abstract class SignalingMessage {
  
}

abstract class SignalingChannelTransformer {
  dynamic serialize(Object o);
  Object unserialize(dynamic o);
}

abstract class SignalingChannel {
  Stream<SignalingMessage> get onMessage;
  
  void send(Object message);
}