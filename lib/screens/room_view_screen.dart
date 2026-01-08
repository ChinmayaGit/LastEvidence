import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../services/firebase_service.dart';

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
    // Get available players (excluding current player and out of game players)
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
          // Current player info
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
          // Result button
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'View Game Results',
            onPressed: _showGameResults,
          ),
          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: _showHelp,
          ),
          // Exit button
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

              // Player selection
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

              // Room checkbox
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
                            // If room is selected and we have 2 items, clear others
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

              // Suspect dropdown
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
                        'Colonel Mustard',
                        'Professor Plum',
                        'Reverend Green',
                        'Mrs Peacock',
                        'Miss Scarlett',
                        'Mrs White',
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
                                // If we have 2 items and room is not selected, clear weapon
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

              // Weapon dropdown
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
                                // If we have 2 items and room is not selected, clear suspect
                                _selectedSuspect = null;
                              }
                              _selectedWeapon = value;
                            });
                          }
                        : null,
                  ),
                ),
              ),

              // Status indicator
              if (_selectedPlayer != null && _selectedCount == 2) ...[
                const SizedBox(height: 24),
                _buildStatusIndicator(),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    _selectedPlayer != null &&
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit room
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
              // Players status
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
              // Game info
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
                'Status Indicator:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Green = Player has at least one matching card',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Red = Player does not have any matching cards',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Note:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'If the asked player has matching cards, they will show you ONE random card. Other players will be notified that a card was shown, but won\'t know which card.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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

  Widget _buildStatusIndicator() {
    if (_selectedPlayer == null) return const SizedBox.shrink();

    final currentPlayer = widget.gameState.currentPlayer;

    // Check what cards are being asked about
    final askedItems = <String>[];
    if (_includeRoom) askedItems.add(widget.room.name);
    if (_selectedSuspect != null) askedItems.add(_selectedSuspect!);
    if (_selectedWeapon != null) askedItems.add(_selectedWeapon!);

    // Find which specific cards the current player has
    final cardsYouHave = askedItems
        .where((item) => currentPlayer.clueCards.contains(item))
        .toList();

    // Only show indicator if current player has a card (warning)
    if (cardsYouHave.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warning: You have this card:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...cardsYouHave.map(
                    (card) => Padding(
                      padding: const EdgeInsets.only(top: 4),
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
        ),
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

    // Build the list of asked items
    final askedItems = <String>[];
    if (_includeRoom) askedItems.add(widget.room.name);
    if (_selectedSuspect != null) askedItems.add(_selectedSuspect!);
    if (_selectedWeapon != null) askedItems.add(_selectedWeapon!);

    // Check if asked player has any of the cards
    final matchingCards = askedItems
        .where((item) => askedPlayer.clueCards.contains(item))
        .toList();

    // Find which specific cards the current player (asker) has - only for warning
    final cardsYouHave = askedItems
        .where((item) => currentPlayer.clueCards.contains(item))
        .toList();

    // If asked player has no cards, just end the turn silently
    // (No message - if they don't have it, it could be part of the solution)
    if (matchingCards.isEmpty) {
      setState(() {
        _isProcessing = false;
      });
      widget.onSuggestionMade(null);
      Navigator.pop(context);
      return;
    }

    // Close the suggestion screen
    Navigator.pop(context);

    if (!mounted) return;

    // For online mode: Send suggestion request to asked player
    if (widget.isOnline &&
        widget.lobbyCode != null &&
        widget.localPlayerName != null) {
      // Send request to Firebase
      await _firebaseService.sendSuggestionRequest(
        widget.lobbyCode!,
        currentPlayer.name,
        askedPlayer.name,
        askedItems,
        matchingCards,
        cardsYouHave,
      );

      // Show waiting message to asker
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
                // Pass suggestion data for local handling
                widget.onSuggestionMade('ONLINE_PENDING');
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // For local games: Pass suggestion data through callback
      final suggestionData =
          'SUGGESTION_PENDING|${askedPlayer.name}|${currentPlayer.name}|${askedItems.join('|')}|${matchingCards.join('|')}|${cardsYouHave.join('|')}';

      // Show waiting message to asker
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

  Future<String?> _showCardSelectionDialog(
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
                      // Immediately confirm selection when card is tapped
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
}
