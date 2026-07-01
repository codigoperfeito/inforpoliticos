import 'package:mobx/mobx.dart';

import '../models/senator.dart';
import '../services/senate_api.dart';
import '../utils/text_utils.dart';

class SenatorsStore {
  SenatorsStore({SenateApi? api}) : api = api ?? SenateApi();

  final SenateApi api;

  final Observable<bool> loading = Observable(false);
  final Observable<String?> errorMessage = Observable(null);
  final Observable<List<Senator>> senators = Observable(<Senator>[]);
  final Observable<String> query = Observable('');
  final Observable<String?> selectedUf = Observable(null);
  final Observable<String?> selectedParty = Observable(null);

  Future<void> load() async {
    if (loading.value) return;
    runInAction(() {
      loading.value = true;
      errorMessage.value = null;
    });
    try {
      final data = await api.fetchSenators();
      runInAction(() {
        senators.value = data;
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
    senators.value = [];
    load();
  }

  void setInitialUf(String? value) {
    selectedUf.value = value;
  }

  void setQuery(String value) {
    query.value = value;
  }

  void setSelectedUf(String? value) {
    selectedUf.value = value;
  }

  void setSelectedParty(String? value) {
    selectedParty.value = value;
  }

  void clearFilters() {
    selectedUf.value = null;
    selectedParty.value = null;
  }

  List<Senator> get filteredSenators {
    final normalizedQuery = normalizeText(query.value);
    return senators.value.where((senator) {
      if (selectedUf.value != null && selectedUf.value != senator.uf) {
        return false;
      }
      if (selectedParty.value != null && selectedParty.value != senator.party) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final name = normalizeText(senator.displayName);
      final party = normalizeText(senator.party);
      final uf = senator.uf.toLowerCase();
      return name.contains(normalizedQuery) ||
          party.contains(normalizedQuery) ||
          uf.contains(normalizedQuery);
    }).toList();
  }

  List<String> get parties {
    final list = senators.value
        .map((d) => d.party)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return list;
  }

  List<String> get ufs {
    final list = senators.value
        .map((d) => d.uf)
        .where((uf) => uf.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return list;
  }
}
