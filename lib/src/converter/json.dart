/**
 * Helper class to convert an Object to JSON (String)
 */

part of webrtc_utils.converter;

abstract class JsonConverter implements Converter {
  String encode(Object o) {
    return JSON.encode(o/*, toEncodable: _toEncodable*/);
  }
  
  Object decode(String s) {
    return JSON.decode(s/*, reviver: _reviver*/);
  }
  /*
  dynamic _toEncodable(dynamic o);
  
  dynamic _reviver(dynamic key, dynamic value);
  */
}