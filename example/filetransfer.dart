import 'package:webrtc_utils/client.dart';
import 'dart:html';
import 'dart:typed_data';
// Used for delaying the sending one tick
import 'dart:async';

const Map rtcConfiguration = const {"iceServers": const [ const {"url": "stun:stun.l.google.com:19302"}]};
final String url = 'ws://${window.location.hostname}:28080';
P2PClient client;
Map<String, File> files = {};
void _onPeerJoined(Peer peer) {
  // TODO(rh): It looks like we cannot open another RtcDataChannel when the old one is still open
  peer.onChannel.listen((RtcDataChannel channel) {
    print('Channel created with label ${channel.label} and id ${channel.id}');
    channel.binaryType = 'arraybuffer';
    
    channel.onClose.listen((Event ev) {
      print('Channel ${channel.label} closed');
    });
          
    channel.onError.listen((Event ev) {
      print('Channel ${channel.label} error: ${channel.readyState}');
    });
    
    print('Channel.readyState = ${channel.readyState}');
    Timer stateTimer = new Timer.periodic(new Duration(seconds: 1), (Timer t) {
      print('Channel.readyState = ${channel.readyState}');
    });
    
    if(files.containsKey(channel.label)) {
      print('Sender');
      
      channel.onOpen.listen((Event ev) {
        stateTimer.cancel();
        print('Channel opened');
        final File file = files[channel.label];
        final int startTime = new DateTime.now().millisecondsSinceEpoch;
        
        print('File to send: ${file.name} ${file.size}');
        
        var chunkSize = 16384;
        sliceFile(int offset) {
          FileReader reader = new FileReader();
          reader.onLoadEnd.listen((Event ev) {
            //print('bytes in buffer (before): ${channel.bufferedAmount}');
            channel.send(reader.result);
            //print('bytes in buffer (after): ${channel.bufferedAmount}');
            if (file.size > offset + (reader.result as TypedData).lengthInBytes) {
              // new Future(() => sliceFile(offset + chunkSize));
              // 0 Delay sending
              sliceFile(offset + chunkSize);
            } else {
              int time = new DateTime.now().millisecondsSinceEpoch - startTime;
              print('Sending done after ${time}ms');
              channel.send('done');
            }
          });
          Blob slice = file.slice(offset, offset + chunkSize);
          //print('Start reading: $slice');
          reader.readAsArrayBuffer(slice);
        };
        //print('Start slicing');
        sliceFile(0);
      });
      
      channel.onMessage.listen((MessageEvent ev) {
        if(ev.data == 'done') {
          channel.close();
        }
        print(ev.data);
      });
    } else {
      int startTime = new DateTime.now().millisecondsSinceEpoch;
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
          receiveBuffer.add(ev.data);
          print('Chunk received: ${buffer.lengthInBytes}');
          if(buffer.lengthInBytes < 16384) {
            int time = new DateTime.now().millisecondsSinceEpoch - startTime;
            print('Receiving done after ${time}ms');
            AnchorElement save = new AnchorElement();
            save.target = '_blank';
            save.download = channel.label;
            save.href = Url.createObjectUrlFromBlob(new Blob(receiveBuffer, 'application/pdf'));
            document.body.append(save);
            save.click();
            save.remove();
          }
        } else {
          print(ev.data);
          if(ev.data == 'done') {
            print('Closing channel due to done message.');
            channel.send('send');
            channel.close();
          }
        }
      });
    }
  });
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
            files[file.name] = file;
            peer.createChannel(file.name, {'ordered': true, 'reliable': true});
          });
        });
      }
      
      return false;
    });
  });
}