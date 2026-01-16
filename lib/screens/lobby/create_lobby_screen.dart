import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/firebase_service.dart';
import '../../models/player.dart';
import '../game_board_screen.dart';

class CreateLobbyScreen extends StatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  State<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends State<CreateLobbyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  String? _lobbyCode;
  bool _isCreating = false;
  Stream<Lobby?>? _lobbyStream;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createLobby() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final playerName = _nameController.text.trim();
      final hostPlayer = Player(name: playerName);
      final code = await _firebaseService.createLobby(playerName, hostPlayer);

      setState(() {
        _lobbyCode = code;
        _lobbyStream = _firebaseService.getLobby(code);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating lobby: $e')),
        );
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _shareCode() {
    if (_lobbyCode != null) {
      Share.share(
        'Join my Evidence game! Code: $_lobbyCode',
        subject: 'Evidence Game Invitation',
      );
    }
  }

  void _startGame(Lobby lobby) async {
    if (lobby.players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 players to start')),
      );
      return;
    }

    await _firebaseService.startGame(_lobbyCode!);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameBoardScreen(
            initialPlayers: lobby.players,
            isOnline: true,
            lobbyCode: _lobbyCode!,
            localPlayerName: _nameController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lobbyCode == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Game'),
          backgroundColor: Colors.green.shade700,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter Your Name',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createLobby,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCreating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Lobby',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby'),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<Lobby?>(
        stream: _lobbyStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Lobby not found'));
          }

          final lobby = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          'Lobby Code',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _lobbyCode!,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _shareCode,
                          icon: const Icon(Icons.share),
                          label: const Text('Share Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Players',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: lobby.players.length,
                    itemBuilder: (context, index) {
                      final player = lobby.players[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: player.playerColor,
                            child: Text(
                              player.firstLetter,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(player.name),
                          trailing: lobby.hostName == player.name
                              ? Chip(
                                  label: const Text('Host'),
                                  backgroundColor: Colors.green.shade100,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (lobby.hostName == _nameController.text.trim())
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: lobby.isStarted ? null : () => _startGame(lobby),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Start Game',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

