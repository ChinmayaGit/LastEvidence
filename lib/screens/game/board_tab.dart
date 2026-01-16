import 'package:flutter/material.dart';
import 'package:lastevidence/models/player.dart';

import '../../models/game_state.dart';
import '../../models/board.dart';
import '../../models/room.dart';

class BoardTab extends StatelessWidget {
  final GameState gameState;
  final bool isMyTurn;
  final bool isOnline;
  final bool hasRolledDice;
  final List<BoardSquare> validMoves;
  final BoardSquare? selectedSquare;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final VoidCallback onEnterRoom;
  final VoidCallback onRollDice;
  final VoidCallback onPassTurn;
  final void Function(BoardSquare) onSquareTap;

  const BoardTab({
    super.key,
    required this.gameState,
    required this.isMyTurn,
    required this.isOnline,
    required this.hasRolledDice,
    required this.validMoves,
    required this.selectedSquare,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    required this.onEnterRoom,
    required this.onRollDice,
    required this.onPassTurn,
    required this.onSquareTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlayer = gameState.currentPlayer;

    return Column(
      children: [
        if (isOnline && !isMyTurn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentPlayer.name}\'s turn - wait for your turn',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: verticalScrollController,
                child: SingleChildScrollView(
                  controller: horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildBoard(),
                  ),
                ),
              );
            },
          ),
        ),
        if (isMyTurn || !isOnline)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (hasRolledDice)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEnterRoom,
                      icon: const Icon(Icons.door_front_door),
                      label: const Text('Enter Room'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                if (hasRolledDice) const SizedBox(width: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: hasRolledDice ? null : onRollDice,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasRolledDice
                            ? Colors.blue.shade100
                            : Colors.yellow.shade300,
                        border: Border.all(
                          color: hasRolledDice
                              ? Colors.blue.shade300
                              : Colors.orange.shade400,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: hasRolledDice
                            ? Text(
                                '${gameState.diceRoll}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              )
                            : Icon(
                                Icons.casino,
                                size: 32,
                                color: Colors.orange.shade800,
                              ),
                      ),
                    ),
                  ),
                ),
                if (hasRolledDice) const SizedBox(width: 16),
                if (hasRolledDice)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPassTurn,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Pass'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBoard() {
    const squareSize = 30.0;

    final board = gameState.board;
    final currentPlayer = gameState.currentPlayer;

    final playerPositions = <String, Player>{};
    for (final player in gameState.players) {
      final key = '${player.boardRow},${player.boardCol}';
      playerPositions[key] = player;
    }

    final roomPositions = <Room, Map<String, int>>{
      Room.study: {'row': 1, 'col': 1},
      Room.hall: {'row': 1, 'col': 6},
      Room.lounge: {'row': 1, 'col': 11},
      Room.library: {'row': 6, 'col': 1},
      Room.garden: {'row': 6, 'col': 6},
      Room.diningRoom: {'row': 6, 'col': 11},
      Room.rooftopPool: {'row': 11, 'col': 1},
      Room.basement: {'row': 11, 'col': 6},
      Room.kitchen: {'row': 11, 'col': 11},
    };

    final boardWidth = squareSize * Board.boardSize + 13;
    final boardHeight = squareSize * Board.boardSize + 13;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade100, Colors.grey.shade200],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(Board.boardSize, (row) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(Board.boardSize, (col) {
                    final square = board.squares[row][col];
                    final isCurrentPlayer =
                        currentPlayer.boardRow == row &&
                        currentPlayer.boardCol == col;
                    final isValidMove = validMoves.contains(square);
                    final isSelected = selectedSquare == square;
                    final key = '$row,$col';
                    final playerAtSquare = playerPositions[key];

                    Color squareColor;
                    IconData? squareIcon;
                    Color? iconColor;
                    double borderWidth = 1.0;
                    Color borderColor = Colors.grey.shade400;

                    if (square.room != null) {
                      final isCenter =
                          square.isDoor && square.doorToRoom != null;
                      squareColor = Colors.brown.shade300;

                      if (isCenter) {
                        squareIcon = Icons.door_front_door;
                        iconColor = Colors.brown.shade900;
                      }

                      final roomSq = board.roomSquares[square.room];
                      if (roomSq != null && roomSq.isNotEmpty) {
                        final minRow = roomSq
                            .map((s) => s.row)
                            .reduce((a, b) => a < b ? a : b);
                        final maxRow = roomSq
                            .map((s) => s.row)
                            .reduce((a, b) => a > b ? a : b);
                        final minCol = roomSq
                            .map((s) => s.col)
                            .reduce((a, b) => a < b ? a : b);
                        final maxCol = roomSq
                            .map((s) => s.col)
                            .reduce((a, b) => a > b ? a : b);

                        final isOuterEdge =
                            row == minRow ||
                            row == maxRow ||
                            col == minCol ||
                            col == maxCol;
                        if (isOuterEdge) {
                          borderColor = Colors.brown.shade700;
                          borderWidth = 2.0;
                        } else {
                          borderColor = Colors.brown.shade300;
                          borderWidth = 0;
                        }
                      } else {
                        borderColor = Colors.brown.shade600;
                        borderWidth = 2.0;
                      }
                    } else {
                      squareColor = Colors.grey.shade200;
                      borderColor = Colors.grey.shade400;
                      borderWidth = 1.0;
                    }

                    if (isValidMove) {
                      squareColor = Colors.blue.shade300;
                      borderColor = Colors.blue.shade600;
                      borderWidth = 2.5;
                    }

                    if (isSelected) {
                      squareColor = Colors.blue.shade500;
                      borderColor = Colors.blue.shade900;
                      borderWidth = 3.0;
                    }

                    if (isCurrentPlayer) {
                      borderColor = Colors.red.shade700;
                      borderWidth = 3.0;
                    }

                    return GestureDetector(
                      onTap: () => onSquareTap(square),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: squareSize,
                        height: squareSize,
                        margin: const EdgeInsets.all(0.5),
                        decoration: BoxDecoration(
                          color: squareColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: borderColor,
                            width: borderWidth,
                          ),
                          boxShadow: isValidMove || isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : isCurrentPlayer
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                        ),
                        child: Stack(
                          children: [
                            if (squareIcon != null)
                              Center(
                                child: Icon(
                                  squareIcon,
                                  size: squareSize * 0.5,
                                  color: iconColor,
                                ),
                              ),
                            if (playerAtSquare != null)
                              Center(
                                child: Container(
                                  width: squareSize * 0.7,
                                  height: squareSize * 0.7,
                                  decoration: BoxDecoration(
                                    color: playerAtSquare.playerColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      playerAtSquare.firstLetter,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: squareSize * 0.3,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
            ...roomPositions.entries.map((entry) {
              final room = entry.key;
              final pos = entry.value;
              return Positioned(
                left: pos['col']! * squareSize - 25,
                top: pos['row']! * squareSize - 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.brown.shade700, Colors.brown.shade900],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

