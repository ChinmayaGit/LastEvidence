import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/suspect.dart';
import '../../models/weapon.dart';
import '../../models/room.dart';

class ClueCardsScreen extends StatelessWidget {
  final Player player;

  const ClueCardsScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
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
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final card = cards[index];
              return _buildCard(context, card);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, String card) {
    return SizedBox(
      width: 140,
      height: 200,
      child: GestureDetector(
        onTap: () => _showCardDetails(context, card),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 8,
                child: _buildCardImage(card),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      card,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardImage(String card) {
    final suspect = Suspect.fromName(card);
    if (suspect != null) {
      return Image.asset(
        suspect.assetPath,
        fit: BoxFit.cover,
      );
    }

    final weapon = Weapon.fromName(card);
    if (weapon != null) {
      return Image.asset(
        weapon.assetPath,
        fit: BoxFit.cover,
      );
    }

    final room = Room.fromName(card);
    if (room != null) {
      return Image.asset(
        room.assetPath,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: color,
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _showCardDetails(BuildContext context, String card) {
    Suspect? suspect = Suspect.fromName(card);
    Weapon? weapon = Weapon.fromName(card);
    Room? room = Room.fromName(card);

    String title = card;
    String type = '';
    String? imagePath;

    if (suspect != null) {
      type = 'Suspect';
      imagePath = suspect.assetPath;
    } else if (weapon != null) {
      type = 'Weapon';
      imagePath = weapon.assetPath;
    } else if (room != null) {
      type = 'Room';
      imagePath = room.assetPath;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagePath != null)
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (type.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
