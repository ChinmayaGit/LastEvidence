import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/board.dart';
import '../models/room.dart';
import '../services/firebase_service.dart';
import 'game/room_view_screen.dart';
import 'game/clue_cards_screen.dart';
import 'game/notes_screen.dart';
import 'game/board_tab.dart';
import 'game/game_status_view.dart';
import 'game/accusation_dialog.dart';

class GameBoardScreen extends StatefulWidget {
  final List<Player> initialPlayers;
  final bool isOnline;
  final String? lobbyCode;
  final String? localPlayerName; // Name of the player using this device

  const GameBoardScreen({
    super.key,
    required this.initialPlayers,
    this.isOnline = false,
    this.lobbyCode,
    this.localPlayerName,
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen>
    with TickerProviderStateMixin {
  late GameState _gameState;
  // Accusation state
  String? _selectedSuspect;
  String? _selectedWeapon;
  String? _selectedRoom;
  bool _hasRolledDice = false;
  BoardSquare? _selectedSquare;
  List<BoardSquare> _validMoves = [];
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Online mode variables
  String? _localPlayerName;
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _gameStateSubscription;
  StreamSubscription? _notificationSubscription;
  bool _isSyncing = false;
  String? _lastNotificationId;
  String? _lastRequestId;
  String? _lastResponseId;

  // Dice state
  int _currentDiceValue = 1;

  // Bottom navigation bar
  int _bottomNavIndex =
      2; // 0: Game Status, 1: Clues, 2: Board, 3: Notes, 4: Accuse
  final List<IconData> _bottomNavIcons = [
    Icons.info_outline, // Game Status
    Icons.credit_card, // Clues
    Icons.grid_view, // Board
    Icons.note, // Notes
    Icons.gavel, // Accuse
  ];

  @override
  void initState() {
    super.initState();

    _gameState = GameState.initialize(widget.initialPlayers);
    _updateCurrentPlayerRoom();

    // For online mode, identify local player and set up Firestore listener
    if (widget.isOnline && widget.lobbyCode != null) {
      // Use provided localPlayerName, or fall back to first player
      _localPlayerName =
          widget.localPlayerName ?? widget.initialPlayers.first.name;
      _initializeOnlineGame();
    }
  }

  void _initializeOnlineGame() async {
    // Save initial game state to Firestore
    await _firebaseService.saveGameState(
      widget.lobbyCode!,
      _gameState.players,
      _gameState.currentPlayerIndex,
      _gameState.diceRoll,
      _gameState.remainingSteps,
      _gameState.gameOver,
      _gameState.winner,
    );

    // Listen to game state updates
    _gameStateSubscription = _firebaseService
        .getGameState(widget.lobbyCode!)
        .listen((gameData) {
          if (gameData != null && !_isSyncing) {
            _updateGameStateFromFirestore(gameData);
          }
        });

    // Listen to suggestion notifications
    _notificationSubscription = _firebaseService
        .getSuggestionNotifications(widget.lobbyCode!)
        .listen((notification) {
          if (notification != null && mounted) {
            final notificationId = notification['id'] as String;
            // Only show if it's a new notification
            if (notificationId != _lastNotificationId) {
              _lastNotificationId = notificationId;
              _handleSuggestionNotification(notification);
            }
          }
        });

    // Listen to suggestion requests (for asked player)
    if (_localPlayerName != null && widget.lobbyCode != null) {
      _firebaseService
          .getSuggestionRequests(widget.lobbyCode!, _localPlayerName!)
          .listen(
            (request) {
              if (request != null && mounted) {
                final requestId = request['id'] as String?;
                if (requestId != null && requestId != _lastRequestId) {
                  _lastRequestId = requestId;
                  _handleSuggestionRequest(request);
                }
              }
            },
            onError: (error) {
              // Handle error gracefully
              print('Error listening to suggestion requests: $error');
            },
          );
    }

    // Listen to suggestion responses (for asker)
    if (_localPlayerName != null && widget.lobbyCode != null) {
      _firebaseService
          .getSuggestionResponses(widget.lobbyCode!, _localPlayerName!)
          .listen(
            (response) {
              if (response != null && mounted) {
                final responseId = response['id'] as String?;
                if (responseId != null && responseId != _lastResponseId) {
                  _lastResponseId = responseId;
                  _handleSuggestionResponse(response);
                }
              }
            },
            onError: (error) {
              // Handle error gracefully
              print('Error listening to suggestion responses: $error');
            },
          );
    }
  }

  void _handleSuggestionRequest(Map<String, dynamic> request) async {
    final requestId = request['id'] as String;
    final askerName = request['askerName'] as String? ?? 'Unknown';
    final askedItems =
        (request['askedItems'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final matchingCards =
        (request['matchingCards'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Find players
    final askerPlayer = _gameState.players.firstWhere(
      (p) => p.name == askerName,
      orElse: () => _gameState.players.first,
    );
    final askedPlayer = _gameState.players.firstWhere(
      (p) => p.name == _localPlayerName,
      orElse: () => _gameState.players.first,
    );

    // Show selection dialog
    final selectedCard = await _showCardSelectionDialogToAskedPlayer(
      askedPlayer,
      askerPlayer,
      askedItems,
      matchingCards,
    );

    // Send response
    if (mounted) {
      await _firebaseService.sendSuggestionResponse(
        widget.lobbyCode!,
        requestId,
        selectedCard,
      );
      // Delete the request after responding
      await _firebaseService.deleteSuggestionRequest(
        widget.lobbyCode!,
        requestId,
      );
    }
  }

  void _handleSuggestionResponse(Map<String, dynamic> response) {
    final responseId = response['id'] as String;
    final askerName = response['askerName'] as String? ?? 'Unknown';
    final askedPlayerName = response['askedPlayerName'] as String? ?? 'Unknown';
    final selectedCard = response['selectedCard'] as String?;
    final askedItems =
        (response['askedItems'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final cardsYouHave =
        (response['cardsYouHave'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (selectedCard == null) {
      if (widget.isOnline && widget.lobbyCode != null) {
        _firebaseService.sendSuggestionNotification(
          widget.lobbyCode!,
          askerName,
          askedPlayerName,
          false,
          askedItems,
        );
      }
      // No card selected - end turn silently
      _nextTurn();
      // Delete the response
      _firebaseService.deleteSuggestionRequest(widget.lobbyCode!, responseId);
      return;
    }

    // Find players
    final askerPlayer = _gameState.players.firstWhere(
      (p) => p.name == askerName,
      orElse: () => _gameState.players.first,
    );
    final askedPlayer = _gameState.players.firstWhere(
      (p) => p.name == askedPlayerName,
      orElse: () => _gameState.players.first,
    );

    // Find the room from the asked items (one should be a room)
    Room? room;
    for (final item in askedItems) {
      try {
        room = Room.values.firstWhere((r) => r.name == item);
        break;
      } catch (e) {
        // Not a room, continue
      }
    }
    final roomForNote = room ?? Room.study;

    // Show result to asker
    _showSuggestionResultToAsker(
      askerPlayer,
      askedPlayer,
      askedItems,
      selectedCard,
      cardsYouHave,
      roomForNote,
    );

    if (widget.isOnline && widget.lobbyCode != null) {
      _firebaseService.sendSuggestionNotification(
        widget.lobbyCode!,
        askerName,
        askedPlayerName,
        true,
        askedItems,
      );
    }

    // Delete the response after showing
    _firebaseService.deleteSuggestionRequest(widget.lobbyCode!, responseId);
  }

  void _handleSuggestionNotification(Map<String, dynamic> notification) {
    final askerName = notification['askerName'] as String? ?? 'Unknown';
    final askedPlayerName =
        notification['askedPlayerName'] as String? ?? 'Unknown';
    final cardShown = notification['cardShown'] as bool? ?? false;
    final askedItems =
        (notification['askedItems'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Don't show notification to the asker or the asked player
    if (askerName == _localPlayerName || askedPlayerName == _localPlayerName) {
      return;
    }

    // Show notification to other players
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('Suggestion Made'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$askerName asked $askedPlayerName'),
              const SizedBox(height: 8),
              if (askedItems.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text(
                  'Asked about:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...askedItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(item),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (cardShown)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$askedPlayerName showed a card to $askerName',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$askedPlayerName does not have any matching cards',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Mark notification as read
                if (widget.lobbyCode != null && _lastNotificationId != null) {
                  _firebaseService.markNotificationRead(
                    widget.lobbyCode!,
                    _lastNotificationId!,
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _updateGameStateFromFirestore(Map<String, dynamic> gameData) {
    if (!mounted) return;

    setState(() {
      final players = (gameData['players'] as List<dynamic>).map((p) {
        // Use the same conversion logic as Lobby.fromJson
        final json = p as Map<String, dynamic>;
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
          notes: notesMap,
        );
      }).toList();

      final currentPlayerIndex = gameData['currentPlayerIndex'] as int? ?? 0;
      final diceRoll = gameData['diceRoll'] as int? ?? 0;
      final remainingSteps = gameData['remainingSteps'] as int? ?? 0;
      final gameOver = gameData['gameOver'] as bool? ?? false;
      final winner = gameData['winner'] as String?;

      // Update game state
      _gameState = _gameState.copyWith(
        players: players,
        currentPlayerIndex: currentPlayerIndex,
        diceRoll: diceRoll,
        remainingSteps: remainingSteps,
        gameOver: gameOver,
        winner: winner,
      );

      // Reset dice state if it's a new turn
      if (diceRoll == 0 && remainingSteps == 0) {
        _hasRolledDice = false;
        _selectedSquare = null;
        _validMoves = [];
      }
    });
  }

  @override
  void dispose() {
    _gameStateSubscription?.cancel();
    _notificationSubscription?.cancel();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  // Check if it's the local player's turn
  bool get _isMyTurn {
    if (!widget.isOnline || _localPlayerName == null) return true;
    final currentPlayer = _gameState.currentPlayer;
    return currentPlayer.name == _localPlayerName;
  }

  // Get the local player
  Player? get _localPlayer {
    if (_localPlayerName == null) return null;
    try {
      return _gameState.players.firstWhere((p) => p.name == _localPlayerName);
    } catch (e) {
      return null;
    }
  }

  void _updateCurrentPlayerRoom() {
    final player = _gameState.currentPlayer;
    final room = _gameState.board.getRoomAt(player.boardRow, player.boardCol);
    if (room != player.currentRoom) {
      setState(() {
        _gameState = _gameState.copyWith(
          players: _gameState.players.asMap().entries.map((entry) {
            if (entry.key == _gameState.currentPlayerIndex) {
              return entry.value.copyWith(currentRoom: room);
            }
            return entry.value;
          }).toList(),
        );
      });
    }
  }

  void _rollDice() {
    if (!_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_gameState.currentPlayer.name}\'s turn - wait for your turn',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_hasRolledDice) return;

    // Roll dice and show result immediately
    final roll = _gameState.rollDice();
    final currentPlayer = _gameState.currentPlayer;
    final currentSquare = _gameState
        .board
        .squares[currentPlayer.boardRow][currentPlayer.boardCol];
    final validMoves = _gameState.board.getValidMoves(currentSquare, roll);

    setState(() {
      _gameState = _gameState.copyWith(diceRoll: roll, remainingSteps: roll);
      _validMoves = validMoves;
      _hasRolledDice = true;
      _currentDiceValue = roll;
    });

    // Sync to Firestore in online mode
    if (widget.isOnline && widget.lobbyCode != null) {
      _syncGameStateToFirestore();
    }
  }

  void _selectSquare(BoardSquare square) {
    if (!_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_gameState.currentPlayer.name}\'s turn - wait for your turn',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_hasRolledDice || _gameState.remainingSteps == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please roll the dice first')),
      );
      return;
    }

    if (!_validMoves.contains(square)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid move! Select a highlighted square.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedSquare = square;

      // Move player
      _gameState = _gameState.copyWith(
        players: _gameState.players.asMap().entries.map((entry) {
          if (entry.key == _gameState.currentPlayerIndex) {
            final newRoom = square.room;
            return entry.value.copyWith(
              boardRow: square.row,
              boardCol: square.col,
              currentRoom: newRoom,
            );
          }
          return entry.value;
        }).toList(),
        remainingSteps: _gameState.remainingSteps - 1,
      );

      // Update valid moves for remaining steps
      if (_gameState.remainingSteps > 0) {
        _validMoves = _gameState.board.getValidMoves(
          square,
          _gameState.remainingSteps,
        );
      } else {
        _validMoves = [];
      }
    });

    // Sync to Firestore in online mode
    if (widget.isOnline && widget.lobbyCode != null) {
      final currentPlayer = _gameState.currentPlayer;
      _firebaseService.updatePlayerPosition(
        widget.lobbyCode!,
        currentPlayer.name,
        currentPlayer.boardRow,
        currentPlayer.boardCol,
        currentPlayer.currentRoom?.name,
      );
      _syncGameStateToFirestore();
    }
  }

  Future<void> _syncGameStateToFirestore() async {
    if (!widget.isOnline || widget.lobbyCode == null) return;

    _isSyncing = true;
    try {
      await _firebaseService.saveGameState(
        widget.lobbyCode!,
        _gameState.players,
        _gameState.currentPlayerIndex,
        _gameState.diceRoll,
        _gameState.remainingSteps,
        _gameState.gameOver,
        _gameState.winner,
      );
    } finally {
      _isSyncing = false;
    }
  }

  void _enterRoom() {
    if (!_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_gameState.currentPlayer.name}\'s turn - wait for your turn',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentPlayer = _gameState.currentPlayer;
    Room? room = currentPlayer.currentRoom;

    // If not in a room, check if we can enter one nearby or allow selection
    if (room == null) {
      // Check if player is adjacent to any room
      final playerSquare = _gameState
          .board
          .squares[currentPlayer.boardRow][currentPlayer.boardCol];
      final adjacentRooms = <Room>[];

      for (final roomEntry in _gameState.board.roomSquares.entries) {
        for (final roomSquare in roomEntry.value) {
          final rowDiff = (playerSquare.row - roomSquare.row).abs();
          final colDiff = (playerSquare.col - roomSquare.col).abs();
          if (rowDiff + colDiff == 1) {
            adjacentRooms.add(roomEntry.key);
            break;
          }
        }
      }

      if (adjacentRooms.isEmpty) {
        // Show dialog to select a room to enter
        _showRoomSelectionDialog();
        return;
      } else if (adjacentRooms.length == 1) {
        _openRoomView(adjacentRooms.first);
        return;
      } else {
        // Multiple rooms adjacent, show selection
        _showRoomSelectionDialog(adjacentRooms);
        return;
      }
    }

    _openRoomView(room);
  }

  void _showRoomSelectionDialog([List<Room>? availableRooms]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: (availableRooms ?? Room.values).map((room) {
              return ListTile(
                title: Text(room.name),
                onTap: () {
                  Navigator.pop(context);
                  _openRoomView(room);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openRoomView(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomViewScreen(
          gameState: _gameState,
          room: room,
          isOnline: widget.isOnline,
          lobbyCode: widget.lobbyCode,
          localPlayerName: _localPlayerName,
          onSuggestionMade: (refutedCard) {
            if (refutedCard != null &&
                refutedCard.startsWith('SUGGESTION_PENDING')) {
              // Handle pending suggestion - show dialog to asked player
              _handlePendingSuggestion(refutedCard, room);
            } else if (refutedCard == 'ONLINE_PENDING') {
              // For online games, suggestion is pending - don't end turn yet
              // The turn will end when the response is received via _handleSuggestionResponse
              // Just return without doing anything
              return;
            } else {
              setState(() {
                if (refutedCard != null) {
                  final noteKey = '${room.name}_${refutedCard}';
                  _gameState = _gameState.copyWith(
                    detectiveNotes: {
                      ..._gameState.detectiveNotes,
                      noteKey: true,
                    },
                  );
                }
              });
              _nextTurn();
            }
          },
        ),
      ),
    );
  }

  void _handlePendingSuggestion(String suggestionData, Room room) async {
    // Parse: "SUGGESTION_PENDING|askedPlayer|askerPlayer|askedItems|matchingCards|cardsYouHave"
    final parts = suggestionData.split('|');
    if (parts.length < 6) return;

    final askedPlayerName = parts[1];
    final askerPlayerName = parts[2];
    final askedItems = parts[3].isEmpty
        ? <String>[]
        : parts[3].split(',').where((s) => s.isNotEmpty).toList();
    final matchingCards = parts[4].isEmpty
        ? <String>[]
        : parts[4].split(',').where((s) => s.isNotEmpty).toList();
    final cardsYouHave = parts[5].isEmpty
        ? <String>[]
        : parts[5].split(',').where((s) => s.isNotEmpty).toList();

    // Find players
    final askedPlayer = _gameState.players.firstWhere(
      (p) => p.name == askedPlayerName,
      orElse: () => _gameState.players.first,
    );
    final askerPlayer = _gameState.players.firstWhere(
      (p) => p.name == askerPlayerName,
      orElse: () => _gameState.players.first,
    );

    // Check if current player is the asked player
    final currentPlayer = widget.isOnline && _localPlayerName != null
        ? _gameState.players.firstWhere(
            (p) => p.name == _localPlayerName,
            orElse: () => _gameState.currentPlayer,
          )
        : _gameState.currentPlayer;

    // If current player is the asked player, show selection dialog
    if (currentPlayer.name == askedPlayerName) {
      final selectedCard = await _showCardSelectionDialogToAskedPlayer(
        askedPlayer,
        askerPlayer,
        askedItems,
        matchingCards,
      );

      if (selectedCard != null && mounted) {
        // Show result to asker
        _showSuggestionResultToAsker(
          askerPlayer,
          askedPlayer,
          askedItems,
          selectedCard,
          cardsYouHave,
          room,
        );
      }
    } else {
      // Current player is not the asked player, wait for them
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Waiting'),
            content: Text('Waiting for $askedPlayerName to select a card...'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<String?> _showCardSelectionDialogToAskedPlayer(
    Player askedPlayer,
    Player askerPlayer,
    List<String> askedItems,
    List<String> matchingCards,
  ) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: askedPlayer.playerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      askedPlayer.firstLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        askedPlayer.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${askerPlayer.name} asked you about:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You have these matching cards:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...askedItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Row(
                          children: [
                            Icon(
                              matchingCards.contains(item)
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 16,
                              color: matchingCards.contains(item)
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: matchingCards.contains(item)
                                      ? Colors.green.shade900
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select which card to show to ${askerPlayer.name}:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ...matchingCards.map(
                (card) => Card(
                  color: Colors.grey.shade50,
                  child: ListTile(
                    title: Text(
                      card,
                      style: const TextStyle(fontWeight: FontWeight.normal),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(dialogContext, card);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, null);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSuggestionResultToAsker(
    Player askerPlayer,
    Player askedPlayer,
    List<String> askedItems,
    String selectedCard,
    List<String> cardsYouHave,
    Room room,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Suggestion Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You asked ${askedPlayer.name} about:'),
            const SizedBox(height: 8),
            ...askedItems.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  item,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                children: [
                  Text(
                    '${askedPlayer.name} showed you:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedCard,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            if (cardsYouHave.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Warning: You have this card:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...cardsYouHave.map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(left: 32, top: 4),
                        child: Text(
                          '• $card',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                final noteKey = '${room.name}_$selectedCard';
                _gameState = _gameState.copyWith(
                  detectiveNotes: {..._gameState.detectiveNotes, noteKey: true},
                );
              });
              _nextTurn();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _passTurn() {
    if (!_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_gameState.currentPlayer.name}\'s turn - wait for your turn',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_hasRolledDice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please roll the dice first')),
      );
      return;
    }
    _nextTurn();
  }

  void _nextTurn() {
    setState(() {
      int nextIndex =
          (_gameState.currentPlayerIndex + 1) % _gameState.players.length;
      while (_gameState.players[nextIndex].isOutOfGame &&
          nextIndex != _gameState.currentPlayerIndex) {
        nextIndex = (nextIndex + 1) % _gameState.players.length;
      }

      _gameState = _gameState.copyWith(
        currentPlayerIndex: nextIndex,
        diceRoll: 0,
        remainingSteps: 0,
      );
      _hasRolledDice = false;
      _selectedSquare = null;
      _validMoves = [];
      _updateCurrentPlayerRoom();
    });

    // Sync to Firestore in online mode
    if (widget.isOnline && widget.lobbyCode != null) {
      _firebaseService.updateCurrentPlayer(
        widget.lobbyCode!,
        _gameState.currentPlayerIndex,
      );
    }
  }

  void _makeAccusation() {
    if (!_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_gameState.currentPlayer.name}\'s turn - wait for your turn',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentPlayer = _gameState.currentPlayer;

    // Check if player is in a room
    if (currentPlayer.currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be in a room to make an accusation!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AccusationDialog(
        gameState: _gameState,
        initialRoom: currentPlayer.currentRoom!.name,
        onAccusation: (suspect, weapon, room) {
          final isCorrect = _gameState.checkAccusation(suspect, weapon, room);
          Navigator.pop(context);

          if (isCorrect) {
            _gameState = _gameState.copyWith(
              gameOver: true,
              winner: _gameState.currentPlayer.name,
            );
            _showGameOverDialog();
          } else {
            setState(() {
              _gameState = _gameState.copyWith(
                players: _gameState.players.asMap().entries.map((entry) {
                  if (entry.key == _gameState.currentPlayerIndex) {
                    return entry.value.copyWith(isOutOfGame: true);
                  }
                  return entry.value;
                }).toList(),
              );
            });
            _nextTurn();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Wrong accusation! You are out of the game.'),
                backgroundColor: Colors.red,
              ),
            );
          }

          // Sync to Firestore in online mode
          if (widget.isOnline && widget.lobbyCode != null) {
            _syncGameStateToFirestore();
          }
        },
      ),
    );
  }

  Widget _buildDiceWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 140),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Dice Roll',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              '${_gameState.diceRoll}',
              key: ValueKey<int>(_gameState.diceRoll),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          if (_gameState.remainingSteps > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_gameState.remainingSteps} steps left',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRollDiceButton() {
    return ElevatedButton.icon(
      onPressed: _rollDice,
      icon: const Icon(Icons.casino),
      label: const Text('Roll'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_gameState.winner} wins!'),
            const SizedBox(height: 16),
            const Text('The murder was committed by:'),
            Text(
              _gameState.murderer ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('With:'),
            Text(
              _gameState.murderWeapon ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('In:'),
            Text(
              _gameState.murderRoom ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(Player player, bool isMyTurn) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer header with player info
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  player.playerColor,
                  player.playerColor.withOpacity(0.7),
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: player.playerColor,
                      child: Text(
                        player.firstLetter,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.isOnline ? 'Online Mode' : 'Offline Mode',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  if (widget.isOnline && !isMyTurn)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Waiting for turn',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Profile section
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            subtitle: const Text('View your player profile'),
            onTap: () {
              Navigator.pop(context);
              _showProfile(player);
            },
          ),

          const Divider(),

          // Game Status / Results
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: const Text('Game Results'),
            subtitle: const Text('View game status and results'),
            onTap: () {
              Navigator.pop(context);
              _showGameResults();
            },
          ),

          // Tips
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('Tips'),
            subtitle: const Text('Gameplay tips and strategies'),
            onTap: () {
              Navigator.pop(context);
              _showTips();
            },
          ),

          // Instructions
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Instructions'),
            subtitle: const Text('How to play the game'),
            onTap: () {
              Navigator.pop(context);
              _showInstructions();
            },
          ),

          const Divider(),

          // Game Settings (if applicable)
          if (widget.isOnline && widget.lobbyCode != null)
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Lobby Info'),
              subtitle: Text('Code: ${widget.lobbyCode}'),
              onTap: () {
                Navigator.pop(context);
                _showLobbyInfo();
              },
            ),

          // Current Turn Info
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Current Turn'),
            subtitle: Text('${_gameState.currentPlayer.name}\'s turn'),
            onTap: () {
              Navigator.pop(context);
              _showGameResults();
            },
          ),

          const Divider(),

          // Exit
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Exit Game', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Leave the current game'),
            onTap: () {
              Navigator.pop(context);
              _showExitConfirmation();
            },
          ),
        ],
      ),
    );
  }

  void _showProfile(Player player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Player Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: player.playerColor,
                  child: Text(
                    player.firstLetter,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildProfileRow('Name', player.name),
              _buildProfileRow('Color', player.playerColor.toString()),
              _buildProfileRow(
                'Clue Cards',
                '${player.clueCards.length} cards',
              ),
              _buildProfileRow(
                'Position',
                'Row: ${player.boardRow}, Col: ${player.boardCol}',
              ),
              if (player.currentRoom != null)
                _buildProfileRow('Current Room', player.currentRoom!.name),
              _buildProfileRow(
                'Status',
                player.isOutOfGame ? 'Out of Game' : 'In Game',
              ),
              if (player.isComputer)
                _buildProfileRow('Type', 'Computer Player'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showGameResults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Status'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Players status
              const Text(
                'Players:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._gameState.players.map((player) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: player.playerColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            player.firstLetter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(player.name)),
                      if (player.isOutOfGame)
                        const Chip(
                          label: Text('Out'),
                          backgroundColor: Colors.red,
                          labelStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        )
                      else if (player.name == _gameState.currentPlayer.name)
                        const Chip(
                          label: Text('Current'),
                          backgroundColor: Colors.green,
                          labelStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              // Game info
              if (_gameState.gameOver) ...[
                const Divider(),
                const Text(
                  'Game Over!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Winner: ${_gameState.winner ?? "Unknown"}'),
                const SizedBox(height: 8),
                const Text('Solution:'),
                Text('  Suspect: ${_gameState.murderer ?? "Unknown"}'),
                Text('  Weapon: ${_gameState.murderWeapon ?? "Unknown"}'),
                Text('  Room: ${_gameState.murderRoom ?? "Unknown"}'),
              ] else ...[
                const Divider(),
                const Text(
                  'Game Info:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Current Turn: ${_gameState.currentPlayer.name}'),
                Text(
                  'Dice Roll: ${_gameState.diceRoll > 0 ? _gameState.diceRoll : "Not rolled"}',
                ),
                if (_gameState.remainingSteps > 0)
                  Text('Remaining Steps: ${_gameState.remainingSteps}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Tips'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTipItem(
                Icons.lightbulb,
                'Make Suggestions',
                'Use suggestions to eliminate possibilities. Ask about combinations you suspect.',
              ),
              _buildTipItem(
                Icons.note,
                'Take Notes',
                'Keep track of what cards players show you. This helps narrow down the solution.',
              ),
              _buildTipItem(
                Icons.door_front_door,
                'Enter Rooms',
                'You must be in a room to make suggestions. Plan your moves carefully.',
              ),
              _buildTipItem(
                Icons.gavel,
                'Make Accusations',
                'Only accuse when you\'re certain! Wrong accusations eliminate you from the game.',
              ),
              _buildTipItem(
                Icons.credit_card,
                'Manage Cards',
                'Keep track of your clue cards. They tell you what\'s NOT in the solution.',
              ),
              _buildTipItem(
                Icons.group,
                'Watch Other Players',
                'Observe what other players ask about. This gives clues about what they know.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Objective:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Be the first to correctly identify the murderer, weapon, and room.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Gameplay:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInstructionStep('1', 'Roll the dice and move your token'),
              _buildInstructionStep('2', 'Enter a room to make suggestions'),
              _buildInstructionStep(
                '3',
                'Ask other players about suspect/weapon/room combinations',
              ),
              _buildInstructionStep(
                '4',
                'Players with matching cards show you ONE card',
              ),
              _buildInstructionStep('5', 'Use notes to track what you learn'),
              _buildInstructionStep('6', 'When confident, make an accusation'),
              const SizedBox(height: 16),
              const Text(
                'Important:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                '• Wrong accusations eliminate you from the game\n'
                '• Only the current player can make moves\n'
                '• Suggestions help eliminate possibilities\n'
                '• Keep track of what cards are shown to you',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showLobbyInfo() {
    if (!widget.isOnline || widget.lobbyCode == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lobby Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lobby Code:'),
            Text(
              widget.lobbyCode!,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Share this code with other players to join the game.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Game?'),
        content: const Text(
          'Are you sure you want to exit the current game? All progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (widget.isOnline &&
                  widget.lobbyCode != null &&
                  _localPlayerName != null) {
                // Leave lobby in online mode
                _firebaseService.leaveLobby(
                  widget.lobbyCode!,
                  _localPlayerName!,
                );
              }
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayer = _gameState.currentPlayer;
    final localPlayer = _localPlayer;
    final isMyTurn = _isMyTurn;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // User name in white bordered circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isOnline && localPlayer != null
                    ? localPlayer.playerColor
                    : currentPlayer.playerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  widget.isOnline && localPlayer != null
                      ? localPlayer.firstLetter
                      : currentPlayer.firstLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: widget.isOnline && localPlayer != null
            ? localPlayer.playerColor
            : currentPlayer.playerColor,
        actions: [
          // Whose turn in right corner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '${currentPlayer.name}\'s Turn',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(localPlayer ?? currentPlayer, isMyTurn),
      body: SafeArea(
        child: IndexedStack(
          index: _bottomNavIndex,
          children: [
            GameStatusView(gameState: _gameState),
            _buildCluesView(localPlayer ?? currentPlayer),
            BoardTab(
              gameState: _gameState,
              isMyTurn: isMyTurn,
              isOnline: widget.isOnline,
              hasRolledDice: _hasRolledDice,
              validMoves: _validMoves,
              selectedSquare: _selectedSquare,
              verticalScrollController: _verticalScrollController,
              horizontalScrollController: _horizontalScrollController,
              onEnterRoom: _enterRoom,
              onRollDice: _rollDice,
              onPassTurn: _passTurn,
              onSquareTap: _selectSquare,
            ),
            _buildNotesView(localPlayer ?? currentPlayer),
            _buildAccuseView(isMyTurn, localPlayer, currentPlayer),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: _bottomNavIcons.length,
        tabBuilder: (int index, bool isActive) {
          final color = isActive
              ? (widget.isOnline && localPlayer != null
                    ? localPlayer.playerColor
                    : currentPlayer.playerColor)
              : Colors.grey;
          return Icon(_bottomNavIcons[index], size: 24, color: color);
        },
        activeIndex: _bottomNavIndex,
        gapLocation: GapLocation.none,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        leftCornerRadius: 0,
        rightCornerRadius: 0,
        onTap: (index) =>
            _handleBottomNavTap(index, isMyTurn, localPlayer, currentPlayer),
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }

  void _handleBottomNavTap(
    int index,
    bool isMyTurn,
    Player? localPlayer,
    Player currentPlayer,
  ) {
    setState(() {
      _bottomNavIndex = index;
    });

    // All views are handled by IndexedStack - no action needed
  }

  // Build Clues View
  Widget _buildCluesView(Player player) {
    return ClueCardsScreen(player: player);
  }

  // Build Notes View
  Widget _buildNotesView(Player player) {
    return NotesScreen(
      gameState: _gameState,
      player: player,
      onNotesUpdated: (updatedPlayer) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              final updatedPlayers = _gameState.players.map((p) {
                return p.name == updatedPlayer.name ? updatedPlayer : p;
              }).toList();
              _gameState = _gameState.copyWith(players: updatedPlayers);
            });
          }
        });
      },
    );
  }

  // Build Accuse View
  Widget _buildAccuseView(
    bool isMyTurn,
    Player? localPlayer,
    Player currentPlayer,
  ) {
    // Initialize room if not set
    if (_selectedRoom == null) {
      _selectedRoom = currentPlayer.currentRoom?.name;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMyTurn && widget.isOnline)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wait for your turn to make an accusation',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            'Select the suspect:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedSuspect,
            isExpanded: true,
            items:
                const [
                  'Alex Hunter',
                  'Blake Rivers',
                  'Casey Knight',
                  'Jordan Steele',
                  'Riley Cross',
                  'Taylor Frost',
                ].map((suspect) {
                  return DropdownMenuItem(value: suspect, child: Text(suspect));
                }).toList(),
            onChanged: (isMyTurn || !widget.isOnline)
                ? (value) {
                    setState(() {
                      _selectedSuspect = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 24),
          const Text(
            'Select the weapon:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedWeapon,
            isExpanded: true,
            items:
                const [
                  'Dagger',
                  'Candlestick',
                  'Revolver',
                  'Rope',
                  'Lead Piping',
                  'Spanner',
                ].map((weapon) {
                  return DropdownMenuItem(value: weapon, child: Text(weapon));
                }).toList(),
            onChanged: (isMyTurn || !widget.isOnline)
                ? (value) {
                    setState(() {
                      _selectedWeapon = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 24),
          const Text(
            'Select the room:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedRoom,
            isExpanded: true,
            items:
                const [
                  'Grand Hall',
                  'Sky Lounge',
                  'Banquet Hall',
                  'Chef Kitchen',
                  'Secret Basement',
                  'Rooftop Pool',
                  'Hidden Garden',
                  'Silent Library',
                  'Private Study',
                ].map((room) {
                  return DropdownMenuItem(value: room, child: Text(room));
                }).toList(),
            onChanged: (isMyTurn || !widget.isOnline)
                ? (value) {
                    setState(() {
                      _selectedRoom = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (isMyTurn || !widget.isOnline) &&
                      _selectedSuspect != null &&
                      _selectedWeapon != null &&
                      _selectedRoom != null
                  ? () {
                      final isCorrect = _gameState.checkAccusation(
                        _selectedSuspect!,
                        _selectedWeapon!,
                        _selectedRoom!,
                      );

                      if (isCorrect) {
                        _gameState = _gameState.copyWith(
                          gameOver: true,
                          winner: _gameState.currentPlayer.name,
                        );
                        _showGameOverDialog();
                      } else {
                        setState(() {
                          _gameState = _gameState.copyWith(
                            players: _gameState.players.asMap().entries.map((
                              entry,
                            ) {
                              if (entry.key == _gameState.currentPlayerIndex) {
                                return entry.value.copyWith(isOutOfGame: true);
                              }
                              return entry.value;
                            }).toList(),
                          );
                        });
                        _nextTurn();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Wrong accusation! You are out of the game.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }

                      // Sync to Firestore in online mode
                      if (widget.isOnline && widget.lobbyCode != null) {
                        _syncGameStateToFirestore();
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Make Accusation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _AccusationDialog extends StatefulWidget {
  final GameState gameState;
  final Function(String suspect, String weapon, String room) onAccusation;
  final String? initialRoom;

  const _AccusationDialog({
    required this.gameState,
    required this.onAccusation,
    this.initialRoom,
  });

  @override
  State<_AccusationDialog> createState() => _AccusationDialogState();
}

class _AccusationDialogState extends State<_AccusationDialog> {
  String? _selectedSuspect;
  String? _selectedWeapon;
  String? _selectedRoom;

  @override
  void initState() {
    super.initState();
    // Pre-select the room if provided
    if (widget.initialRoom != null) {
      _selectedRoom = widget.initialRoom;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Make Accusation'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select the suspect:'),
          DropdownButton<String>(
              value: _selectedSuspect,
              isExpanded: true,
              items:
                  const [
                    'Alex Hunter',
                    'Blake Rivers',
                    'Casey Knight',
                    'Jordan Steele',
                    'Riley Cross',
                    'Taylor Frost',
                  ].map((suspect) {
                    return DropdownMenuItem(
                      value: suspect,
                      child: Text(suspect),
                    );
                  }).toList(),
              onChanged: (value) => setState(() => _selectedSuspect = value),
            ),
            const SizedBox(height: 16),
            const Text('Select the weapon:'),
            DropdownButton<String>(
              value: _selectedWeapon,
              isExpanded: true,
              items:
                  const [
                    'Dagger',
                    'Candlestick',
                    'Revolver',
                    'Rope',
                    'Lead Piping',
                    'Spanner',
                  ].map((weapon) {
                    return DropdownMenuItem(value: weapon, child: Text(weapon));
                  }).toList(),
              onChanged: (value) => setState(() => _selectedWeapon = value),
            ),
            const SizedBox(height: 16),
            const Text('Select the room:'),
          DropdownButton<String>(
              value: _selectedRoom,
              isExpanded: true,
              items:
                  const [
                    'Grand Hall',
                    'Sky Lounge',
                    'Banquet Hall',
                    'Chef Kitchen',
                    'Secret Basement',
                    'Rooftop Pool',
                    'Hidden Garden',
                    'Silent Library',
                    'Private Study',
                  ].map((room) {
                    return DropdownMenuItem(value: room, child: Text(room));
                  }).toList(),
              onChanged: (value) => setState(() => _selectedRoom = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _selectedSuspect != null &&
                  _selectedWeapon != null &&
                  _selectedRoom != null
              ? () {
                  widget.onAccusation(
                    _selectedSuspect!,
                    _selectedWeapon!,
                    _selectedRoom!,
                  );
                }
              : null,
          child: const Text('Accuse'),
        ),
      ],
    );
  }
}
