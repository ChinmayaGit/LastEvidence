import 'package:flutter/material.dart';

import '../../models/game_state.dart';

class AccusationDialog extends StatefulWidget {
  final GameState gameState;
  final Function(String suspect, String weapon, String room) onAccusation;
  final String? initialRoom;

  const AccusationDialog({
    super.key,
    required this.gameState,
    required this.onAccusation,
    this.initialRoom,
  });

  @override
  State<AccusationDialog> createState() => _AccusationDialogState();
}

class _AccusationDialogState extends State<AccusationDialog> {
  String? _selectedSuspect;
  String? _selectedWeapon;
  String? _selectedRoom;

  @override
  void initState() {
    super.initState();
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
              items: const [
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
              items: const [
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
              items: const [
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
          onPressed: _selectedSuspect != null &&
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
