import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/player_setup_screen.dart';
import 'screens/game_board_screen.dart';
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
      initialRoute: '/',
      routes: {
        '/': (context) => const ModeSelectionScreen(),
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
