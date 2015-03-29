import 'package:webrtc_utils/client.dart';
import 'dart:html';

/*
class ReliableP2PClient {
  P2PClient _client;
  
  ReliableP2PClient(this._client) {
     
  }
}
*/
const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://${window.location.hostname}:28080';
P2PClient client;
//ReliableP2PClient rClient;

void main() {
  client = new WebSocketP2PClient(url, rtcConfiguration);
  
  client.onConnect.listen((final int myId) {
    client.join('filetransfer');
  });
  
  //rClient = new ReliableP2PClient(client);
}