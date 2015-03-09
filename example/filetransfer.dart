import 'package:webrtc_utils/client.dart';
import 'dart:html';
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';

const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://${window.location.hostname}:28080';
P2PClient client;
Map<String, File> files = {};
void _onPeerJoined(Peer peer) {
  peer.onChannelCreated.listen((RtcDataChannel channel) {
    print('Channel created with label ${channel.label}');
    channel.binaryType = 'arraybuffer';
    
    if(files.containsKey(channel.label)) {
      print('Sender');
      
      channel.onOpen.listen((Event ev) {
        print('Channel is opened');
        final File file = files[channel.label];
        
        var chunkSize = 16384;
        sliceFile(int offset) {
          FileReader reader = new FileReader();
          reader.onLoad.listen((Event ev) {
            channel.send(reader.result);
            if (file.size > offset + (reader.result as TypedData).lengthInBytes) {
              new Future(() => sliceFile(offset + chunkSize));
            }
          });
          Blob slice = file.slice(offset, offset + chunkSize);
          reader.readAsArrayBuffer(slice);
        };
        sliceFile(0);
      });
      
      channel.onMessage.listen((MessageEvent ev) {
        print(ev.data);
      });
    } else {
      print('Receiver');
      List receiveBuffer = [];
      channel.onMessage.listen((MessageEvent ev) {
        if(ev.data is ByteBuffer) {
          if((ev.data as ByteBuffer).lengthInBytes < 16384) {
            AnchorElement save = new AnchorElement();
            save.target = '_blank';
            save.download = channel.label;
            save.href = Url.createObjectUrlFromBlob(new Blob(receiveBuffer, 'application/pdf'));
            document.body.append(save);
            save.click();
            save.remove();
          }
          receiveBuffer.add(ev.data);
        } else {
          print(ev.data);
        }
      });
    }
  });
}

void main() {
  client = new WebSocketP2PClient(url, rtcConfiguration);
  client.onConnected.listen((final int id) {
    client.join('filetransfer');
  });
  
  client.onRoomJoined.listen((final Room room) {
    room.peers.forEach(_onPeerJoined);
    room.onJoin.listen(_onPeerJoined);
    
    document.onDragEnter.listen((MouseEvent ev) {
    });
    
    document.onDragLeave.listen((MouseEvent ev) {
    });
    
    document.onDragOver.listen((MouseEvent ev) {
      ev.preventDefault();
    });
    
    document.onDragStart.listen((MouseEvent ev) {
      
    });
    
    document.onDragEnd.listen((MouseEvent ev) {
      
    });
    
    document.onDrop.listen((MouseEvent ev) {
      ev.stopPropagation();
      ev.preventDefault();
      
      print('Something dropped');
      
      if(ev.dataTransfer.files.length > 0) {
        ev.dataTransfer.files.forEach((File file) {
          room.peers.forEach((Peer peer) {
            peer.createChannel(file.name, {'ordered': true, 'reliable': true});
            files[file.name] = file;
          });
        });
      }
      
      return false;
    });
  });
}