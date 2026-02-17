import 'package:flutter/material.dart';
import 'package:good_news/core/constants/theme_tokens.dart';

class SpeedDialFAB extends StatefulWidget {
  final List<SpeedDialAction> actions;

  const SpeedDialFAB({
    Key? key,
    required this.actions,
  }) : super(key: key);

  @override
  State<SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends State<SpeedDialFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _collapse() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final animValue = _expandAnimation.value;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // ✅ Backdrop - उघडा असताना बाहेर tap close करतो
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _collapse,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),

        // ✅ REAL FIX: animValue > 0 तरच buttons exist करतात
        // animValue == 0 म्हणजे buttons DOM मधून पूर्णपणे गेले
        if (animValue > 0)
          ...widget.actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            final offset = (index + 1) * 70.0 * animValue;

            return Positioned(
              bottom: 16 + offset,
              right: 16,
              child: Opacity(
                opacity: animValue,
                child: Transform.scale(
                  scale: animValue,
                  alignment: Alignment.bottomRight,
                  child: _buildSpeedDialItem(action),
                ),
              ),
            );
          }).toList(),

        // ✅ Main FAB - नेहमी वर राहतो, नेहमी clickable
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'main_speed_dial_fab',
            onPressed: _toggle,
            backgroundColor: ThemeTokens.primaryGreen,
            child: AnimatedRotation(
              turns: _isExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              child: Icon(
                Icons.add,
                color: Colors.white,
                semanticLabel: _isExpanded ? 'Close menu' : 'Open actions menu',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialItem(SpeedDialAction action) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? screenWidth * 0.4 : 200,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 12,
            vertical: isSmallScreen ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            action.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        SizedBox(
          width: 40,
          height: 40,
          child: FloatingActionButton(
            heroTag: action.heroTag ?? 'speed_dial_${action.label}',
            onPressed: () {
              _collapse();
              action.onPressed();
            },
            backgroundColor: ThemeTokens.primaryGreen,
            mini: true,
            child: Icon(
              action.icon,
              color: Colors.white,
              size: 20,
              semanticLabel: action.semanticLabel ?? action.label,
            ),
          ),
        ),
      ],
    );
  }
}

class SpeedDialAction {
  final IconData icon;
  final String label;
  final String? semanticLabel;
  final VoidCallback onPressed;
  final Object? heroTag;

  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    this.heroTag,
  });
}