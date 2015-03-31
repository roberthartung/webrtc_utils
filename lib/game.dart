/// A library to help build Peer-to-Peer based games in the browser
///
/// When developing a P2P Game that relies on time or points in time
/// there are two problems:
///
/// * clock drift    (problem over time)
/// * clock offset   (initial / adjusted)
///
/// This library helps to get rid of these two side effects and make synchronisation more easy.
/// To minimize clock drift we will use [window.performance.now] to get an accurate time. This is
/// a clock that should be accurate between 1ms and 1µs.
///
/// TODO(rh): Fix rest of this documentation below.
///
/// In a browser based P2P game you usually use [window.requestAnimationFrame] to get a
/// stable 60 fps. The callback takes one argument: A double that represents a
/// high precision timestamp. It starts measuring time when the document is loaded. So this
/// time naturally differs between each pair of peers. Thus the difference between these times
/// has to be measured between pairs.
///
/// The clock offset can be approximated by measuring the ping that is
///
///      ping := (Round Trip Time (RTT)  / 2)
///
/// We take the average ping to all peers. This does give a good appoximation,
/// however we don't know the ping between the other peers. Thus we assume the
/// worst case behaviour
///
///      A <-- PingAB --> B <-- PingBC --> C
///
/// and we assume that the ping between A and C is twice the maximum ping between
/// A and B and B and C so:
///
///      maxping := 2 * max( PingAB, PingBC )
///
/// This will be the initial delay and it can be adjusted (if needed) later in time if needed.
///
/// In a P2P Game you might generate (synchronized) events on all peers. If a peer
/// wishes to generate an event it takes the local time and adds the offset (maxping) to it.
/// This way the events should occur almost at the same point in time from a global point of view.
///
/// As there might be a clock drift between pairs of peers the difference has to be measured.
/// To get an accurate result we use [window.performance.now].

library webrtc_utils.game;

import 'dart:html';
import 'dart:async';
import 'client.dart';
import 'dart:collection';

// export 'client.dart';

part 'src/game/game.dart';
part 'src/game/room.dart';
part 'src/game/player.dart';
part 'src/game/protocol.dart';
