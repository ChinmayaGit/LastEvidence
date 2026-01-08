import 'package:flutter/material.dart';
import 'room.dart';

enum NoteState {
  none,
  askedAndHasIt,
  mightBeAnswer,
  isAnswer,
}

class Player {
  final String name;
  final bool isComputer;
  final int skillLevel; // 1 = novice, 2 = intermediate, 3 = experienced
  final List<String> clueCards;
  final Room? currentRoom;
  final int boardRow;
  final int boardCol;
  final bool isOutOfGame;
  final Map<String, NoteState> notes; // Player's personal notes
  
  Player({
    required this.name,
    this.isComputer = false,
    this.skillLevel = 1,
    List<String>? clueCards,
    this.currentRoom,
    this.boardRow = 12,
    this.boardCol = 12,
    this.isOutOfGame = false,
    Map<String, NoteState>? notes,
  }) : clueCards = clueCards ?? [],
       notes = notes ?? {};

  Player copyWith({
    String? name,
    bool? isComputer,
    int? skillLevel,
    List<String>? clueCards,
    Room? currentRoom,
    int? boardRow,
    int? boardCol,
    bool? isOutOfGame,
    Map<String, NoteState>? notes,
  }) {
    return Player(
      name: name ?? this.name,
      isComputer: isComputer ?? this.isComputer,
      skillLevel: skillLevel ?? this.skillLevel,
      clueCards: clueCards ?? this.clueCards,
      currentRoom: currentRoom ?? this.currentRoom,
      boardRow: boardRow ?? this.boardRow,
      boardCol: boardCol ?? this.boardCol,
      isOutOfGame: isOutOfGame ?? this.isOutOfGame,
      notes: notes ?? this.notes,
    );
  }
  
  // Generate color from player name hash
  Color get playerColor {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    final hash = name.hashCode;
    return colors[hash.abs() % colors.length].shade600;
  }
  
  // Get first letter of player name
  String get firstLetter => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

