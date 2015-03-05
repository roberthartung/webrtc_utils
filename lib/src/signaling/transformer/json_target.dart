part of webrtc_utils.signaling;

/**
 * Transforms messages to json
 */

class JsonTargetSignalingTransformer extends JsonSignalingTransformer implements TargetedSignalingChannelTransformer {
  /**
   * Serialize 
   */
  
  dynamic serialize(dynamic o, [int target]) {
    o['peer'] = {'id': target};
    var x = super.serialize(o);
    return x;
  }
  
  TargetedSignalingMessage unserialize(dynamic o) {
    Map x = super.unserialize(o);
    return new TargetedSignalingMessage(x['peer']['id'], x);
  }
}