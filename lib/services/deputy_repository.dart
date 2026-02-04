import '../models/deputy.dart';
import '../models/proposition.dart';
import '../models/voting.dart';
import 'cache_store.dart';
import 'camara_api.dart';

class RepositoryResult<T> {
  RepositoryResult({
    required this.data,
    required this.fromCache,
    this.lastUpdated,
  });

  final T data;
  final bool fromCache;
  final DateTime? lastUpdated;
}

class DeputyRepository {
  DeputyRepository({
    CamaraApi? api,
    CacheStore? cache,
  })  : _api = api ?? CamaraApi(),
        _cache = cache ?? const CacheStore();

  final CamaraApi _api;
  final CacheStore _cache;

  static const _listKey = 'deputies_list';

  Future<RepositoryResult<List<Deputy>>> getDeputies() async {
    try {
      final data = await _api.fetchDeputies();
      await _cache.writeJson(
        _listKey,
        {
          'items': data.map((item) => item.toJson()).toList(),
        },
      );
      final lastUpdated = await _cache.lastUpdated(_listKey);
      return RepositoryResult(
        data: data,
        fromCache: false,
        lastUpdated: lastUpdated,
      );
    } catch (_) {
      final cached = await _cache.readJson(_listKey);
      if (cached != null) {
        final items = (cached['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Deputy.fromCacheJson)
            .toList();
        return RepositoryResult(
          data: items,
          fromCache: true,
          lastUpdated: await _cache.lastUpdated(_listKey),
        );
      }
      rethrow;
    }
  }

  Future<RepositoryResult<Deputy>> getDeputyDetail(int id) async {
    final key = 'deputy_$id';
    try {
      final data = await _api.fetchDeputyDetail(id);
      await _cache.writeJson(key, {'item': data.toJson()});
      return RepositoryResult(
        data: data,
        fromCache: false,
        lastUpdated: await _cache.lastUpdated(key),
      );
    } catch (_) {
      final cached = await _cache.readJson(key);
      if (cached != null) {
        final item = cached['item'] as Map<String, dynamic>? ?? {};
        return RepositoryResult(
          data: Deputy.fromCacheJson(item),
          fromCache: true,
          lastUpdated: await _cache.lastUpdated(key),
        );
      }
      rethrow;
    }
  }

  Future<RepositoryResult<List<Proposition>>> getPropositions(
    int id, {
    int page = 1,
    int items = 10,
  }) async {
    final key = 'propositions_${id}_page_$page';
    try {
      final data = await _api.fetchPropositions(id, page: page, items: items);
      final filtered =
          data.where((item) => item.summary.trim().isNotEmpty).toList();
      await _cache.writeJson(
        key,
        {
          'items': filtered.map((item) => item.toJson()).toList(),
        },
      );
      return RepositoryResult(
        data: filtered,
        fromCache: false,
        lastUpdated: await _cache.lastUpdated(key),
      );
    } catch (_) {
      final cached = await _cache.readJson(key);
      if (cached != null) {
        final items = (cached['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Proposition.fromCacheJson)
            .toList();
        return RepositoryResult(
          data: items,
          fromCache: true,
          lastUpdated: await _cache.lastUpdated(key),
        );
      }
      rethrow;
    }
  }

  Future<Proposition> getPropositionDetail(int id) {
    return _api.fetchPropositionDetail(id);
  }

  Future<String?> getPropositionAuthor(int id) {
    return _api.fetchPropositionAuthor(id);
  }

  Future<List<Voting>> getPropositionVotacoes(int propositionId) {
    return _api.fetchPropositionVotacoes(propositionId);
  }

  Future<List<DeputyVote>> getVotingVotes(String votingId) {
    return _api.fetchVotingVotes(votingId);
  }

  Future<List<Voting>> getRecentVotacoes({
    int items = 5,
    int page = 1,
  }) {
    return _api.fetchRecentVotacoes(items: items, page: page);
  }

  Future<String?> getVotingEmenta(String votingId) {
    return _api.fetchVotingEmentaXml(votingId);
  }
}
