import 'dart:math';
import 'player.dart';
import 'suspect.dart';
import 'weapon.dart';
import 'room.dart';
import 'board.dart';

class GameState {
  final List<Player> players;
  final int currentPlayerIndex;
  final int diceRoll;
  final int remainingSteps;
  final Board board;
  final Map<String, bool> detectiveNotes; // For tracking clues
  final String? murderer;
  final String? murderWeapon;
  final String? murderRoom;
  final bool gameOver;
  final String? winner;
  
  GameState({
    required this.players,
    this.currentPlayerIndex = 0,
    this.diceRoll = 0,
    this.remainingSteps = 0,
    Board? board,
    Map<String, bool>? detectiveNotes,
    this.murderer,
    this.murderWeapon,
    this.murderRoom,
    this.gameOver = false,
    this.winner,
  }) : board = board ?? Board.createBoard(),
       detectiveNotes = detectiveNotes ?? {};

  GameState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    int? diceRoll,
    int? remainingSteps,
    Board? board,
    Map<String, bool>? detectiveNotes,
    String? murderer,
    String? murderWeapon,
    String? murderRoom,
    bool? gameOver,
    String? winner,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      diceRoll: diceRoll ?? this.diceRoll,
      remainingSteps: remainingSteps ?? this.remainingSteps,
      board: board ?? this.board,
      detectiveNotes: detectiveNotes ?? this.detectiveNotes,
      murderer: murderer ?? this.murderer,
      murderWeapon: murderWeapon ?? this.murderWeapon,
      murderRoom: murderRoom ?? this.murderRoom,
      gameOver: gameOver ?? this.gameOver,
      winner: winner ?? this.winner,
    );
  }
  
  Player get currentPlayer => players[currentPlayerIndex];
  
  // Initialize game with random murder solution
  static GameState initialize(List<Player> players) {
    final random = Random();
    
    // Create board first
    final board = Board.createBoard();
    
    // Randomly select murder solution
    final suspects = Suspect.values;
    final weapons = Weapon.values;
    final rooms = Room.values;
    
    final murderer = suspects[random.nextInt(suspects.length)].name;
    final murderWeapon = weapons[random.nextInt(weapons.length)].name;
    final murderRoom = rooms[random.nextInt(rooms.length)].name;
    
    // Create all clue cards (excluding murder cards)
    final allSuspects = suspects.map((s) => s.name).toList();
    final allWeapons = weapons.map((w) => w.name).toList();
    final allRooms = rooms.map((r) => r.name).toList();
    
    allSuspects.remove(murderer);
    allWeapons.remove(murderWeapon);
    allRooms.remove(murderRoom);
    
    // Distribute cards evenly by category with balanced totals per player
    final playersWithCards = List<Player>.from(players.map((p) => p.copyWith(clueCards: [])));
    
    // Shuffle each category separately
    allSuspects.shuffle(random);
    allWeapons.shuffle(random);
    allRooms.shuffle(random);
    
    final numPlayers = players.length;
    
    // Calculate distribution for each category
    final suspectPerPlayer = allSuspects.length ~/ numPlayers;
    final suspectExtra = allSuspects.length % numPlayers;
    
    final weaponPerPlayer = allWeapons.length ~/ numPlayers;
    final weaponExtra = allWeapons.length % numPlayers;
    
    final roomPerPlayer = allRooms.length ~/ numPlayers;
    final roomExtra = allRooms.length % numPlayers;
    
    // Track which players get extras to balance totals
    final playerTotals = List<int>.filled(numPlayers, 0);
    
    // Helper function to distribute category with rotation for extras
    void distributeCategory(List<String> cards, int basePerPlayer, int extra, int startRotation) {
      if (cards.isEmpty) return;
      
      int cardIndex = 0;
      
      for (int playerIndex = 0; playerIndex < numPlayers; playerIndex++) {
        // Calculate if this player gets an extra card
        // Rotate the extras to balance totals
        final rotationIndex = (playerIndex + startRotation) % numPlayers;
        final getsExtra = rotationIndex < extra;
        final count = basePerPlayer + (getsExtra ? 1 : 0);
        
        final currentCards = List<String>.from(playersWithCards[playerIndex].clueCards);
        
        for (int j = 0; j < count && cardIndex < cards.length; j++) {
          currentCards.add(cards[cardIndex]);
          cardIndex++;
          playerTotals[playerIndex]++;
        }
        
        playersWithCards[playerIndex] = playersWithCards[playerIndex].copyWith(clueCards: currentCards);
      }
    }
    
    // Distribute each category with different rotation to balance totals
    // Start rotation at 0 for suspects, then rotate for weapons and rooms
    distributeCategory(allSuspects, suspectPerPlayer, suspectExtra, 0);
    distributeCategory(allWeapons, weaponPerPlayer, weaponExtra, suspectExtra);
    distributeCategory(allRooms, roomPerPlayer, roomExtra, suspectExtra + weaponExtra);
    
    // Room center positions (center of each 3x3 room)
    // Rooms start at 0, 5, 10, so centers are at 1, 6, 11
    final roomCenters = [
      {'row': 1, 'col': 1},   // Study (center of room at 0,0)
      {'row': 1, 'col': 6},   // Hall (center of room at 0,5)
      {'row': 1, 'col': 11},  // Lounge (center of room at 0,10)
      {'row': 6, 'col': 1},   // Library (center of room at 5,0)
      {'row': 6, 'col': 6},   // Billiard Room (center of room at 5,5)
      {'row': 6, 'col': 11},  // Dining Room (center of room at 5,10)
      {'row': 11, 'col': 1},  // Conservatory (center of room at 10,0)
      {'row': 11, 'col': 6},  // Ballroom (center of room at 10,5)
      {'row': 11, 'col': 11}, // Kitchen (center of room at 10,10)
    ];
    
    // Shuffle room centers and assign players randomly
    final shuffledCenters = List<Map<String, int>>.from(roomCenters);
    shuffledCenters.shuffle(random);

    final playersWithPosition = <Player>[];
    for (int i = 0; i < playersWithCards.length; i++) {
      final pos = shuffledCenters[i % shuffledCenters.length];
      final roomRow = pos['row']!;
      final roomCol = pos['col']!;
      
      // Get the room at this position
      final room = board.getRoomAt(roomRow, roomCol);
      
      playersWithPosition.add(
        playersWithCards[i].copyWith(
          boardRow: roomRow,
          boardCol: roomCol,
          currentRoom: room,
        ),
      );
    }

    return GameState(
      players: playersWithPosition,
      board: board,
      murderer: murderer,
      murderWeapon: murderWeapon,
      murderRoom: murderRoom,
    );
  }
  
  int rollDice() {
    final random = Random();
    return random.nextInt(6) + 1; // 1-6
  }
  
  // Check if a suggestion can be refuted by any player
  String? checkSuggestion(String suspect, String weapon, String room) {
    // Check players in order starting from next player
    for (int i = 1; i < players.length; i++) {
      final playerIndex = (currentPlayerIndex + i) % players.length;
      final player = players[playerIndex];
      
      if (player.isOutOfGame) continue;
      
      // Check if player has any of the suggested cards
      if (player.clueCards.contains(suspect) ||
          player.clueCards.contains(weapon) ||
          player.clueCards.contains(room)) {
        // Return the first matching card
        if (player.clueCards.contains(suspect)) return suspect;
        if (player.clueCards.contains(weapon)) return weapon;
        if (player.clueCards.contains(room)) return room;
      }
    }
    return null; // No one can refute
  }
  
  // Check if accusation is correct
  bool checkAccusation(String suspect, String weapon, String room) {
    return suspect == murderer &&
           weapon == murderWeapon &&
           room == murderRoom;
  }
}



