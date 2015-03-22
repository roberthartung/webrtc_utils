part of webrtc_utils.client;

/**
 * Signaling Channel interface
 */

abstract class SignalingChannel {
  Stream<SignalingMessage> get onMessage;
  Stream<int> get onClose;
  Stream get onOpen;
  void send(SignalingMessage message);
}