import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import 'lobby/create_lobby_screen.dart';
import 'lobby/join_lobby_screen.dart';
import 'lobby/lobby_room_screen.dart';
import 'game_board_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final session = await _firebaseService.checkActiveSession(user.uid);
      if (session != null && mounted) {
        // Found active session
        final String code = session['code'];
        final String type = session['type'];
        final data = session['data'];

        if (type == 'game') {
          // Rejoin active game
          final playersData = (data['players'] as List<dynamic>)
              .map((p) => Lobby.playerFromJson(p as Map<String, dynamic>))
              .toList();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameBoardScreen(
                initialPlayers: playersData,
                isOnline: true,
                lobbyCode: code,
              ),
            ),
          );
        } else if (type == 'lobby') {
          // Rejoin lobby
          final String hostName = data['hostName'];
          final bool isStarted = session['isStarted'];

          if (isStarted) {
            // If lobby started but game doc not found/checked yet, try to join game screen
            // But usually 'game' type check handles this.
            // If we are here, it means lobby doc says started but we caught it as lobby type.
            // Let's go to lobby room, it will handle redirection to game if started.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LobbyRoomScreen(
                  lobbyCode: code,
                  playerName: user.displayName ?? 'Player',
                  isHost: hostName == (user.displayName ?? ''),
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LobbyRoomScreen(
                  lobbyCode: code,
                  playerName: user.displayName ?? 'Player',
                  isHost: hostName == (user.displayName ?? ''),
                ),
              ),
            );
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Lobby'),
        backgroundColor: Colors.green.shade700,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud, size: 80, color: Colors.green.shade700),
              const SizedBox(height: 24),
              const Text(
                'Online Multiplayer',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              // Create Game Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateLobbyScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  label: const Text(
                    'Create Game',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Join Game Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const JoinLobbyScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search, size: 28),
                  label: const Text(
                    'Join Game',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
