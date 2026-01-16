import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/player.dart';
import '../game_board_screen.dart';

class JoinLobbyScreen extends StatefulWidget {
  const JoinLobbyScreen({super.key});

  @override
  State<JoinLobbyScreen> createState() => _JoinLobbyScreenState();
}

class _JoinLobbyScreenState extends State<JoinLobbyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _showCodeInput = false;
  String? _joinedLobbyCode;
  Stream<Lobby?>? _lobbyStream;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinByCode() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter lobby code')),
      );
      return;
    }

    final playerName = _nameController.text.trim();
    final code = _codeController.text.trim();
    final player = Player(name: playerName);

    final success = await _firebaseService.joinLobby(code, player);

    if (!mounted) return;

    if (success) {
      setState(() {
        _joinedLobbyCode = code;
        _lobbyStream = _firebaseService.getLobby(code);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to join lobby. Check code or try another lobby.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _joinLobby(Lobby lobby, String playerName) async {
    if (lobby.isStarted) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameBoardScreen(
              initialPlayers: lobby.players,
              isOnline: true,
              lobbyCode: lobby.code,
              localPlayerName: playerName,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_joinedLobbyCode != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lobby'),
          backgroundColor: Colors.blue.shade700,
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

            if (lobby.isStarted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _joinLobby(lobby, _nameController.text.trim());
              });
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Card(
                    color: Colors.blue.shade50,
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
                            lobby.code,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                              letterSpacing: 4,
                            ),
                          ),
                          if (lobby.isStarted)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                'Game Starting...',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                    backgroundColor: Colors.blue.shade100,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Game'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_showCodeInput) ...[
                const Text(
                  'Available Lobbies',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Lobby>>(
                  stream: _firebaseService.getOpenLobbies(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No open lobbies available'),
                        ),
                      );
                    }

                    final lobbies = snapshot.data!;

                    return Column(
                      children: lobbies.map((lobby) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading:
                                Icon(Icons.people, color: Colors.blue.shade700),
                            title: Text('Lobby ${lobby.code}'),
                            subtitle: Text(
                              '${lobby.players.length}/6 players - Host: ${lobby.hostName}',
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              setState(() {
                                _codeController.text = lobby.code;
                                _showCodeInput = true;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showCodeInput = true;
                    });
                  },
                  child: const Text('Enter Code Manually'),
                ),
              ] else ...[
                const Text(
                  'Enter Lobby Code',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Lobby Code',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _joinByCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      const Text('Join Lobby', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showCodeInput = false;
                    });
                  },
                  child: const Text('Browse Lobbies'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
