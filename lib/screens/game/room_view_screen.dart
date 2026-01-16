import 'package:flutter/material.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../../services/firebase_service.dart';

class RoomViewScreen extends StatefulWidget {
  final GameState gameState;
  final Room room;
  final Function(String?) onSuggestionMade;
  final bool isOnline;
  final String? lobbyCode;
  final String? localPlayerName;

  const RoomViewScreen({
    super.key,
    required this.gameState,
    required this.room,
    required this.onSuggestionMade,
    this.isOnline = false,
    this.lobbyCode,
    this.localPlayerName,
  });

  @override
  State<RoomViewScreen> createState() => _RoomViewScreenState();
}

class _RoomViewScreenState extends State<RoomViewScreen> {
  String? _selectedPlayer;
  String? _selectedSuspect;
  String? _selectedWeapon;
  bool _includeRoom = false;
  bool _isProcessing = false;
  final FirebaseService _firebaseService = FirebaseService();

  int get _selectedCount {
    int count = 0;
    if (_includeRoom) count++;
    if (_selectedSuspect != null) count++;
    if (_selectedWeapon != null) count++;
    return count;
  }

  bool get _canSelectMore => _selectedCount < 2;

  @override
  Widget build(BuildContext context) {
    final availablePlayers = widget.gameState.players
        .where(
          (p) =>
              p.name != widget.gameState.currentPlayer.name && !p.isOutOfGame,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.room.name} - Make Suggestion'),
        backgroundColor: Colors.brown,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.gameState.currentPlayer.playerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        widget.gameState.currentPlayer.firstLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.gameState.currentPlayer.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'View Game Results',
            onPressed: _showGameResults,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: _showHelp,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit Room',
            onPressed: _exitRoom,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'You are in:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.room.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.room.secretPassage != null) ...[
                        const SizedBox(height: 16),
                        const Text('Secret Passage to:'),
                        Text(
                          widget.room.secretPassage!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Make a Suggestion:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Select a player to ask:'),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedPlayer,
                isExpanded: true,
                items: availablePlayers.map((player) {
                  return DropdownMenuItem(
                    value: player.name,
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
                        Text(player.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlayer = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Select 2 things to ask about:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Card(
                color: _includeRoom ? Colors.green.shade50 : null,
                child: CheckboxListTile(
                  title: const Text('Room'),
                  subtitle: Text(
                    widget.room.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade700,
                    ),
                  ),
                  value: _includeRoom,
                  onChanged: _canSelectMore || _includeRoom
                      ? (value) {
                          setState(() {
                            _includeRoom = value ?? false;
                            if (_includeRoom && _selectedCount > 2) {
                              if (_selectedSuspect != null &&
                                  _selectedWeapon != null) {
                                _selectedWeapon = null;
                              }
                            }
                          });
                        }
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: _selectedSuspect != null ? Colors.blue.shade50 : null,
                child: ListTile(
                  title: const Text('Suspect'),
                  trailing: DropdownButton<String?>(
                    value: _selectedSuspect,
                    hint: const Text('Select'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None (Deselect)'),
                      ),
                      ...const [
                        'Alex Hunter',
                        'Blake Rivers',
                        'Casey Knight',
                        'Jordan Steele',
                        'Riley Cross',
                        'Taylor Frost',
                      ].map((suspect) {
                        return DropdownMenuItem<String?>(
                          value: suspect,
                          child: Text(suspect),
                        );
                      }).toList(),
                    ],
                    onChanged: _canSelectMore || _selectedSuspect != null
                        ? (value) {
                            setState(() {
                              if (value != null &&
                                  _selectedCount >= 2 &&
                                  !_includeRoom) {
                                _selectedWeapon = null;
                              }
                              _selectedSuspect = value;
                            });
                          }
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: _selectedWeapon != null ? Colors.red.shade50 : null,
                child: ListTile(
                  title: const Text('Weapon'),
                  trailing: DropdownButton<String?>(
                    value: _selectedWeapon,
                    hint: const Text('Select'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None (Deselect)'),
                      ),
                      ...const [
                        'Dagger',
                        'Candlestick',
                        'Revolver',
                        'Rope',
                        'Lead Piping',
                        'Spanner',
                      ].map((weapon) {
                        return DropdownMenuItem<String?>(
                          value: weapon,
                          child: Text(weapon),
                        );
                      }).toList(),
                    ],
                    onChanged: _canSelectMore || _selectedWeapon != null
                        ? (value) {
                            setState(() {
                              if (value != null &&
                                  _selectedCount >= 2 &&
                                  !_includeRoom) {
                                _selectedSuspect = null;
                              }
                              _selectedWeapon = value;
                            });
                          }
                        : null,
                  ),
                ),
              ),
              if (_selectedCount > 0) ...[
                const SizedBox(height: 24),
                _buildSelfCardWarning(),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _selectedPlayer != null &&
                        _selectedCount == 2 &&
                        !_isProcessing
                    ? _makeSuggestion
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Make Suggestion',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exitRoom() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Room?'),
        content: const Text(
          'Are you sure you want to exit without making a suggestion?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
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
              const Text(
                'Players:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...widget.gameState.players.map((player) {
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
                      else if (player.name ==
                          widget.gameState.currentPlayer.name)
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
              if (widget.gameState.gameOver) ...[
                const Divider(),
                const Text(
                  'Game Over!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Winner: ${widget.gameState.winner ?? "Unknown"}'),
                const SizedBox(height: 8),
                const Text('Solution:'),
                Text('  Suspect: ${widget.gameState.murderer ?? "Unknown"}'),
                Text('  Weapon: ${widget.gameState.murderWeapon ?? "Unknown"}'),
                Text('  Room: ${widget.gameState.murderRoom ?? "Unknown"}'),
              ] else ...[
                const Divider(),
                const Text(
                  'Game Info:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Current Turn: ${widget.gameState.currentPlayer.name}'),
                Text(
                  'Dice Roll: ${widget.gameState.diceRoll > 0 ? widget.gameState.diceRoll : "Not rolled"}',
                ),
                if (widget.gameState.remainingSteps > 0)
                  Text('Remaining Steps: ${widget.gameState.remainingSteps}'),
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

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Make a Suggestion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Select a player to ask'),
              const Text('2. Select exactly 2 items:'),
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('   • Room (checkbox) + Suspect OR'),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('   • Room (checkbox) + Weapon OR'),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('   • Suspect + Weapon'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Warnings:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You will see a warning if you select a card you have.',
                    ),
                  ),
                ],
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

  Widget _buildSelfCardWarning() {
    final currentPlayer = widget.gameState.currentPlayer;

    final askedItems = <String>[];
    if (_includeRoom) askedItems.add(widget.room.name);
    if (_selectedSuspect != null) askedItems.add(_selectedSuspect!);
    if (_selectedWeapon != null) askedItems.add(_selectedWeapon!);

    final cardsYouHave = askedItems
        .where((item) => currentPlayer.clueCards.contains(item))
        .toList();

    if (cardsYouHave.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Warning: you have at least one of these cards.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _makeSuggestion() async {
    if (_selectedPlayer == null || _selectedCount != 2) return;

    setState(() {
      _isProcessing = true;
    });

    final askedPlayer = widget.gameState.players.firstWhere(
      (p) => p.name == _selectedPlayer,
    );
    final currentPlayer = widget.gameState.currentPlayer;

    final askedItems = <String>[];
    if (_includeRoom) askedItems.add(widget.room.name);
    if (_selectedSuspect != null) askedItems.add(_selectedSuspect!);
    if (_selectedWeapon != null) askedItems.add(_selectedWeapon!);

    final matchingCards = askedItems
        .where((item) => askedPlayer.clueCards.contains(item))
        .toList();

    final cardsYouHave = askedItems
        .where((item) => currentPlayer.clueCards.contains(item))
        .toList();

    if (matchingCards.isEmpty) {
      setState(() {
        _isProcessing = false;
      });
      widget.onSuggestionMade(null);
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context);

    if (!mounted) return;

    if (widget.isOnline &&
        widget.lobbyCode != null &&
        widget.localPlayerName != null) {
      await _firebaseService.sendSuggestionRequest(
        widget.lobbyCode!,
        currentPlayer.name,
        askedPlayer.name,
        askedItems,
        matchingCards,
        cardsYouHave,
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Waiting for Response'),
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
              Text(
                'Waiting for ${askedPlayer.name} to select a card...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onSuggestionMade('ONLINE_PENDING');
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      final suggestionData =
          'SUGGESTION_PENDING|${askedPlayer.name}|${currentPlayer.name}|${askedItems.join('|')}|${matchingCards.join('|')}|${cardsYouHave.join('|')}';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Waiting for Response'),
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
              Text(
                'Please hand the device to ${askedPlayer.name} to select a card.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onSuggestionMade(suggestionData);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    setState(() {
      _isProcessing = false;
    });
  }
}

