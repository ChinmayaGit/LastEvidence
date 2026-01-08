import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/suspect.dart';
import '../models/weapon.dart';
import '../models/room.dart';

class NotesScreen extends StatefulWidget {
  final GameState gameState;
  final Player player;
  final Function(Player) onNotesUpdated;

  const NotesScreen({
    super.key,
    required this.gameState,
    required this.player,
    required this.onNotesUpdated,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  Map<String, NoteState> _notes = {};

  @override
  void initState() {
    super.initState();
    // Load notes from player, or initialize empty
    try {
      if (widget.player.notes.isNotEmpty) {
        _notes = Map<String, NoteState>.from(widget.player.notes);
      } else {
        _notes = <String, NoteState>{};
      }
    } catch (e) {
      // If there's any issue loading notes, start with empty map
      _notes = <String, NoteState>{};
    }
    
    // Initialize notes for all suspects, weapons, and rooms if not present
    for (final suspect in Suspect.values) {
      _notes.putIfAbsent('suspect_${suspect.name}', () => NoteState.none);
    }
    for (final weapon in Weapon.values) {
      _notes.putIfAbsent('weapon_${weapon.name}', () => NoteState.none);
    }
    for (final room in Room.values) {
      _notes.putIfAbsent('room_${room.name}', () => NoteState.none);
    }
  }

  void _setNoteState(String key, NoteState state) {
    setState(() {
      if (_notes[key] == state) {
        _notes[key] = NoteState.none; // Clear if clicking same state
      } else {
        _notes[key] = state;
      }
    });
    
    // Update player's notes and notify parent (outside setState to avoid nested setState)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final updatedPlayer = widget.player.copyWith(
          notes: Map<String, NoteState>.from(_notes),
        );
        widget.onNotesUpdated(updatedPlayer);
      }
    });
  }
  
  void _saveNotes() {
    if (mounted) {
      final updatedPlayer = widget.player.copyWith(
        notes: Map<String, NoteState>.from(_notes),
      );
      widget.onNotesUpdated(updatedPlayer);
    }
  }
  
  @override
  void dispose() {
    // Save notes one final time when leaving the screen
    _saveNotes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Color Legend:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LegendItem(
                      color: Colors.grey.shade400,
                      label: 'Grey - Asked someone and they have it',
                      icon: Icons.check_circle,
                    ),
                    _LegendItem(
                      color: Colors.blue.shade300,
                      label: 'Blue - Might be the answer',
                      icon: Icons.help_outline,
                    ),
                    _LegendItem(
                      color: Colors.green.shade400,
                      label: 'Green - Think it\'s the answer',
                      icon: Icons.star,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Suspects:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...Suspect.values
                .where(
                  (suspect) => !widget.player.clueCards.contains(suspect.name),
                )
                .map((suspect) {
              final key = 'suspect_${suspect.name}';
              return _NoteItem(
                label: suspect.name,
                noteState: _notes[key] ?? NoteState.none,
                    onGreyTap: () =>
                        _setNoteState(key, NoteState.askedAndHasIt),
                    onBlueTap: () =>
                        _setNoteState(key, NoteState.mightBeAnswer),
                onGreenTap: () => _setNoteState(key, NoteState.isAnswer),
              );
            }),
            const SizedBox(height: 24),
            const Text(
              'Weapons:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...Weapon.values
                .where(
                  (weapon) => !widget.player.clueCards.contains(weapon.name),
                )
                .map((weapon) {
              final key = 'weapon_${weapon.name}';
              return _NoteItem(
                label: weapon.name,
                noteState: _notes[key] ?? NoteState.none,
                    onGreyTap: () =>
                        _setNoteState(key, NoteState.askedAndHasIt),
                    onBlueTap: () =>
                        _setNoteState(key, NoteState.mightBeAnswer),
                onGreenTap: () => _setNoteState(key, NoteState.isAnswer),
              );
            }),
            const SizedBox(height: 24),
            const Text(
              'Rooms:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...Room.values
                .where((room) => !widget.player.clueCards.contains(room.name))
                .map((room) {
              final key = 'room_${room.name}';
              return _NoteItem(
                label: room.name,
                noteState: _notes[key] ?? NoteState.none,
                    onGreyTap: () =>
                        _setNoteState(key, NoteState.askedAndHasIt),
                    onBlueTap: () =>
                        _setNoteState(key, NoteState.mightBeAnswer),
                onGreenTap: () => _setNoteState(key, NoteState.isAnswer),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  final String label;
  final NoteState noteState;
  final VoidCallback onGreyTap;
  final VoidCallback onBlueTap;
  final VoidCallback onGreenTap;

  const _NoteItem({
    required this.label,
    required this.noteState,
    required this.onGreyTap,
    required this.onBlueTap,
    required this.onGreenTap,
  });

  Color? _getBackgroundColor() {
    switch (noteState) {
      case NoteState.askedAndHasIt:
        return Colors.grey.shade400;
      case NoteState.mightBeAnswer:
        return Colors.blue.shade300;
      case NoteState.isAnswer:
        return Colors.green.shade400;
      case NoteState.none:
        return null;
    }
  }

  IconData? _getIcon() {
    switch (noteState) {
      case NoteState.askedAndHasIt:
        return Icons.check_circle;
      case NoteState.mightBeAnswer:
        return Icons.help_outline;
      case NoteState.isAnswer:
        return Icons.star;
      case NoteState.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();
    final icon = _getIcon();

    return Card(
      color: backgroundColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: backgroundColor != null ? Colors.white : null,
                ),
              ),
            ),
            if (icon != null) Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            // Color buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 _ColorButton(
                   color: Colors.grey.shade400,
                   icon: Icons.check_circle,
                   isSelected: noteState == NoteState.askedAndHasIt,
                   onTap: onGreyTap,
                   tooltip: 'Asked someone and they have it',
                 ),
                const SizedBox(width: 4),
                _ColorButton(
                  color: Colors.blue.shade300,
                  icon: Icons.help_outline,
                  isSelected: noteState == NoteState.mightBeAnswer,
                  onTap: onBlueTap,
                  tooltip: 'Might be the answer',
                ),
                const SizedBox(width: 4),
                _ColorButton(
                  color: Colors.green.shade400,
                  icon: Icons.star,
                  isSelected: noteState == NoteState.isAnswer,
                  onTap: onGreenTap,
                  tooltip: 'Think it\'s the answer',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  const _ColorButton({
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: isSelected ? 3 : 0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
