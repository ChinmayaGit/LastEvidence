import 'room.dart';

class BoardSquare {
  final int row;
  final int col;
  final Room? room;
  final bool isCorridor;
  final bool isDoor;
  final Room? doorToRoom;

  BoardSquare({
    required this.row,
    required this.col,
    this.room,
    this.isCorridor = true,
    this.isDoor = false,
    this.doorToRoom,
  });
}

class Board {
  static const int boardSize = 13; // 13x13 static grid: 3 rooms (3x3 each) + 2 corridors between = 3+2+3+2+3 = 13
  final List<List<BoardSquare>> squares;
  final Map<Room, List<BoardSquare>> roomSquares;
  final Map<Room, List<BoardSquare>> roomDoors;

  Board({
    required this.squares,
    required this.roomSquares,
    required this.roomDoors,
  });

  // Create a simplified board layout
  static Board createBoard() {
    final squares = <List<BoardSquare>>[];
    final roomSquares = <Room, List<BoardSquare>>{};
    final roomDoors = <Room, List<BoardSquare>>{};

    // Initialize all squares as corridors
    for (int row = 0; row < boardSize; row++) {
      squares.add([]);
      for (int col = 0; col < boardSize; col++) {
        squares[row].add(BoardSquare(row: row, col: col, isCorridor: true));
      }
    }

    // Define room positions - each room is 3x3, arranged in 3x3 grid
    // Room positions: rows 0-2, 5-7, 10-12 and cols 0-2, 5-7, 10-12
    // Between rooms: rows 3-4, 8-9 and cols 3-4, 8-9 (2 boxes each)
    // Layout: Room(3) + Gap(2) + Room(3) + Gap(2) + Room(3) = 13
    final roomPositions = {
      Room.study: {'startRow': 0, 'startCol': 0},      // Top-left
      Room.hall: {'startRow': 0, 'startCol': 5},       // Top-middle
      Room.lounge: {'startRow': 0, 'startCol': 10},    // Top-right
      Room.library: {'startRow': 5, 'startCol': 0},    // Middle-left
      Room.garden: {'startRow': 5, 'startCol': 5},     // Middle-center
      Room.diningRoom: {'startRow': 5, 'startCol': 10},  // Middle-right
      Room.rooftopPool: {'startRow': 10, 'startCol': 0}, // Bottom-left
      Room.basement: {'startRow': 10, 'startCol': 5},    // Bottom-middle
      Room.kitchen: {'startRow': 10, 'startCol': 10},    // Bottom-right
    };

    // Mark room squares - each room occupies 3x3 area
    for (final entry in roomPositions.entries) {
      final room = entry.key;
      final startRow = entry.value['startRow']!;
      final startCol = entry.value['startCol']!;
      final roomSq = <BoardSquare>[];
      final doors = <BoardSquare>[];
      
      // Mark all 3x3 squares as part of the room
      for (int r = startRow; r < startRow + 3; r++) {
        for (int c = startCol; c < startCol + 3; c++) {
          if (r < boardSize && c < boardSize) {
            // Mark center square as door, edges as room borders
            final isCenter = r == startRow + 1 && c == startCol + 1;
            final isEdge = r == startRow || r == startRow + 2 || c == startCol || c == startCol + 2;
            
            final square = BoardSquare(
              row: r,
              col: c,
              room: room,
              isCorridor: false,
              isDoor: isCenter || isEdge, // Center and edges are entry points
              doorToRoom: isCenter ? room : null,
            );

            squares[r][c] = square;
            roomSq.add(square);
            if (isCenter || isEdge) {
              doors.add(square);
            }
          }
        }
      }

      roomSquares[room] = roomSq;
      roomDoors[room] = doors;
    }

    return Board(
      squares: squares,
      roomSquares: roomSquares,
      roomDoors: roomDoors,
    );
  }

  // Get valid moves from a position
  List<BoardSquare> getValidMoves(BoardSquare from, int steps) {
    final moves = <BoardSquare>[];
    final visited = <String>{};
    
    _findMoves(from, steps, moves, visited);
    return moves;
  }

  void _findMoves(BoardSquare from, int steps, List<BoardSquare> moves, Set<String> visited) {
    if (steps == 0) {
      final key = '${from.row},${from.col}';
      if (!visited.contains(key)) {
        moves.add(from);
        visited.add(key);
      }
      return;
    }

    final directions = [
      {'row': -1, 'col': 0}, // Up
      {'row': 1, 'col': 0},  // Down
      {'row': 0, 'col': -1}, // Left
      {'row': 0, 'col': 1},  // Right
    ];

    for (final dir in directions) {
      final newRow = from.row + dir['row']!;
      final newCol = from.col + dir['col']!;

      if (newRow >= 0 && newRow < boardSize && newCol >= 0 && newCol < boardSize) {
        final nextSquare = squares[newRow][newCol];
        
        // Can move to corridors or rooms (but not through room walls)
        if (nextSquare.isCorridor || 
            (nextSquare.room != null && from.room == nextSquare.room) ||
            (nextSquare.isDoor && from.isCorridor)) {
          _findMoves(nextSquare, steps - 1, moves, visited);
        }
      }
    }
  }

  // Check if square is adjacent to a room door
  bool isAdjacentToRoom(BoardSquare square, Room room) {
    if (square.room == room) return true;
    
    final doors = roomDoors[room] ?? [];
    for (final door in doors) {
      final rowDiff = (square.row - door.row).abs();
      final colDiff = (square.col - door.col).abs();
      if (rowDiff + colDiff == 1) {
        return true;
      }
    }
    return false;
  }

  // Get room from position
  Room? getRoomAt(int row, int col) {
    if (row >= 0 && row < boardSize && col >= 0 && col < boardSize) {
      return squares[row][col].room;
    }
    return null;
  }
}

