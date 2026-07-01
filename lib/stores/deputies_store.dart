import 'package:mobx/mobx.dart';

import '../models/deputy.dart';
import '../services/deputy_repository.dart';
import '../utils/text_utils.dart';

class DeputiesStore {
  DeputiesStore({DeputyRepository? repository})
      : repository = repository ?? DeputyRepository();

  final DeputyRepository repository;

  final Observable<bool> loading = Observable(false);
  final Observable<String?> errorMessage = Observable(null);
  final Observable<RepositoryResult<List<Deputy>>?> result = Observable(null);
  final Observable<String> query = Observable('');
  final Observable<String?> selectedRegion = Observable(null);
  final Observable<String?> selectedUf = Observable(null);
  final Observable<String?> selectedParty = Observable(null);
  final Observable<int> visibleCount = Observable(_pageSize);

  static const int _pageSize = 30;

  Future<void> load() async {
    if (loading.value) return;
    runInAction(() {
      loading.value = true;
      errorMessage.value = null;
    });
    try {
      final data = await repository.getDeputies();
      runInAction(() {
        result.value = data;
      });
    } catch (error) {
      runInAction(() {
        errorMessage.value = error.toString();
      });
    } finally {
      runInAction(() {
        loading.value = false;
      });
    }
  }

  void reload() {
    result.value = null;
    visibleCount.value = _pageSize;
    load();
  }

  void resetSearch() {
    query.value = '';
    selectedRegion.value = null;
    selectedUf.value = null;
    selectedParty.value = null;
    visibleCount.value = _pageSize;
  }

  void setQuery(String value) {
    query.value = value;
    visibleCount.value = _pageSize;
  }

  void setSelectedRegion(String? value) {
    selectedRegion.value = value;
    visibleCount.value = _pageSize;
  }

  void setSelectedUf(String? value) {
    selectedUf.value = value;
    visibleCount.value = _pageSize;
    if (value != null) {
      selectedRegion.value = _regionByUf[value];
    }
  }

  void setSelectedParty(String? value) {
    selectedParty.value = value;
    visibleCount.value = _pageSize;
  }

  void clearFilters() {
    selectedRegion.value = null;
    selectedUf.value = null;
    selectedParty.value = null;
    visibleCount.value = _pageSize;
  }

  void loadMoreVisible() {
    final total = filteredItems.length;
    if (visibleCount.value < total) {
      visibleCount.value = (visibleCount.value + _pageSize).clamp(0, total);
    }
  }

  List<Deputy> get allItems => result.value?.data ?? const [];

  bool get hasError => errorMessage.value != null;

  List<Deputy> get filteredItems {
    final items = allItems.where((deputy) {
      if (!_matchesFilters(deputy)) {
        return false;
      }
      final normalizedQuery = normalizeText(query.value);
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final name = normalizeText(deputy.displayName);
      final party = normalizeText(deputy.party);
      final uf = deputy.uf.toLowerCase();
      return name.contains(normalizedQuery) ||
          party.contains(normalizedQuery) ||
          uf.contains(normalizedQuery);
    }).toList();
    return items;
  }

  List<Deputy> get visibleItems =>
      filteredItems.take(visibleCount.value).toList();

  Map<String, List<Deputy>> get groupedVisibleItems {
    final map = <String, List<Deputy>>{};
    for (final deputy in visibleItems) {
      final region = _regionByUf[deputy.uf] ?? 'Outros';
      map.putIfAbsent(region, () => []).add(deputy);
    }
    return map;
  }

  List<String> get parties {
    final list = allItems
        .map((d) => d.party)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return list;
  }

  int get totalCount => filteredItems.length;

  bool _matchesFilters(Deputy deputy) {
    final region = _regionByUf[deputy.uf] ?? 'Outros';
    if (selectedRegion.value != null &&
        selectedRegion.value != region) {
      return false;
    }
    if (selectedUf.value != null && selectedUf.value != deputy.uf) {
      return false;
    }
    if (selectedParty.value != null && selectedParty.value != deputy.party) {
      return false;
    }
    return true;
  }
}

const _regionByUf = {
  'AC': 'Norte',
  'AP': 'Norte',
  'AM': 'Norte',
  'PA': 'Norte',
  'RO': 'Norte',
  'RR': 'Norte',
  'TO': 'Norte',
  'AL': 'Nordeste',
  'BA': 'Nordeste',
  'CE': 'Nordeste',
  'MA': 'Nordeste',
  'PB': 'Nordeste',
  'PE': 'Nordeste',
  'PI': 'Nordeste',
  'RN': 'Nordeste',
  'SE': 'Nordeste',
  'DF': 'Centro-Oeste',
  'GO': 'Centro-Oeste',
  'MT': 'Centro-Oeste',
  'MS': 'Centro-Oeste',
  'ES': 'Sudeste',
  'MG': 'Sudeste',
  'RJ': 'Sudeste',
  'SP': 'Sudeste',
  'PR': 'Sul',
  'RS': 'Sul',
  'SC': 'Sul',
};
