// lib/features/articles/presentation/screens/article_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/foundation.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> article;

  const ArticleDetailScreen({
    Key? key,
    required this.article,
  }) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLoading = false;

  // ================= CLEAN AI TEXT =================
  String _removeAiText(String content) {
    final aiPatterns = [
      '[This article was rewritten using A.I]',
      '[This article was rewritten using A.I.]',
      '(This article was rewritten using A.I.)',
      '[Rewritten by AI]',
      'AI Rewritten:',
    ];
    var result = content;
    for (var p in aiPatterns) {
      result = result.replaceAll(p, '');
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _getCleanContent() {
    debugPrint('📰 ARTICLE DETAIL: Keys available: ${widget.article.keys.toList()}');
    debugPrint('📰 ARTICLE DETAIL: content = ${widget.article['content']}');
    debugPrint('📰 ARTICLE DETAIL: summary = ${widget.article['summary']}');
    debugPrint('📰 ARTICLE DETAIL: rewritten_summary = ${widget.article['rewritten_summary']}');

    final rawContent = widget.article['rewritten_summary'] ??
        widget.article['summary'] ??
        widget.article['content'] ??
        widget.article['rewritten_content'] ??
        widget.article['description'] ??
        '';

    if (rawContent.isEmpty || rawContent == 'No content available') {
      return '''
      <div style="padding: 20px; background: #f5f5f5; border-radius: 8px; text-align: center;">
        <h3>📰 Content Not Available</h3>
        <p>The full article content is not available in the app.</p>
        <p><strong>Please tap "Visit Official Source" button below to read the complete article.</strong></p>
      </div>
    ''';
    }

    return _removeAiText(rawContent);
  }

  // ================= DOMAIN =================
  String _getDomainFromUrl(String? url) {
    if (url == null || url.isEmpty) return "Source";
    try {
      final uri = Uri.parse(url);
      var host = uri.host.replaceFirst("www.", "");
      return host.split(".").take(2).join(".");
    } catch (_) {
      return "Source";
    }
  }

  // ================= DATE FORMAT =================
  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return "Unknown";
    try {
      final date = DateTime.parse(dateStr.toString());
      final diff = DateTime.now().difference(date);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";

      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return "Recent";
    }
  }

  // ================= OPEN SOURCE URL =================
  Future<void> _openSourceUrl() async {
    setState(() => _isLoading = true);

    String url = widget.article['source_url']?.toString() ?? "";
    if (url.isEmpty || url == "null") {
      _showSnack("No source link");
      setState(() => _isLoading = false);
      return;
    }

    if (!url.startsWith("http")) url = "https://$url";

    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showSnack("Cannot open link");
    }

    setState(() => _isLoading = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= ARTICLE IMAGE - FIXED VERSION =================
  Widget _buildArticleImage(Color primaryColor) {
    final imageUrl = widget.article['image_url'];
    final width = MediaQuery.of(context).size.width;
    final height = width > 800 ? 450.0 : 300.0;

    debugPrint('🖼️ IMAGE DEBUG: imageUrl = $imageUrl');
    debugPrint('🖼️ IMAGE DEBUG: imageUrl type = ${imageUrl.runtimeType}');
    debugPrint('🖼️ IMAGE DEBUG: imageUrl isEmpty = ${imageUrl?.toString().isEmpty}');

    // ✅ IMPROVED IMAGE VALIDATION
    if (imageUrl != null &&
        imageUrl.toString().isNotEmpty &&
        imageUrl != "null" &&
        imageUrl != "NULL") {

      final imageUrlString = imageUrl.toString();

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: imageUrlString,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          // ✅ ADDED: Memory cache settings for better performance
          memCacheWidth: 800,
          memCacheHeight: 600,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (_, __) => Container(
            color: primaryColor.withOpacity(0.1),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading image...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('❌ IMAGE LOAD ERROR: $error');
            debugPrint('❌ FAILED URL: $url');
            return _buildDefaultArticleImage(primaryColor);
          },
        ),
      );
    }

    debugPrint('⚠️ NO VALID IMAGE URL - Showing default');
    return _buildDefaultArticleImage(primaryColor);
  }

  // ✅ NEW: Default image widget matching ArticleCardWidget style
  Widget _buildDefaultArticleImage(Color primaryColor) {
    final title = widget.article['title'] ?? 'No Title';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final height = width > 800 ? 450.0 : 300.0;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _getShortTitle(title),
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : primaryColor,
              height: 1.3,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Helper to get short title
  String _getShortTitle(String fullTitle) {
    final words = fullTitle.trim().split(' ');
    if (words.length <= 6) return fullTitle;
    return words.take(6).join(' ') + '...';
  }

  String _formatHtmlContent(String content) {
    if (content.isEmpty) {
      return '''
      <div style="padding: 20px; text-align: center;">
        <p style="color: #666;">No content available</p>
      </div>
    ''';
    }

    content = content.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '');
    content = content.replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false), '');

    if (!content.contains('<') && !content.contains('>')) {
      final paragraphs = content.split('\n\n');
      content = paragraphs.map((p) => '<p>${p.trim()}</p>').join('\n');
    }

    return content;
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;

    final title = widget.article['title'] ?? "Untitled";
    final author = widget.article['author']?.toString() ?? "Unknown";
    final domain = _getDomainFromUrl(widget.article['source_url']);
    final time = _formatDateTime(widget.article['created_at']);
    final content = _getCleanContent();

    // ✅ RESPONSIVE FONT SIZES - SMALLER
    final titleFontSize = screenWidth > 600 ? 22.0 : 20.0;
    final contentFontSize = screenWidth > 600 ? 14.0 : 13.0; // ✅ REDUCED from 17 to 14/13

    return Scaffold(
      appBar: AppBar(
        title: const Text("Article Details"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ FIXED IMAGE WIDGET
            _buildArticleImage(primaryColor),
            const SizedBox(height: 16),

            // TITLE - SMALLER FONT
            Text(
              title,
              style: GoogleFonts.merriweather(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 10),

            // META
            Wrap(
              spacing: 12,
              children: [
                Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language, size: 16),
                      SizedBox(width: 4),
                      Text(domain)
                    ]
                ),
                Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 16),
                      SizedBox(width: 4),
                      Text(time)
                    ]
                ),
              ],
            ),

            const SizedBox(height: 20),

            // HTML CONTENT - SMALLER FONT SIZE
            Html(
              data: _formatHtmlContent(content),
              style: {
                "body": Style(
                  fontSize: FontSize(contentFontSize), // ✅ REDUCED FONT SIZE
                  lineHeight: LineHeight(1.6),
                  color: isDark ? Colors.white : Colors.black87,
                ),
                "p": Style(
                  fontSize: FontSize(contentFontSize), // ✅ PARAGRAPH FONT
                  lineHeight: LineHeight(1.6),
                  margin: Margins.only(bottom: 12),
                ),
                "h1": Style(
                  fontSize: FontSize(contentFontSize + 6), // ✅ HEADING 1
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 16, bottom: 12),
                ),
                "h2": Style(
                  fontSize: FontSize(contentFontSize + 4), // ✅ HEADING 2
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 14, bottom: 10),
                ),
                "h3": Style(
                  fontSize: FontSize(contentFontSize + 2), // ✅ HEADING 3
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 12, bottom: 8),
                ),
                "img": Style(
                  width: Width(100, Unit.percent),
                  height: Height.auto(),
                  margin: Margins.symmetric(vertical: 12),
                ),
                "blockquote": Style(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  padding: HtmlPaddings.all(12),
                  border: Border(
                    left: BorderSide(color: primaryColor, width: 4),
                  ),
                  margin: Margins.symmetric(vertical: 12),
                ),
                "ul": Style(
                  fontSize: FontSize(contentFontSize),
                  margin: Margins.only(left: 16, bottom: 12),
                ),
                "ol": Style(
                  fontSize: FontSize(contentFontSize),
                  margin: Margins.only(left: 16, bottom: 12),
                ),
                "li": Style(
                  fontSize: FontSize(contentFontSize),
                  margin: Margins.only(bottom: 6),
                ),
              },
              onAnchorTap: (url, attributes, element) async {
                if (url != null) {
                  final uri = Uri.parse(url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),

            const SizedBox(height: 30),

            // VISIT SOURCE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _openSourceUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white)
                )
                    : const Text("Visit Official Source"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}