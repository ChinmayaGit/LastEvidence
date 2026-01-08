import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/suspect.dart';
import '../models/weapon.dart';
import '../models/room.dart';

class ClueCardsScreen extends StatelessWidget {
  final Player player;

  const ClueCardsScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    // Categorize cards
    final suspects = <String>[];
    final weapons = <String>[];
    final rooms = <String>[];

    for (final card in player.clueCards) {
      if (Suspect.values.any((s) => s.name == card)) {
        suspects.add(card);
      } else if (Weapon.values.any((w) => w.name == card)) {
        weapons.add(card);
      } else if (Room.values.any((r) => r.name == card)) {
        rooms.add(card);
      }
    }

    return Scaffold(
      body: player.clueCards.isEmpty
          ? const Center(
              child: Text('No clue cards yet'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (suspects.isNotEmpty) ...[
                  _CategorySection(
                    title: 'Suspects',
                    cards: suspects,
                    icon: Icons.person,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                ],
                if (weapons.isNotEmpty) ...[
                  _CategorySection(
                    title: 'Weapons',
                    cards: weapons,
                    icon: Icons.build,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                ],
                if (rooms.isNotEmpty) ...[
                  _CategorySection(
                    title: 'Rooms',
                    cards: rooms,
                    icon: Icons.door_front_door,
                    color: Colors.brown,
                  ),
                ],
              ],
            ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final List<String> cards;
  final IconData icon;
  final Color color;

  const _CategorySection({
    required this.title,
    required this.cards,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${cards.length}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...cards.map((card) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                title: Text(
                  card,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            )),
      ],
    );
  }
}
