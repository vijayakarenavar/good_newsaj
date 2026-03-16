class ArticleModel {
  final int id;
  final String title;
  final String rewrittenHeadline;
  final String content;
  final String rewrittenSummary;
  final String sentiment;
  final String? imageUrl;
  final String? sourceUrl;
  final String? category;
  final int? categoryId;
  final String? createdAt;
  final bool isAiRewritten;

  ArticleModel({
    required this.id,
    required this.title,
    this.rewrittenHeadline = '',
    required this.content,
    this.rewrittenSummary = '',
    this.sentiment = 'POSITIVE',
    this.imageUrl,
    this.sourceUrl,
    this.category,
    this.categoryId,
    this.createdAt,
    this.isAiRewritten = false,
  });

  factory ArticleModel.fromMap(Map<String, dynamic> map) {
    return ArticleModel(
      id: map['id'] ?? 0,
      title: map['rewritten_headline'] ?? map['title'] ?? 'Untitled',
      rewrittenHeadline: map['rewritten_headline'] ?? '',
      content: map['content'] ?? map['rewritten_summary'] ?? '',
      rewrittenSummary: map['rewritten_summary'] ?? '',
      sentiment: map['sentiment'] ?? 'POSITIVE',
      imageUrl: map['image_url'],
      sourceUrl: map['source_url'],
      category: map['category'],
      categoryId: map['category_id'],
      createdAt: map['created_at'],
      isAiRewritten: map['is_ai_rewritten'] == true ||
          map['is_ai_rewritten'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': 'article',
      'id': id,
      'title': title,
      'rewritten_headline': rewrittenHeadline,
      'content': content,
      'rewritten_summary': rewrittenSummary,
      'sentiment': sentiment,
      'image_url': imageUrl,
      'source_url': sourceUrl,
      'category': category,
      'category_id': categoryId,
      'created_at': createdAt,
      'is_ai_rewritten': isAiRewritten,
    };
  }
}
