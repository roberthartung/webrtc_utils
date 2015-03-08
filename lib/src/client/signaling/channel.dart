part of webrtc_utils.client;

/**
 * Signaling Channel interface
 */

abstract class SignalingChannel {
  Stream<SignalingMessage> get onMessage;
  void send(SignalingMessage message);
}