part of webrtc_utils.server;

class Room {
  final String name;

  final String password;

  Map<int, Peer> peers = {};

  Room(this.name, this.password) {
    print('Room $name created with password $password');
  }

  String toString() => 'Room:$name';
}
