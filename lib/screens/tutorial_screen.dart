import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialScreen extends StatefulWidget {
  final VoidCallback onDone;

  const TutorialScreen({super.key, required this.onDone});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Welcome to Evidence',
      'description':
          'Become a detective and solve the mystery! Someone has been murdered, and it\'s up to you to find out WHO did it, with WHAT weapon, and WHERE.',
      'icon': Icons.search,
      'color': Colors.deepPurple,
    },
    {
      'title': 'The Objective',
      'description':
          'Navigate the mansion and gather clues. Eliminate suspects, weapons, and rooms by asking other players. The last remaining cards are the solution.',
      'icon': Icons.lightbulb_outline,
      'color': Colors.amber,
    },
    {
      'title': 'How to Move',
      'description':
          'Roll the dice to move your character. You must land in a room to look for clues. Secret passages can help you travel quickly across the board!',
      'icon': Icons.directions_walk,
      'color': Colors.blue,
    },
    {
      'title': 'Making Suggestions',
      'description':
          'Once in a room, suggest a Suspect and a Weapon. If another player has one of those cards, they must show it to you secretly.',
      'icon': Icons.question_answer,
      'color': Colors.green,
    },
    {
      'title': 'Using Your Notebook',
      'description':
          'Tap the "Notes" button to track your findings. Mark off cards you\'ve seen. Use colors to mark confirmed (Green), possible (Blue), or impossible (Grey).',
      'icon': Icons.edit_note,
      'color': Colors.teal,
    },
    {
      'title': 'The Final Accusation',
      'description':
          'When you are 100% sure, go to the center room to make your Accusation. Be careful—if you are wrong, you are out of the game!',
      'icon': Icons.gavel,
      'color': Colors.red,
    },
  ];

  Future<void> _finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: (slide['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide['icon'] as IconData,
                            size: 100,
                            color: slide['color'] as Color,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          slide['title'] as String,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          slide['description'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Buttons
                  Row(
                    children: [
                      if (_currentPage < _slides.length - 1)
                        TextButton(
                          onPressed: _finishTutorial,
                          child: const Text('Skip'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _slides.length - 1) {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _finishTutorial();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _currentPage == _slides.length - 1 ? 'Play' : 'Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
