import 'package:flutter/material.dart';

import '../../models/game_state.dart';

class GameStatusView extends StatelessWidget {
  final GameState gameState;

  const GameStatusView({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Players:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 12),
          ...gameState.players.map((p) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: p.playerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        p.firstLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  if (p.isOutOfGame)
                    const Chip(
                      label: Text('Out'),
                      backgroundColor: Colors.red,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    )
                  else if (p.name == gameState.currentPlayer.name)
                    const Chip(
                      label: Text('Current Turn'),
                      backgroundColor: Colors.green,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          if (gameState.gameOver) ...[
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Game Over!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'Winner: ${gameState.winner ?? "Unknown"}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Solution:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '  Suspect: ${gameState.murderer ?? "Unknown"}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              '  Weapon: ${gameState.murderWeapon ?? "Unknown"}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              '  Room: ${gameState.murderRoom ?? "Unknown"}',
              style: const TextStyle(fontSize: 16),
            ),
          ] else ...[
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Game Info:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'Current Turn: ${gameState.currentPlayer.name}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Dice Roll: ${gameState.diceRoll > 0 ? gameState.diceRoll : "Not rolled"}',
              style: const TextStyle(fontSize: 16),
            ),
            if (gameState.remainingSteps > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Remaining Steps: ${gameState.remainingSteps}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

