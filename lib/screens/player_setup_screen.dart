import 'package:flutter/material.dart';
import '../models/player.dart';

class PlayerSetupScreen extends StatefulWidget {
  const PlayerSetupScreen({super.key});

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  final List<Player> _players = [];
  final TextEditingController _nameController = TextEditingController();
  int? _selectedSkillLevel;
  bool _isComputer = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addPlayer() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a player name')),
      );
      return;
    }

    if (_isComputer && _selectedSkillLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a skill level for computer player'),
        ),
      );
      return;
    }

    final player = Player(
      name: _nameController.text.trim(),
      isComputer: _isComputer,
      skillLevel: _selectedSkillLevel ?? 1,
    );

    setState(() {
      _players.add(player);
      _nameController.clear();
      _selectedSkillLevel = null;
      _isComputer = false;
    });
  }

  void _startGame() {
    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 players are required')),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      '/game',
      arguments: {
        'players': _players,
        'isOnline': false,
        'lobbyCode': null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Setup'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Players',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Player Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Computer Player'),
                value: _isComputer,
                onChanged: (value) {
                  setState(() {
                    _isComputer = value ?? false;
                    if (!_isComputer) {
                      _selectedSkillLevel = null;
                    }
                  });
                },
              ),
              if (_isComputer) ...[
                const SizedBox(height: 8),
                const Text('Skill Level:'),
                Row(
                  children: [
                    Radio<int>(
                      value: 1,
                      groupValue: _selectedSkillLevel,
                      onChanged: (value) =>
                          setState(() => _selectedSkillLevel = value),
                    ),
                    const Text('Novice'),
                    Radio<int>(
                      value: 2,
                      groupValue: _selectedSkillLevel,
                      onChanged: (value) =>
                          setState(() => _selectedSkillLevel = value),
                    ),
                    const Text('Intermediate'),
                    Radio<int>(
                      value: 3,
                      groupValue: _selectedSkillLevel,
                      onChanged: (value) =>
                          setState(() => _selectedSkillLevel = value),
                    ),
                    const Text('Experienced'),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addPlayer,
                child: const Text('Add Player'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text(
                'Players Added:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._players.map((player) {
                final index = _players.indexOf(player);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: player.playerColor.withOpacity(0.2),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: player.playerColor,
                      child: Text(
                        player.firstLetter,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(player.name),
                    subtitle: Text(
                      player.isComputer
                          ? 'Computer - Level ${player.skillLevel}'
                          : 'Player',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _players.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start Game',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
