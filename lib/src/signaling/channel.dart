part of webrtc_utils.signaling;

/**
 * This is the basic signaling class that handles basic information
 */

abstract class SignalingMessage {
  
}

class RtcIceCandidateMessage extends SignalingMessage {
  final RtcIceCandidate candidate;
  RtcIceCandidateMessage(this.candidate);
}

class RtcSessionDescriptionMessage extends SignalingMessage {
  final RtcSessionDescription description;
  RtcSessionDescriptionMessage(this.description);
}

class TargetedSignalingMessage {
  final Map data;
  final int source;
  SignalingMessage message = null;
  TargetedSignalingMessage(this.source, this.data);
}

abstract class SignalingChannelTransformer {
  dynamic serialize(dynamic o);
  dynamic unserialize(dynamic o);
}

abstract class SignalingChannel {
  Stream<SignalingMessage> get onMessage;
  void send(Object message);
}

abstract class TargetedSignalingChannelTransformer extends SignalingChannelTransformer {
  dynamic serialize(dynamic o, [int target]);
  TargetedSignalingMessage unserialize(dynamic o);
}

abstract class TargetedSignalingChannel {
  int source;
  Stream<TargetedSignalingMessage> get onTargetedMessage;
  void send(Object message, [int target]);
}