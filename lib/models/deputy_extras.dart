class DeputyExtras {
  DeputyExtras({
    required this.pros,
    required this.cons,
    required this.news,
    required this.rating,
    required this.cleanRecord,
    required this.score,
    required this.votesReceived,
    required this.tweets,
  });

  final List<String> pros;
  final List<String> cons;
  final List<NewsItem> news;
  final double rating;
  final bool cleanRecord;
  final int score;
  final int votesReceived;
  final List<String> tweets;

  static DeputyExtras fromJson(Map<String, dynamic> json) {
    final newsList = (json['news'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NewsItem.fromJson)
        .toList();

    return DeputyExtras(
      pros: (json['pros'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      cons: (json['cons'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      news: newsList,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      cleanRecord: (json['cleanRecord'] as bool?) ?? false,
      score: (json['score'] as num?)?.toInt() ?? 0,
      votesReceived: (json['votesReceived'] as num?)?.toInt() ?? 0,
      tweets: (json['tweets'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
    );
  }
}

class NewsItem {
  NewsItem({
    required this.title,
    required this.source,
    required this.imageUrl,
    this.url,
    this.description,
  });

  final String title;
  final String source;
  final String imageUrl;
  final String? url;
  final String? description;

  static NewsItem fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: (json['title'] ?? '') as String,
      source: (json['source'] ?? '') as String,
      imageUrl: (json['imageUrl'] ?? '') as String,
      url: json['url'] as String?,
      description: json['description'] as String?,
    );
  }
}
