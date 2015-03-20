part of webrtc_utils.game;

/**
 * A Player in the game
 */

abstract class Player {
  final P2PGame game; // CurveGame
  
  // final LIElement li;
  
  final int id;
  
  bool get isLocal => this is LocalPlayer;
  
  Player(this.game, this.id) /* : li = new LIElement() */ { 
    // li.appendHtml('<span class="name">Player#$id</span><span class="ping">-</span>');
  }
}

abstract class ReadyPlayer {
  bool _ready = false;
  bool get isReady => _ready;
  
  // Abstract
  bool get isLocal;
  P2PGame get game;
  
  void setReady(bool ready) {
    _ready = ready;
    // TODO(rh): Check if player is leader
    if(_ready) {
      // Now Ready
      //li.style.color = '#00FF00';
    } else {
      // Not ready
      //li.style.color = '#FF0000';
    }
    
    // Send status to other players
    if(isLocal) {
      game.players.where((Player otherPlayer) => otherPlayer is RemotePlayer).forEach((RemotePlayer remotePlayer) {
        remotePlayer.send(new ReadyStateChangedMessage(this));
      });
    }
  }
}

class LocalPlayer extends Player {
  LocalPlayer(P2PGame game, int id) : super(game, id);
}

abstract class GameChannel {
  GameProtocol get gameChannel => _gameProtocol;
  GameProtocol _gameProtocol = null;
}

abstract class ChattingPlayer {
  Peer get peer;
  StringProtocol get chatChannel => _chatProtocol;
  StringProtocol _chatProtocol = null;
}

abstract class PingPlayer extends GameChannel {
  Timer _pingTimer;
    
  int _pingTime;
  
  void startPingTimer() {
    _pingTimer = new Timer.periodic(new Duration(seconds: 1), (_) {
      if(gameChannel != null) {
        _pingTime = new DateTime.now().millisecondsSinceEpoch;
        send(new PingMessage());
      }
    });
  }
  
  void send(GameMessage message);
}

/**
 * A remote player
 */

class RemotePlayer extends Player {
  final Peer peer;
  
  final Map<String, DataChannelProtocol> channels = {};
  
  Stream<DataChannelProtocol> get onProtocol => _onProtocolStreamController.stream;
  StreamController<DataChannelProtocol> _onProtocolStreamController = new StreamController<DataChannelProtocol>.broadcast();
  
  RemotePlayer(P2PGame game, Peer peer) : super(game, peer.id), this.peer = peer {
    peer.onChannelCreated.listen(_onChannelCreated);
  }
  
  void _onChannelCreated(DataChannelProtocol protocol) {
    channels[protocol.channel.label] = protocol;
    _onProtocolStreamController.add(protocol);
  }
  
  /*
  void _onPingMessage(PingMessage ping) {
    //print('Ping message received: ${ping.time}');
    send(new PongMessage(/*ping.time*/));
  }
  
  void _onPongMessage(PongMessage message) {
    int ping = (new DateTime.now().millisecondsSinceEpoch - /*message.time*/_pingTime);
    li.querySelector('.ping').text = '$ping';
    print('Pong message received: ${ping}ms'); // ${message.time}
  }
  
  void _onReadyMessage(ReadyMessage m) {
    setReady(m.ready);
  }
  */
  
  /*
  void send(GameMessage message) {
    gameChannel.send(message);
  }
  */
}