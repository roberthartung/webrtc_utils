/**
 * A helper library used by the [WebSocketP2PClient] that converts SignalingMessages
 */

library webrtc_utils.converter;

import 'dart:convert' show JSON;
part 'src/converter/json.dart';

/**
 * Converted interface
 */

abstract class Converter {
  /**
   * Encode message
   */
  
  dynamic encode(dynamic o);
  
  /**
   * Decode message
   */
  
  dynamic decode(dynamic o);
}