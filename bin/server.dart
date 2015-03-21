import 'package:webrtc_utils/server.dart';

/**
 * Example Signaling Server
 * 
 * Port 28080 can be changed as you want!
 */

void main() {
  new SignalingServer()..listen(28080).then((SignalingServer server) {
    print('SignalingServer started.');
  });
}