## 0.2.1
- Fix:    Interfaces used internal classes
- Change: Delayed synchronized messages in a game no longer get dropped.
- Add:    Dart doc added
- Add:    Added tick method to GameRoomRenderer

## 0.2.0+2
- Fix:    Two interface problems in client and game library changed
- Fix:    Cyclic dependency problem in the client interfaces -> removed the client getter on P2PClient

## 0.2.0
- Change: Moved all examples to their own directory
- Change: Moved synchronization code from example to game library
- Add:    First game library: WebSocketP2PGame and SynchronizedWebSocketP2PGame
- Add:    Concept of a game room renderer added

## 0.1.0
- Add:    First published version with basic functionality for P2PClient and WebSocketP2PClient