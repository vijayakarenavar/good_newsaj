// lib/features/articles/presentation/widgets/article_card_widget.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';

class ArticleCardWidget extends StatefulWidget {
  final Map<String, dynamic> article;
  final Function(Map<String, dynamic>) onTrackRead;
  final Function(Map<String, dynamic>) onShare;

  const ArticleCardWidget({
    Key? key,
    required this.article,
    required this.onTrackRead,
    required this.onShare,
  }) : super(key: key);

  @override
  State<ArticleCardWidget> createState() => _ArticleCardWidgetState();
}

class _ArticleCardWidgetState extends State<ArticleCardWidget> {
  bool _hasTrackedRead = false;
  Timer? _visibilityTimer;

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  String _getShortTitle(String fullTitle) {
    final words = fullTitle.trim().split(' ');
    if (words.length <= 5) return fullTitle;
    return words.take(5).join(' ') + '...';
  }

  Widget _buildDefaultArticleImage(Color primary, bool isDark) {
    final title = widget.article['title'] ?? 'No Title';
    final shortTitle = _getShortTitle(title);
    return Container(
      color: primary.withOpacity(0.08),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            shortTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : primary,
              height: 1.3,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _removeAiText(String content) {
    final aiPatterns = [
      '[This article was rewritten using A.I]',
      '[This article was rewritten using A.I.]',
      '(This article was rewritten using A.I.)',
      '[Rewritten by AI]',
      'AI Rewritten:',
    ];
    var result = content;
    for (var pattern in aiPatterns) {
      result = result.replaceAll(pattern, '');
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _getSummaryCharLimit(double screenWidth) {
    if (screenWidth >= 800) return 900;
    if (screenWidth >= 700) return 750;
    if (screenWidth >= 600) return 650;
    if (screenWidth >= 450) return 500;
    return 350;
  }

  int _getSummaryMaxLines(double screenWidth, double screenHeight) {
    if (screenHeight > 800) return screenWidth > 600 ? 12 : 8;
    if (screenHeight > 700) return screenWidth > 600 ? 10 : 7;
    return screenWidth > 600 ? 8 : 5;
  }

  String _getSummaryText(BuildContext context, int maxLines) {
    final screenWidth = MediaQuery.of(context).size.width;
    final charLimit = _getSummaryCharLimit(screenWidth);
    final cleanContent = _removeAiText(widget.article['content'] ?? 'No content available');

    if (cleanContent.length <= charLimit) return cleanContent;

    final approxChars = maxLines * 80;
    final limit = charLimit < approxChars ? charLimit : approxChars;

    if (cleanContent.length <= limit) return cleanContent;

    final truncated = cleanContent.substring(0, limit);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace == -1) return truncated + '...';
    return truncated.substring(0, lastSpace) + '...';
  }

  bool _hasAiRewritingTag() {
    final content = widget.article['content'] ?? '';
    final aiPatterns = [
      '[This article was rewritten using A.I]',
      '[This article was rewritten using A.I.]',
      '(This article was rewritten using A.I.)',
      '[Rewritten by AI]',
      'AI Rewritten:',
    ];
    return aiPatterns.any((pattern) => content.contains(pattern));
  }

  String _getDomainFromUrl(String? url) {
    if (url == null || url.isEmpty) return 'News';
    try {
      final uri = Uri.parse(url);
      var host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      return host.isNotEmpty ? host : 'News';
    } catch (e) {
      return 'News';
    }
  }

  String _formatRelativeTime(dynamic dateStr) {
    if (dateStr == null) return 'Recent';
    try {
      DateTime date = dateStr is String
          ? (dateStr.contains('GMT') ? _parseGMTDate(dateStr) : DateTime.parse(dateStr))
          : dateStr is DateTime ? dateStr : DateTime.now();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (e) {
      return 'Recent';
    }
  }

  DateTime _parseGMTDate(String dateStr) {
    final parts = dateStr.split(' ');
    if (parts.length < 5) throw FormatException('Invalid GMT format');
    final day = int.parse(parts[1]);
    final month = _monthToNumber(parts[2]);
    final year = int.parse(parts[3]);
    final timeParts = parts[4].split(':');
    return DateTime.utc(year, month, day, int.parse(timeParts[0]), int.parse(timeParts[1]), int.parse(timeParts[2]));
  }

  int _monthToNumber(String month) {
    const months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
    return months[month] ?? 1;
  }

  Future<void> _openInAppBrowser(BuildContext context) async {
    final rawUrl = widget.article['source_url'] ?? '';
    String url = rawUrl.toString().trim();

    if (url.isEmpty || url.toLowerCase() == 'null' || url == 'undefined' || url == 'none') {
      _showErrorSnackBar(context, 'No source URL available.');
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      _showErrorSnackBar(context, 'Invalid article link.');
      return;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar(context, 'Cannot open this link.');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to open article.');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_hasTrackedRead || info.visibleFraction < 0.7) return;

    _visibilityTimer?.cancel();
    _visibilityTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_hasTrackedRead) {
        setState(() => _hasTrackedRead = true);
        widget.onTrackRead(widget.article);
        debugPrint('✅ Article ${widget.article['id']} tracked as read');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isAiRewritten = widget.article['is_ai_rewritten'] == 1 ||
        widget.article['is_ai_rewritten'] == true ||
        widget.article['is_ai_rewritten'] == '1';
    final hasAiTag = _hasAiRewritingTag();
    final showAiTag = isAiRewritten && hasAiTag;
    final sourceDomain = _getDomainFromUrl(widget.article['source_url']);
    final timeText = _formatRelativeTime(widget.article['created_at']);
    final title = widget.article['title'] ?? 'No Title';
    final summaryMaxLines = _getSummaryMaxLines(screenWidth, screenHeight);
    final summary = _getSummaryText(context, summaryMaxLines);
    final imageHeight = screenWidth > 600 ? 280.0 : screenWidth > 450 ? 260.0 : 230.0;
    final contentPadding = screenWidth > 600 ? 20.0 : screenWidth > 450 ? 18.0 : 16.0;
    final primaryColor = colorScheme.primary;

    // ✅ ADAPTIVE BUTTON METRICS BASED ON SCREEN WIDTH
    final buttonMetrics = _getButtonMetrics(screenWidth);
    final readButtonText = _getButtonText(screenWidth);

    Widget buildImageWidget() {
      final imageUrl = widget.article['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          memCacheHeight: 600,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(
            color: primaryColor.withOpacity(0.08),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildDefaultArticleImage(primaryColor, isDark),
        );
      } else {
        return _buildDefaultArticleImage(primaryColor, isDark);
      }
    }

    return VisibilityDetector(
      key: Key('article_${widget.article['id']}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: screenWidth > 600 ? 24.0 : screenWidth > 450 ? 18.0 : 12.0,
          vertical: screenHeight > 800 ? 14.0 : 10.0,
        ),
        constraints: screenWidth > 600 ? const BoxConstraints(maxWidth: 480) : null,
        child: Card(
          elevation: 8,
          margin: EdgeInsets.zero,
          shadowColor: isDark ? primaryColor.withOpacity(0.3) : Colors.black.withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: theme.cardTheme.color ?? (isDark ? const Color(0xFF121212) : Colors.white),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: GestureDetector(
              onTap: () {
                // Track read when card is tapped
                if (!_hasTrackedRead) {
                  setState(() => _hasTrackedRead = true);
                  widget.onTrackRead(widget.article);
                  debugPrint('✅ Article ${widget.article['id']} tracked as read (via card tap)');
                }
                // Open the article in browser
                _openInAppBrowser(context);
              },
              child: Column(
                children: [
                  // IMAGE SECTION
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: Hero(
                      tag: 'article_${widget.article['id']}',
                      child: buildImageWidget(),
                    ),
                  ),

                  // CONTENT SECTION
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: contentPadding,
                        right: contentPadding,
                        top: 16,
                        bottom: contentPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TIMESTAMP ONLY
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: isDark ? Colors.white60 : Colors.black45),
                              const SizedBox(width: 4),
                              Text(
                                timeText,
                                style: GoogleFonts.inter(
                                  color: isDark ? Colors.white60 : Colors.black45,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // TITLE
                          Text(
                            title,
                            style: GoogleFonts.merriweather(
                              fontSize: screenWidth > 600 ? 19 : screenWidth > 450 ? 17.5 : 16,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // SOURCE + AI TAG (SOLID THEME COLORS)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.15)
                                        : Colors.black.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.language_rounded, size: 11, color: isDark ? Colors.white70 : Colors.black87),
                                    const SizedBox(width: 4),
                                    Text(
                                      sourceDomain,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (showAiTag)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome, color: primaryColor, size: 11),
                                        const SizedBox(width: 4),
                                        Text(
                                          'AI Enhanced',
                                          style: GoogleFonts.poppins(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 8.5,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // SUMMARY
                          Expanded(
                            child: Text(
                              summary,
                              style: GoogleFonts.inter(
                                fontSize: screenWidth > 600 ? 14.5 : screenWidth > 450 ? 13 : 12,
                                height: 1.5,
                                color: isDark ? Colors.white70 : Colors.black87,
                                letterSpacing: 0.15,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: summaryMaxLines,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ✅ RESPONSIVE BUTTONS WITH WHITE TEXT (70:30 RATIO)
                          _buildResponsiveActionButtons(
                            context: context,
                            buttonMetrics: buttonMetrics,
                            primaryColor: primaryColor,
                            readButtonText: readButtonText,
                            isDark: isDark,
                            screenWidth: screenWidth,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ ULTRA-RESPONSIVE BUTTON TEXT (5 TIERS)
  String _getButtonText(double screenWidth) {
    if (screenWidth < 320) return 'Read';
    if (screenWidth < 360) return 'Read Art';
    if (screenWidth < 400) return 'Read Article';
    if (screenWidth < 600) return 'Read Full Article';
    return 'Read Full Article';
  }

  // ✅ 5-TIER BUTTON METRICS
  _ButtonMetrics _getButtonMetrics(double screenWidth) {
    if (screenWidth >= 600) {
      return _ButtonMetrics(
        height: 48,
        horizontalPadding: 16,
        iconSize: 20,
        textSize: 14,
        spacing: 8,
        borderRadius: 16,
      );
    } else if (screenWidth >= 400) {
      return _ButtonMetrics(
        height: 46,
        horizontalPadding: 14,
        iconSize: 19,
        textSize: 13.5,
        spacing: 7,
        borderRadius: 16,
      );
    } else if (screenWidth >= 360) {
      return _ButtonMetrics(
        height: 44,
        horizontalPadding: 12,
        iconSize: 18,
        textSize: 13,
        spacing: 6,
        borderRadius: 15,
      );
    } else if (screenWidth >= 320) {
      return _ButtonMetrics(
        height: 42,
        horizontalPadding: 10,
        iconSize: 17,
        textSize: 12.5,
        spacing: 5,
        borderRadius: 14,
      );
    } else {
      return _ButtonMetrics(
        height: 40,
        horizontalPadding: 8,
        iconSize: 16,
        textSize: 12,
        spacing: 4,
        borderRadius: 14,
      );
    }
  }

  // ✅ BUTTONS WITH WHITE TEXT/ICONS (EXPLICIT WHITE - MATCHING CREATE_POST_SCREEN)
  Widget _buildResponsiveActionButtons({
    required BuildContext context,
    required _ButtonMetrics buttonMetrics,
    required Color primaryColor,
    required String readButtonText,
    required bool isDark,
    required double screenWidth,
  }) {
    return Row(
      children: [
        // READ FULL ARTICLE BUTTON (70% width - WHITE TEXT)
        Expanded(
          flex: 7,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (!_hasTrackedRead) {
                  setState(() => _hasTrackedRead = true);
                  widget.onTrackRead(widget.article);
                  debugPrint('✅ Article ${widget.article['id']} tracked as read (via tap)');
                }
                _openInAppBrowser(context);
              },
              borderRadius: BorderRadius.circular(buttonMetrics.borderRadius),
              splashColor: isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.15),
              child: Ink(
                decoration: BoxDecoration(
                  color: primaryColor, // ✅ SOLID PRIMARY (NO GRADIENT)
                  borderRadius: BorderRadius.circular(buttonMetrics.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  constraints: BoxConstraints(minHeight: buttonMetrics.height.toDouble()),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: buttonMetrics.horizontalPadding,
                    vertical: (buttonMetrics.height - 24) / 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white, // ✅ EXPLICIT WHITE (NOT onPrimary)
                        size: buttonMetrics.iconSize,
                      ),
                      SizedBox(width: buttonMetrics.spacing),
                      Flexible(
                        child: Text(
                          readButtonText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: buttonMetrics.textSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white, // ✅ EXPLICIT WHITE
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                      SizedBox(width: buttonMetrics.spacing * 0.6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white, // ✅ EXPLICIT WHITE
                        size: buttonMetrics.iconSize * 0.85,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // SHARE BUTTON (30% width - WHITE TEXT)
        Expanded(
          flex: 3,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onShare(widget.article),
              borderRadius: BorderRadius.circular(buttonMetrics.borderRadius),
              splashColor: isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.15),
              child: Ink(
                decoration: BoxDecoration(
                  color: primaryColor, // ✅ SOLID PRIMARY (NO GRADIENT)
                  borderRadius: BorderRadius.circular(buttonMetrics.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Container(
                  constraints: BoxConstraints(minHeight: buttonMetrics.height.toDouble()),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: buttonMetrics.horizontalPadding * 0.8,
                    vertical: (buttonMetrics.height - 24) / 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        color: Colors.white, // ✅ EXPLICIT WHITE
                        size: buttonMetrics.iconSize * 0.95,
                      ),
                      if (screenWidth >= 320) ...[
                        SizedBox(width: buttonMetrics.spacing * 0.7),
                        Text(
                          'Share',
                          style: GoogleFonts.poppins(
                            fontSize: buttonMetrics.textSize * 0.95,
                            fontWeight: FontWeight.w700,
                            color: Colors.white, // ✅ EXPLICIT WHITE
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ HELPER CLASS FOR BUTTON METRICS
class _ButtonMetrics {
  final int height;
  final double horizontalPadding;
  final double iconSize;
  final double textSize;
  final double spacing;
  final double borderRadius;

  _ButtonMetrics({
    required this.height,
    required this.horizontalPadding,
    required this.iconSize,
    required this.textSize,
    required this.spacing,
    required this.borderRadius,
  });
}