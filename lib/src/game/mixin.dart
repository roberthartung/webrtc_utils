part of webrtc_utils.game;

abstract class ReadyPlayer {
  get isReady;

  Stream get onReadyStateChanged;
}

abstract class NamedPlayer {
  get name;
}

class NamedPlayerMixin implements NamedPlayer {
  String get name => _name;
  String _name;

  void setName(String name) {
    _name = name;
  }
}

abstract class ReadyPlayerMixin implements ReadyPlayer {
  bool get isReady => _isReady;
  var _isReady;

  void setReady(bool ready) {
    if(ready != _isReady) {
      _isReady = ready;
      // TODO(rh): Fire event
    }
  }
}