import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/deputy_extras.dart';

class NewsService {
  NewsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _rssUrl =
      'https://www.camara.leg.br/noticias/rss/ultimas-noticias';

  Future<List<NewsItem>> fetchAllNews() async {
    final response = await _client.get(Uri.parse(_rssUrl));
    if (response.statusCode != 200) {
      return [];
    }
    final document = XmlDocument.parse(response.body);
    final items = document.findAllElements('item');
    return items.map((item) {
      final title = item.getElement('title')?.innerText ?? '';
      final description = item.getElement('description')?.innerText ?? '';
      final link = item.getElement('link')?.innerText ?? '';
      return NewsItem(
        title: title,
        source: 'Agência Câmara',
        imageUrl: '',
        url: link,
        description: description,
      );
    }).where((item) => item.title.isNotEmpty).toList();
  }

  List<NewsItem> filterByQuery(List<NewsItem> items, String query) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) {
      return items;
    }
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return items.where((item) {
      final haystack =
          '${item.title} ${item.description ?? ''}'.toLowerCase();
      return tokens.any(haystack.contains);
    }).toList();
  }
}
