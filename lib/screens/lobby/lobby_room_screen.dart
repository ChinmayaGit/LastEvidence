import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../models/player.dart';
import '../game_board_screen.dart';

class LobbyRoomScreen extends StatefulWidget {
  final String lobbyCode;
  final String playerName;
  final bool isHost;

  const LobbyRoomScreen({
    super.key,
    required this.lobbyCode,
    required this.playerName,
    required this.isHost,
  });

  @override
  State<LobbyRoomScreen> createState() => _LobbyRoomScreenState();
}

class _LobbyRoomScreenState extends State<LobbyRoomScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _leaveLobby() {
    // If host leaves, the lobby is deleted or host transferred (logic in service)
    // For now, let's just leave.
    _firebaseService.leaveLobby(widget.lobbyCode, widget.playerName);
    Navigator.of(context).pop();
  }

  void _startGame(List<Player> players) {
    if (players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 players to start')),
      );
      return;
    }

    _firebaseService.startGame(widget.lobbyCode);
    // The stream listener will handle navigation when isStarted becomes true
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby Room'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.lobbyCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lobby code copied!')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Lobby?>(
        stream: _firebaseService.getLobby(widget.lobbyCode),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lobby = snapshot.data;
          if (lobby == null) {
            // Lobby deleted or doesn't exist
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) Navigator.of(context).pop();
            });
            return const Center(child: Text('Lobby closed'));
          }

          // Check if game started
          if (lobby.isStarted) {
            // Navigate to game board
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameBoardScreen(
                      initialPlayers: lobby.players,
                      isOnline: true,
                      lobbyCode: widget.lobbyCode,
                    ),
                  ),
                );
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                color: Colors.green.shade50,
                width: double.infinity,
                child: Column(
                  children: [
                    const Text(
                      'Lobby Code',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.lobbyCode,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for players... (${lobby.players.length}/6)',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: lobby.players.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = lobby.players[index];
                    final isMe = player.name == widget.playerName;
                    final isHost = player.name == lobby.hostName;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.primaries[
                              player.name.length % Colors.primaries.length],
                          child: Text(
                            player.name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          player.name,
                          style: TextStyle(
                            fontWeight:
                                isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: isHost ? const Text('Host') : null,
                        trailing: isMe
                            ? const Icon(Icons.person, color: Colors.blue)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (widget.isHost)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _startGame(lobby.players),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'START GAME',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _leaveLobby,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('LEAVE LOBBY'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
