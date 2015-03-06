import 'package:webrtc_utils/signaling/server.dart';

/**
 * Example Signaling Server
 */

void main() {
  new SignalingServer()..listen(28081).then((SignalingServer server) {
    print('SignalingServer created: $server');
  });
}