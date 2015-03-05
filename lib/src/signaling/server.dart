part of webrtc_utils.signaling.server;

const String PROTOCOL = 'webrtc_signaling';

/**
 * A Dual Peer Signaling Server that redirects messages between a pair of peers.
 * 
 * The url's path is taken as the 'room' name.
 */

class Peer {
  WebSocket _ws;
  
  Peer(this._ws) {
    
  }
  
  void send(Object o) {
    _ws.add(JSON.encode(o));
  }
}

class DualPeerSignalingServer {
  final int _port;
  
  Map<String, List<Peer>> rooms = {};
  
  DualPeerSignalingServer(this._port) {
    HttpServer.bind('0.0.0.0', _port).then((HttpServer server) {
      server.listen(_onHttpRequest);
    });
  }
  
  void _onHttpRequest(HttpRequest req) {
    final String room = req.requestedUri.path;
    WebSocketTransformer.upgrade(req, protocolSelector: (List<String> protocols) {
      if(protocols.contains(PROTOCOL)) {
        return PROTOCOL;
      }
      return false;
    }).catchError((err) {
      print('[ERROR] Unable to upgrade HttpRequest to WebSocket: $err');
    }).then((WebSocket webSocket) {
      if(webSocket == null || webSocket.protocol != PROTOCOL) {
        print('[ERROR] WebSocket not upgraded or wrong protocol.');
        return;
      }
      
      // Create new Peer
      final Peer peer = new Peer(webSocket);
      
      // Make sure the room is created
      if(!rooms.containsKey(room)) {
        rooms[room] = new List<Peer>();
      } else {
        // Notify others about the new peer?
      }
      
      // Add peer to room
      rooms[room].add(peer);
      
      webSocket.listen((json) {
        Map data = JSON.decode(json);
        print(data);
        if(data.containsKey('rtc_session_description')) {
          // Forward to other peer
          rooms[room].firstWhere((Peer otherPeer) => otherPeer != peer).send(data);
        } else if(data.containsKey('rtc_ice_candidate')) {
          // Forward to other peer
          rooms[room].firstWhere((Peer otherPeer) => otherPeer != peer).send(data);
        } else {
          print('Unknown message from WebSocket: $data');
        }
      });
      
      /*
      final Client client = new Client(webSocket, clientId++);
      
      client.send({'type': 'init', 'id': client.id});
      
      print('[$channel] New Client #${client.id}');
      
      if(!clients.containsKey(channel)) {
        clients[channel] = [];
      } else {
        // Exchange client IDs
        clients[channel].forEach((Client otherClient) {
          client.send({'type': 'client', 'id': otherClient.id});
          otherClient.send({'type': 'client', 'id': client.id});
        });
      }
      
      clients[channel].add(client);
      
      webSocket.done.then((_) {
        print('[$channel] Client #${client.id} closed connection.');
        clients[channel].remove(client);
      });
      
      // TODO(rh): Move this to the Client
      webSocket.listen((json) {
        var data = JSON.decode(json);
        switch(data['type']) {
          case 'candidate' :
            //  for ${data['target']['id']}
            print('[$channel] Candidate from client #${client.id}');
            /*
            client.addCandidate(data['candidate']);
            */
            // Only propagate candidates of this clients to clients with larger id.
            // >
            clients[channel].where((Client otherClient) => otherClient.id != client.id).forEach((Client otherClient) {
              otherClient.send({'type': 'candidate', 'client': {'id': client.id}, 'candidate': data['candidate']});
            });
            break;
          case "sdp" :
            print('[$channel] Sdp from Client #${client.id}: ${data['sdp']}');
            
            // Send SDP to other peer
            switch(data['sdp']['type']) {
              case 'offer' :
                clients[channel].where((Client otherClient) => otherClient.id > client.id).forEach((Client otherClient) {
                  otherClient.send({'type': 'sdp', 'client': {'id': client.id}, 'sdp': data['sdp']});
                });
                break;
              case 'answer' :
                clients[channel].where((Client otherClient) => otherClient.id < client.id).forEach((Client otherClient) {
                  otherClient.send({'type': 'sdp', 'client': {'id': client.id}, 'sdp': data['sdp']});
                });
                break;
            }
            break;
          default :
            print('data: $data');
            break;
        }
      });
      */
    });
  }
}