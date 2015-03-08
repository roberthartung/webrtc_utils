library webrtc_utils.converter;

import 'dart:convert';
// Used for SignalingMessage for converter message

part 'src/converter/json.dart';

abstract class Converter {
  dynamic encode(dynamic o);
  dynamic decode(dynamic o);
}