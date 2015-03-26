import 'package:webrtc_utils/client.dart';
import 'dart:html';
import 'dart:typed_data';
// Used for delaying the sending one tick
import 'dart:async';

const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://${window.location.hostname}:28080';
P2PClient client;

int channelId = 1;

void _onPeerJoined(Peer peer) {
  bool isInitiator = client.id < peer.id;
  
  peer.onChannel.listen((final RtcDataChannel channel) {
    print('Channel created: ${channel.label} (ID: ${channel.id}, Reliable: ${channel.reliable})');
    channel.binaryType = 'arraybuffer';
    
    channel.onClose.listen((Event ev) {
      print('Channel ${channel.label} closed');
      
      if(isInitiator) {
        peer.createChannel('channel${channelId++}');
      }
    });
    
    channel.onError.listen((Event ev) {
      print('Channel ${channel.label} error: ${channel.readyState}');
    });
    
    print('Channel.readyState = ${channel.readyState}');
    Timer stateTimer = new Timer.periodic(new Duration(seconds: 1), (Timer t) {
      print('Channel.readyState = ${channel.readyState}');
    });
    
    if(isInitiator) {
      print('Initiator');
      
      channel.onOpen.listen((Event ev) {
        stateTimer.cancel();
        
        print('Channel opened');
        
        channel.send(new Uint8List(1024));  
        channel.send('done');
      });
      
      channel.onMessage.listen((MessageEvent ev) {
        print(ev.data);
        if(ev.data == 'close') {
          channel.close();
        }
      });
    } else {
      print('Receiver');
      
      List receiveBuffer = [];
      
      channel.onOpen.listen((Event ev) {
        stateTimer.cancel();
        print('Channel opened');
        channel.send('hello');
      });
      
      channel.onMessage.listen((MessageEvent ev) {
        if(ev.data is ByteBuffer) {
          ByteBuffer buffer = ev.data;
          print('Chunk received: ${buffer.lengthInBytes}');
        } else {
          print(ev.data);
          if(ev.data == 'done') {
            print('Closing channel due to done message.');
            channel.send('close');
            channel.close();
          }
        }
      });
    }
  });
  
  if(isInitiator) {
    print('I am the initiator');
    peer.createChannel('channel${channelId++}');
  }
}

void main() {
  client = new WebSocketP2PClient(url, rtcConfiguration);
  client.onConnect.listen((final int id) {
    print('Local ID: $id');
    client.join('filetransfer');
  });
  
  client.onJoinRoom.listen((final Room room) {
    room.peers.forEach(_onPeerJoined);
    room.onPeerJoin.listen(_onPeerJoined);
  });
}