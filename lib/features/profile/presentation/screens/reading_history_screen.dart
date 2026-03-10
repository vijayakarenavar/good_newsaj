import 'package:flutter/material.dart';
import 'package:good_news/core/services/user_service.dart';
import '../../../articles/presentation/screens/article_detail_screen.dart';

class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  List<Map<String, dynamic>> _historyArticles = [];
  bool _isLoading = true;
  int _totalReadsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      // ✅ getHistory() आता feed मधून image_url + source_url enrich करतो
      final history = await UserService.getHistory();
      if (mounted) {
        setState(() {
          _historyArticles = history;
          _totalReadsCount = history.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyArticles = [];
          _totalReadsCount = 0;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load history: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: _loadHistory,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading History'),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyArticles.isEmpty
          ? _buildEmptyState(context)
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$_totalReadsCount article${_totalReadsCount != 1 ? 's' : ''} read',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadHistory,
              color: colorScheme.primary,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _historyArticles.length,
                itemBuilder: (context, index) {
                  final article = _historyArticles[index];
                  return _buildHistoryCard(article, colorScheme, textTheme);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80,
              color: colorScheme.onSurface.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('No reading history yet',
              style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text('Articles you read will appear here',
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7)),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.explore),
            label: const Text('Explore Articles'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
      Map<String, dynamic> article,
      ColorScheme colorScheme,
      TextTheme textTheme) {
    final summary = article['rewritten_summary'] ??
        article['summary'] ??
        article['content'] ??
        '';
    final displaySummary =
    (summary.isEmpty || summary == 'No summary available' || summary.length < 20)
        ? 'Tap "Read Again" to view this article.'
        : summary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: () => _openArticle(article),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      article['category'] ?? 'General',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(article['read_at']),
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                article['title'] ?? 'No Title',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
                ),
                child: Text(
                  displaySummary,
                  style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.8), height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Read ${_formatDate(article['read_at'])}',
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openArticle(article),
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Read Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FIXED: article AS-IS pass करतो — getHistory() ने आधीच
  // feed मधून image_url + source_url enrich केलेले असतात
  // त्यामुळे इथे कुठलाही rebuild/map करायची गरज नाही
  void _openArticle(Map<String, dynamic> article) {
    // ✅ Direct pass — कुठलेही fields strip होत नाहीत
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );

    // ✅ Background history entry (fire and forget)
    final rawId = article['id'] ?? article['article_id'];
    final articleId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');
    if (articleId != null) {
      UserService.addToHistoryWithNewEntry(articleId);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Recently';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Recently';
    }
  }
}