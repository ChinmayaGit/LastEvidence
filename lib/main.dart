import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/player_setup_screen.dart';
import 'screens/game_board_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'models/player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const EvidenceApp());
}

class EvidenceApp extends StatelessWidget {
  const EvidenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evidence Detective Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const ModeSelectionScreen(),
        '/offline': (context) => const PlayerSetupScreen(),
        '/game': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return GameBoardScreen(
            initialPlayers: args['players'] as List<Player>,
            isOnline: args['isOnline'] as bool? ?? false,
            lobbyCode: args['lobbyCode'] as String?,
          );
        },
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          return const ModeSelectionScreen();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
