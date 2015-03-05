library webrtc_utils.signaling;

// WebSocket
import 'dart:html';

// JSON
import 'dart:convert';

// Streams
import 'dart:async';

// Converts messages from and to json
part 'src/signaling/transformer/json.dart';
part 'src/signaling/transformer/json_target.dart';
part 'src/signaling/channel.dart';
part 'src/signaling/channel/websocket.dart';

// Basic Handler class
// part 'src/signaling/handler.dart';
// (Demo) Implementation of a signaling handler that uses a WebSocket + JSON
// part 'src/signaling/handlers/websocket_json.dart';
//part 'src/signaling/messages/welcome.dart';
part 'src/signaling/messages/icecandidate.dart';
part 'src/signaling/messages/session_description.dart';