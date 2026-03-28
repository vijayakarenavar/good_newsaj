import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class JoyScrollLoader extends StatefulWidget {
  const JoyScrollLoader({super.key});

  @override
  State<JoyScrollLoader> createState() => _JoyScrollLoaderState();
}

class _JoyScrollLoaderState extends State<JoyScrollLoader>
    with SingleTickerProviderStateMixin {

  final _random = Random();

  final List<Map<String, String>> _items = [
    {'emoji': '🏏', 'cat': 'SPORTS',       'title': 'India wins T20 series in thrilling finish'},
    {'emoji': '💰', 'cat': 'BUSINESS',      'title': 'Sensex hits all-time high today'},
    {'emoji': '🚀', 'cat': 'TECHNOLOGY',    'title': 'ISRO launches new satellite successfully'},
    {'emoji': '🌧️', 'cat': 'WEATHER',       'title': 'Heavy rainfall alert for Maharashtra'},
    {'emoji': '🎬', 'cat': 'ENTERTAINMENT', 'title': 'Blockbuster movie crosses ₹1000 crore'},
    {'emoji': '🏛️', 'cat': 'POLITICS',      'title': 'New policy reforms tabled in Parliament'},
    {'emoji': '🌍', 'cat': 'WORLD',         'title': 'UN Climate Summit kicks off worldwide'},
    {'emoji': '⚽', 'cat': 'SPORTS',        'title': 'Mumbai FC qualifies for AFC Champions'},
  ];

  final List<String> _funFacts = [
    '📰 Did you know? The first newspaper was published in 1605!',
    '🌍 Did you know? 500 million tweets are sent every day!',
    '📱 Did you know? India has 600M+ internet users!',
    '🧠 Did you know? Reading news improves your vocabulary!',
    '⚡ Did you know? Breaking news travels faster than sound!',
    '📺 Did you know? TV news started in 1948 in the USA!',
  ];

  final List<String> _quotes = [
    '"The more you read, the more you know." – Dr. Seuss',
    '"Knowledge is power." – Francis Bacon',
    '"Stay curious, stay informed." – Unknown',
    '"News is the first draft of history." – Phil Graham',
  ];

  final List<String> _msgs = [
    'Curating your feed...',
    'Fetching top stories...',
    'Almost there...',
    'Loading JoyScroll...',
  ];

  int _idx = 0;
  int _factIdx = 0;
  bool _showFact = true;
  double _progress = 0.0;
  int _msgIdx = 0;

  late AnimationController _fadeController;
  Timer? _cardTimer;
  Timer? _factTimer;
  Timer? _msgTimer;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Card दर 3 seconds ला random बदलतो
    _cardTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      _changeCard();
    });

    // Fact/Quote दर 4 seconds ला random बदलतो
    _factTimer = Timer.periodic(const Duration(milliseconds: 4000), (_) {
      if (mounted) {
        setState(() {
          _showFact = _random.nextBool();
          if (_showFact) {
            _factIdx = _random.nextInt(_funFacts.length);
          } else {
            _factIdx = _random.nextInt(_quotes.length);
          }
        });
      }
    });

    // Message दर 3 seconds ला बदलतो
    _msgTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (mounted) {
        setState(() {
          _msgIdx = (_msgIdx + 1) % _msgs.length;
        });
      }
    });

    // Progress bar
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _progress = (_progress + 0.06).clamp(0.0, 0.92);
        });
      }
    });
  }

  // Random card बदलतो
  void _changeCard() async {
    if (!mounted) return;
    await _fadeController.forward();
    if (!mounted) return;
    setState(() {
      int newIdx;
      do {
        newIdx = _random.nextInt(_items.length);
      } while (newIdx == _idx);
      _idx = newIdx;
    });
    await _fadeController.reverse();
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _factTimer?.cancel();
    _msgTimer?.cancel();
    _progressTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = _items[_idx];

    final String factText = _showFact
        ? _funFacts[_factIdx % _funFacts.length]
        : _quotes[_factIdx % _quotes.length];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.article_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      children: [
                        const TextSpan(text: 'Joy'),
                        TextSpan(
                          text: 'Scroll',
                          style: TextStyle(color: primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // News Card
              FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0)
                    .animate(_fadeController),
                child: Container(
                  key: ValueKey(_idx),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            item['emoji']!,
                            style: const TextStyle(fontSize: 68),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['cat']!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['title']!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Fun Fact / Quote Card
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Container(
                  key: ValueKey('${_showFact}_$_factIdx'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primary.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _showFact ? '💡' : '✨',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          factText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: primary.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                  minHeight: 3,
                ),
              ),

              const SizedBox(height: 12),

              // Message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _msgs[_msgIdx],
                  key: ValueKey(_msgIdx),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.grey[500],
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