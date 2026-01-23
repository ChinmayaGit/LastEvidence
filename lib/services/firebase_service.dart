import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player.dart';
import '../models/room.dart';

class Lobby {
  final String code;
  final String hostName;
  final List<Player> players;
  final bool isStarted;
  final DateTime createdAt;

  Lobby({
    required this.code,
    required this.hostName,
    required this.players,
    this.isStarted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'hostName': hostName,
      'players': players.map((p) => playerToJson(p)).toList(),
      'isStarted': isStarted,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  static Lobby fromJson(Map<String, dynamic> json) {
    return Lobby(
      code: json['code'] as String,
      hostName: json['hostName'] as String,
      players:
          (json['players'] as List<dynamic>?)
              ?.map((p) => playerFromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      isStarted: json['isStarted'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  static Map<String, dynamic> playerToJson(Player player) {
    return {
      'name': player.name,
      'playerId': player.playerId,
      'isComputer': player.isComputer,
      'skillLevel': player.skillLevel,
      'clueCards': player.clueCards,
      'boardRow': player.boardRow,
      'boardCol': player.boardCol,
      'isOutOfGame': player.isOutOfGame,
      'currentRoom': player.currentRoom?.name,
      'notes': player.notes.map((key, value) => MapEntry(key, value.name)),
    };
  }

  static Player playerFromJson(Map<String, dynamic> json) {
    final notesMap = <String, NoteState>{};
    if (json['notes'] != null) {
      (json['notes'] as Map<String, dynamic>).forEach((key, value) {
        notesMap[key] = NoteState.values.firstWhere(
          (e) => e.name == value.toString(),
          orElse: () => NoteState.none,
        );
      });
    }

    return Player(
      name: json['name'] as String,
      playerId: json['playerId'] as String?,
      isComputer: json['isComputer'] as bool? ?? false,
      skillLevel: json['skillLevel'] as int? ?? 1,
      clueCards:
          (json['clueCards'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      boardRow: json['boardRow'] as int? ?? 12,
      boardCol: json['boardCol'] as int? ?? 12,
      isOutOfGame: json['isOutOfGame'] as bool? ?? false,
      currentRoom: json['currentRoom'] != null
          ? Room.values.firstWhere(
              (e) => e.name == json['currentRoom'].toString(),
              orElse: () => Room.study,
            )
          : null,
      notes: notesMap,
    );
  }
}

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check for active game session for user
  Future<Map<String, dynamic>?> checkActiveSession(String userId) async {
    try {
      // 1. Check open lobbies first
      final lobbySnapshot = await _firestore
          .collection('lobbies')
          .where(
            'players',
            arrayContains: {'playerId': userId},
          ) // This won't work directly on array of maps
          .get();

      // Since we can't easily query array of maps by partial match in Firestore without specific structure,
      // we'll fetch open lobbies and filter manually (not efficient for large scale but works for now)
      // OR better: check all lobbies where user might be.

      // A better approach for session persistence is to store "currentLobbyId" in a "users" collection.
      // But sticking to the current structure, let's scan recent lobbies/games.

      // Let's try to find a lobby where this player ID exists in the players list
      // Note: This requires client-side filtering if we don't restructure data.
      final allLobbies = await _firestore.collection('lobbies').get();
      for (var doc in allLobbies.docs) {
        final data = doc.data();
        final players = (data['players'] as List<dynamic>?) ?? [];
        final isMember = players.any((p) => p['playerId'] == userId);

        if (isMember) {
          return {
            'type': 'lobby',
            'code': doc.id,
            'isStarted': data['isStarted'] ?? false,
            'data': data,
          };
        }
      }

      // 2. Check active games (if separate from lobbies)
      // In this app, games seem to share ID with lobbies but exist in 'games' collection once started
      // We should check 'games' collection too if the lobby is marked as started.
      final allGames = await _firestore.collection('games').get();
      for (var doc in allGames.docs) {
        final data = doc.data();
        if (data['gameOver'] == true) continue; // Skip finished games

        final players = (data['players'] as List<dynamic>?) ?? [];
        final isMember = players.any((p) => p['playerId'] == userId);

        if (isMember) {
          return {'type': 'game', 'code': doc.id, 'data': data};
        }
      }

      return null;
    } catch (e) {
      print('Error checking active session: $e');
      return null;
    }
  }

  // Generate a random 6-digit code
  String _generateLobbyCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Create a new lobby
  Future<String> createLobby(String hostName, Player hostPlayer) async {
    final code = _generateLobbyCode();
    final lobby = Lobby(
      code: code,
      hostName: hostName,
      players: [hostPlayer],
      createdAt: DateTime.now(),
    );

    await _firestore.collection('lobbies').doc(code).set(lobby.toJson());
    return code;
  }

  // Join a lobby by code
  Future<bool> joinLobby(String code, Player player) async {
    try {
      final doc = await _firestore.collection('lobbies').doc(code).get();
      if (!doc.exists) {
        return false; // Lobby doesn't exist
      }

      final lobby = Lobby.fromJson(doc.data()!);

      if (lobby.isStarted) {
        return false; // Game already started
      }

      if (lobby.players.length >= 6) {
        return false; // Lobby is full
      }

      // Check if player name already exists
      if (lobby.players.any((p) => p.name == player.name)) {
        return false; // Name already taken
      }

      // Add player to lobby
      final updatedPlayers = [...lobby.players, player];
      await _firestore.collection('lobbies').doc(code).update({
        'players': updatedPlayers.map((p) => Lobby.playerToJson(p)).toList(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get all open lobbies
  Stream<List<Lobby>> getOpenLobbies() {
    return _firestore.collection('lobbies').snapshots().map((snapshot) {
      final lobbies = <Lobby>[];

      for (var doc in snapshot.docs) {
        try {
          final lobby = Lobby.fromJson(doc.data());
          if (!lobby.isStarted && lobby.players.length < 6) {
            lobbies.add(lobby);
          }
        } catch (e) {
          // Skip invalid lobbies
        }
      }

      return lobbies;
    });
  }

  // Get lobby by code
  Stream<Lobby?> getLobby(String code) {
    return _firestore.collection('lobbies').doc(code).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) {
        return null;
      }

      try {
        return Lobby.fromJson(snapshot.data()!);
      } catch (e) {
        return null;
      }
    });
  }

  // Remove player from lobby
  Future<void> leaveLobby(String code, String playerName) async {
    final doc = await _firestore.collection('lobbies').doc(code).get();
    if (!doc.exists) return;

    final lobby = Lobby.fromJson(doc.data()!);

    final updatedPlayers = lobby.players
        .where((p) => p.name != playerName)
        .toList();

    if (updatedPlayers.isEmpty) {
      // Delete lobby if empty
      await _firestore.collection('lobbies').doc(code).delete();
    } else {
      // Update lobby
      await _firestore.collection('lobbies').doc(code).update({
        'players': updatedPlayers.map((p) => Lobby.playerToJson(p)).toList(),
        'hostName': updatedPlayers.first.name, // New host
      });
    }
  }

  // Start the game
  Future<void> startGame(String code) async {
    await _firestore.collection('lobbies').doc(code).update({
      'isStarted': true,
    });
  }

  // Delete lobby
  Future<void> deleteLobby(String code) async {
    await _firestore.collection('lobbies').doc(code).delete();
  }

  // Save game state to Firestore
  Future<void> saveGameState(
    String code,
    List<Player> players,
    int currentPlayerIndex,
    int diceRoll,
    int remainingSteps,
    bool gameOver,
    String? winner,
  ) async {
    await _firestore.collection('games').doc(code).set({
      'players': players.map((p) => Lobby.playerToJson(p)).toList(),
      'currentPlayerIndex': currentPlayerIndex,
      'diceRoll': diceRoll,
      'remainingSteps': remainingSteps,
      'gameOver': gameOver,
      'winner': winner,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Get game state stream
  Stream<Map<String, dynamic>?> getGameState(String code) {
    return _firestore.collection('games').doc(code).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return snapshot.data();
    });
  }

  // Update current player index (turn)
  Future<void> updateCurrentPlayer(String code, int currentPlayerIndex) async {
    await _firestore.collection('games').doc(code).update({
      'currentPlayerIndex': currentPlayerIndex,
      'diceRoll': 0,
      'remainingSteps': 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Update player position
  Future<void> updatePlayerPosition(
    String code,
    String playerName,
    int boardRow,
    int boardCol,
    String? currentRoom,
  ) async {
    final gameDoc = await _firestore.collection('games').doc(code).get();
    if (!gameDoc.exists) return;

    final data = gameDoc.data()!;
    final players = (data['players'] as List<dynamic>)
        .map((p) => Lobby.playerFromJson(p as Map<String, dynamic>))
        .toList();

    final updatedPlayers = players.map((p) {
      if (p.name == playerName) {
        return Lobby.playerToJson(
          p.copyWith(
            boardRow: boardRow,
            boardCol: boardCol,
            currentRoom: currentRoom != null
                ? Room.values.firstWhere(
                    (r) => r.name == currentRoom,
                    orElse: () => Room.study,
                  )
                : null,
          ),
        );
      }
      return Lobby.playerToJson(p);
    }).toList();

    await _firestore.collection('games').doc(code).update({
      'players': updatedPlayers,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Send suggestion notification
  Future<void> sendSuggestionNotification(
    String code,
    String askerName,
    String askedPlayerName,
    bool cardShown,
    List<String> askedItems,
  ) async {
    await _firestore
        .collection('games')
        .doc(code)
        .collection('notifications')
        .add({
          'type': 'suggestion',
          'askerName': askerName,
          'askedPlayerName': askedPlayerName,
          'cardShown': cardShown,
          'askedItems': askedItems,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  // Get suggestion notifications stream
  Stream<Map<String, dynamic>?> getSuggestionNotifications(String code) {
    return _firestore
        .collection('games')
        .doc(code)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return {'id': doc.id, ...doc.data()};
        });
  }

  // Mark notification as read
  Future<void> markNotificationRead(String code, String notificationId) async {
    await _firestore
        .collection('games')
        .doc(code)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  // Send suggestion request to asked player
  Future<String> sendSuggestionRequest(
    String code,
    String askerName,
    String askedPlayerName,
    List<String> askedItems,
    List<String> matchingCards,
    List<String> cardsYouHave,
  ) async {
    final docRef = await _firestore
        .collection('games')
        .doc(code)
        .collection('suggestionRequests')
        .add({
          'type': 'request',
          'askerName': askerName,
          'askedPlayerName': askedPlayerName,
          'askedItems': askedItems,
          'matchingCards': matchingCards,
          'cardsYouHave': cardsYouHave,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
    return docRef.id;
  }

  // Get suggestion requests stream for a specific player
  Stream<Map<String, dynamic>?> getSuggestionRequests(
    String code,
    String playerName,
  ) {
    return _firestore
        .collection('games')
        .doc(code)
        .collection('suggestionRequests')
        .where('askedPlayerName', isEqualTo: playerName)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .handleError((error) {
          // Log error but don't crash - index might not be created yet
          print('Error getting suggestion requests: $error');
        })
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          // Get the most recent one (by document ID or manually sort)
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final aTime = a.data()['timestamp'] as Timestamp?;
            final bTime = b.data()['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          final doc = docs.first;
          return {'id': doc.id, ...doc.data()};
        });
  }

  // Send suggestion response (selected card)
  Future<void> sendSuggestionResponse(
    String code,
    String requestId,
    String? selectedCard,
  ) async {
    await _firestore
        .collection('games')
        .doc(code)
        .collection('suggestionRequests')
        .doc(requestId)
        .update({
          'status': 'completed',
          'selectedCard': selectedCard,
          'responseTimestamp': FieldValue.serverTimestamp(),
        });
  }

  // Get suggestion responses stream for asker
  Stream<Map<String, dynamic>?> getSuggestionResponses(
    String code,
    String askerName,
  ) {
    return _firestore
        .collection('games')
        .doc(code)
        .collection('suggestionRequests')
        .where('askerName', isEqualTo: askerName)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .handleError((error) {
          // Log error but don't crash - index might not be created yet
          print('Error getting suggestion responses: $error');
        })
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          // Get the most recent one (by document ID or manually sort)
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final aTime = a.data()['responseTimestamp'] as Timestamp?;
            final bTime = b.data()['responseTimestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          final doc = docs.first;
          return {'id': doc.id, ...doc.data()};
        });
  }

  // Delete suggestion request/response after processing
  Future<void> deleteSuggestionRequest(String code, String requestId) async {
    await _firestore
        .collection('games')
        .doc(code)
        .collection('suggestionRequests')
        .doc(requestId)
        .delete();
  }
}
