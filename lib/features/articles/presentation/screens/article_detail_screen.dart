// lib/features/articles/presentation/screens/article_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> article;

  const ArticleDetailScreen({
    super.key,
    required this.article,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    assert(widget.article['id'] != null, 'article.id cannot be null');
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
    for (var p in aiPatterns) {
      result = result.replaceAll(p, '');
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _getCleanContent() {
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

  String _getDomainFromUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      var host = uri.host.replaceFirst('www.', '');
      return host.split('.').take(2).join('.');
    } catch (_) {
      return '';
    }
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && ['http', 'https'].contains(uri.scheme);
  }

  Future<void> _openSourceUrl() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    String? rawUrl;
    for (final key in ['source_url', 'url', 'link', 'article_url', 'original_url']) {
      final val = widget.article[key]?.toString().trim();
      if (val != null && val.isNotEmpty && val != 'null') {
        rawUrl = val;
        break;
      }
    }

    if (rawUrl == null || rawUrl.isEmpty) {
      _showSnack('No source link available');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!_isValidUrl(rawUrl)) {
      _showSnack('Invalid or unsafe link');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final uri = Uri.parse(rawUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Cannot open link');
      }
    } catch (e) {
      _showSnack('Cannot open link. Please try again.');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isValidImageUrl(dynamic imageUrl) {
    if (imageUrl == null) return false;
    final s = imageUrl.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'NULL' || s == 'undefined') return false;
    if (!s.startsWith('http://') && !s.startsWith('https://')) return false;
    return true;
  }

  Widget _buildArticleImage(Color primaryColor) {
    dynamic imageUrl;
    for (final key in ['image_url', 'image', 'thumbnail_url', 'thumbnail', 'featured_image']) {
      if (_isValidImageUrl(widget.article[key])) {
        imageUrl = widget.article[key];
        break;
      }
    }

    final width = MediaQuery.of(context).size.width;
    final height = width > 800 ? 450.0 : 280.0;

    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: imageUrl.toString().trim(),
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          memCacheHeight: 600,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (_, __) => Container(
            height: height,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => _buildDefaultArticleImage(primaryColor),
        ),
      );
    }
    return _buildDefaultArticleImage(primaryColor);
  }

  Widget _buildDefaultArticleImage(Color primaryColor) {
    final title = widget.article['title'] ?? 'No Title';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final height = width > 800 ? 450.0 : 280.0;

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
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : primaryColor,
              height: 1.3,
              shadows: const [
                Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _getShortTitle(String fullTitle) {
    final words = fullTitle.trim().split(' ');
    if (words.length <= 6) return fullTitle;
    return '${words.take(6).join(' ')}...';
  }

  String _formatHtmlContent(String content) {
    if (content.isEmpty) {
      return '<div style="padding: 20px; text-align: center;"><p style="color: #666;">No content available</p></div>';
    }

    // ✅ Step 1: Remove script tags
    content = content.replaceAll(
      RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false, multiLine: true),
      '',
    );

    // ✅ Step 2: Remove style tags
    content = content.replaceAll(
      RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false, multiLine: true),
      '',
    );

    // ✅ Step 3: Remove event handlers (onerror, onload, onclick, etc.)
    content = content.replaceAll(
      RegExp(r'\s+on\w+\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    content = content.replaceAll(
      RegExp(r"\s+on\w+\s*=\s*'[^']*'", caseSensitive: false),
      '',
    );

    // ✅ Step 4: Remove javascript: URLs
    content = content.replaceAll(
      RegExp(r'javascript\s*:', caseSensitive: false),
      '',
    );

    // ✅ Step 5: Remove iframe tags
    content = content.replaceAll(
      RegExp(r'<iframe\b[^>]*>[\s\S]*?</iframe>', caseSensitive: false, multiLine: true),
      '',
    );
    content = content.replaceAll(
      RegExp(r'<iframe\b[^>]*/>'),
      '',
    );

    // ✅ Step 6: Remove object tags
    content = content.replaceAll(
      RegExp(r'<object\b[^>]*>[\s\S]*?</object>', caseSensitive: false, multiLine: true),
      '',
    );

    // ✅ Step 7: Remove embed tags
    content = content.replaceAll(
      RegExp(r'<embed\b[^>]*>[\s\S]*?</embed>', caseSensitive: false, multiLine: true),
      '',
    );

    // ✅ Step 8: Remove form tags
    content = content.replaceAll(
      RegExp(r'<form\b[^>]*>[\s\S]*?</form>', caseSensitive: false, multiLine: true),
      '',
    );

    // ✅ Step 9: Remove dangerous SVG patterns
    content = content.replaceAll(
      RegExp(r'<svg\b[^>]*on\w+\s*=[^>]*>', caseSensitive: false),
      '<svg>',
    );

    // ✅ Step 10: If content has no HTML tags, wrap in paragraphs
    if (!content.contains('<') && !content.contains('>')) {
      final paragraphs = content.split('\n\n');
      content = paragraphs.map((p) => '<p>${p.trim()}</p>').join('\n');
    }

    return content;
  }

  bool _hasValidSourceUrl() {
    for (final key in ['source_url', 'url', 'link', 'article_url', 'original_url']) {
      final val = widget.article[key]?.toString().trim() ?? '';
      if (val.isNotEmpty && val != 'null') return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.article.isEmpty || widget.article['id'] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Article')),
        body: const Center(child: Text('Article data not available')),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;

    final title = widget.article['title'] ?? 'Untitled';
    final domain = _getDomainFromUrl(
        widget.article['source_url'] ?? widget.article['url'] ?? '');
    final time = _formatDateTime(
        widget.article['created_at'] ?? widget.article['published_at']);
    final content = _getCleanContent();
    final hasSourceUrl = _hasValidSourceUrl();

    final titleFontSize = screenWidth > 600 ? 22.0 : 20.0;
    final contentFontSize = screenWidth > 600 ? 14.0 : 13.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        actions: [
          if (hasSourceUrl)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Open in browser',
              onPressed: _isLoading ? null : _openSourceUrl,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildArticleImage(primaryColor),
            const SizedBox(height: 16),

            Text(
              title,
              style: GoogleFonts.merriweather(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            if (domain.isNotEmpty || time.isNotEmpty)
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (domain.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.language, size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(domain,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ]),
                  if (time.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.access_time, size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(time,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ]),
                ],
              ),

            const SizedBox(height: 20),

            Html(
              data: _formatHtmlContent(content),
              style: {
                'body': Style(
                  fontSize: FontSize(contentFontSize),
                  lineHeight: LineHeight(1.6),
                  color: isDark ? Colors.white : Colors.black87,
                ),
                'p': Style(
                  fontSize: FontSize(contentFontSize),
                  lineHeight: LineHeight(1.6),
                  margin: Margins.only(bottom: 12),
                ),
                'h1': Style(
                  fontSize: FontSize(contentFontSize + 6),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 16, bottom: 12),
                ),
                'h2': Style(
                  fontSize: FontSize(contentFontSize + 4),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 14, bottom: 10),
                ),
                'h3': Style(
                  fontSize: FontSize(contentFontSize + 2),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 12, bottom: 8),
                ),
                'img': Style(
                  width: Width(100, Unit.percent),
                  height: Height.auto(),
                  margin: Margins.symmetric(vertical: 12),
                ),
                'blockquote': Style(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  padding: HtmlPaddings.all(12),
                  border: Border(left: BorderSide(color: primaryColor, width: 4)),
                  margin: Margins.symmetric(vertical: 12),
                ),
                'ul': Style(
                  fontSize: FontSize(contentFontSize),
                  margin: Margins.only(left: 16, bottom: 12),
                ),
                'ol': Style(
                  fontSize: FontSize(contentFontSize),
                  margin: Margins.only(left: 16, bottom: 12),
                ),
                'li': Style(
                  fontSize: FontSize(contentFontSize),
                  margin: Margins.only(bottom: 6),
                ),
              },
              onAnchorTap: (url, attributes, element) async {
                if (url == null || url.trim().isEmpty) return;

                if (!_isValidUrl(url)) {
                  _showSnack('Invalid or unsafe link');
                  return;
                }

                try {
                  final uri = Uri.parse(url.trim());
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    _showSnack('Cannot open link');
                  }
                } catch (_) {
                  _showSnack('Cannot open link');
                }
              },
            ),

            const SizedBox(height: 30),

            if (hasSourceUrl)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _openSourceUrl,
                  icon: _isLoading
                      ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.open_in_new),
                  label: const Text('Visit Official Source'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}