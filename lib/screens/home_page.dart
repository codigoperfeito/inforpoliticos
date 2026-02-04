import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/deputy.dart';
import '../services/deputy_repository.dart';
import 'deputy_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.initialUf,
  });

  final String? initialUf;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = DeputyRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();
  late Future<RepositoryResult<List<Deputy>>> _future;
  String _query = '';
  String? _selectedRegion;
  String? _selectedUf;
  String? _selectedParty;
  int _visibleCount = _pageSize;
  int _currentTotal = 0;
  double _lastScrollOffset = 0;

  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _future = _repository.getDeputies();
    _selectedUf = widget.initialUf;
    if (widget.initialUf != null) {
      _selectedRegion = _regionByUf[widget.initialUf!];
    }
    _listController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repository.getDeputies();
      _visibleCount = _pageSize;
    });
  }

  void _resetSearch() {
    setState(() {
      _query = '';
      _selectedRegion = null;
      _selectedUf = null;
      _selectedParty = null;
      _visibleCount = _pageSize;
    });
    _searchController.clear();
  }

  void _onScroll() {
    _lastScrollOffset = _listController.offset;
    if (_listController.position.pixels >
        _listController.position.maxScrollExtent - 240) {
      if (_visibleCount < _currentTotal) {
        setState(() {
          _visibleCount =
              (_visibleCount + _pageSize).clamp(0, _currentTotal);
        });
      }
    }
  }

  void _restoreScroll() {
    if (!_listController.hasClients) {
      return;
    }
    final max = _listController.position.maxScrollExtent;
    final target = _lastScrollOffset.clamp(0.0, max);
    if (target == _listController.offset) {
      return;
    }
    _listController.jumpTo(target);
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Sem cache';
    }
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InfoPoliticos'),
      ),
      body: FutureBuilder<RepositoryResult<List<Deputy>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: _reload);
          }
          final result = snapshot.data;
          if (result == null || result.data.isEmpty) {
            return _EmptyState(onRetry: _reload);
          }
          final items = result.data.where((deputy) {
            final query = _normalize(_query);
            if (query.isEmpty) {
              return _matchesFilters(deputy);
            }
            final name = _normalize(deputy.displayName);
            final party = _normalize(deputy.party);
            final uf = deputy.uf.toLowerCase();
            final matchesQuery =
                name.contains(query) || party.contains(query) || uf.contains(query);
            return matchesQuery && _matchesFilters(deputy);
          }).toList();
          _currentTotal = items.length;
          if (_visibleCount > _currentTotal) {
            _visibleCount = _currentTotal;
          }
          final visibleItems = items.take(_visibleCount).toList();
          final grouped = _groupByRegion(visibleItems);
          WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              controller: _listController,
              padding: const EdgeInsets.all(16),
              children: [
                _SearchField(
                  options: result.data.map((d) => d.displayName).toList(),
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _query = value;
                    _visibleCount = _pageSize;
                  }),
                  onSelected: (value) => setState(() {
                    _query = value;
                    _visibleCount = _pageSize;
                  }),
                ),
                const SizedBox(height: 12),
                _UfShortcutRow(
                  onSelect: (uf) {
                    setState(() {
                      _selectedUf = uf;
                      _selectedRegion = _regionByUf[uf];
                    });
                  },
                ),
                const SizedBox(height: 12),
                _FilterPanel(
                  regions: _regions,
                  ufs: _ufs,
                  parties: _parties(result.data),
                  selectedRegion: _selectedRegion,
                  selectedUf: _selectedUf,
                  selectedParty: _selectedParty,
                  onRegionChanged: (value) => setState(() {
                    _selectedRegion = value;
                    _visibleCount = _pageSize;
                  }),
                  onUfChanged: (value) => setState(() {
                    _selectedUf = value;
                    _visibleCount = _pageSize;
                  }),
                  onPartyChanged: (value) => setState(() {
                    _selectedParty = value;
                    _visibleCount = _pageSize;
                  }),
                  onClear: () => setState(() {
                    _selectedRegion = null;
                    _selectedUf = null;
                    _selectedParty = null;
                    _visibleCount = _pageSize;
                  }),
                ),
                const SizedBox(height: 12),
                _CacheBanner(
                  fromCache: result.fromCache,
                  lastUpdated: result.lastUpdated,
                  formattedDate: _formatDate(result.lastUpdated),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  _EmptyState(onRetry: _reload)
                else
                  for (final entry in grouped.entries) ...[
                    _SectionHeader(title: entry.key),
                    for (final deputy in entry.value)
                      _DeputyCard(
                        deputy: deputy,
                        onTap: () async {
                          final reset = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DeputyDetailPage(deputyId: deputy.id),
                            ),
                          );
                          if (reset == true) {
                            _resetSearch();
                          }
                        },
                      ),
                  ],
                if (_visibleCount < _currentTotal)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _visibleCount =
                                  (_visibleCount + _pageSize).clamp(
                                    0,
                                    _currentTotal,
                                  );
                            });
                          },
                          icon: const Icon(Icons.expand_more),
                          label: Text('Carregar mais (${_visibleCount}/$_currentTotal)'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilters(Deputy deputy) {
    final region = _regionByUf[deputy.uf] ?? 'Outros';
    if (_selectedRegion != null && _selectedRegion != region) {
      return false;
    }
    if (_selectedUf != null && _selectedUf != deputy.uf) {
      return false;
    }
    if (_selectedParty != null && _selectedParty != deputy.party) {
      return false;
    }
    return true;
  }

  String _normalize(String value) {
    var text = value.toLowerCase();
    const map = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    map.forEach((key, replacement) {
      text = text.replaceAll(key, replacement);
    });
    return text;
  }

  Map<String, List<Deputy>> _groupByRegion(List<Deputy> items) {
    final map = <String, List<Deputy>>{};
    for (final deputy in items) {
      final region = _regionByUf[deputy.uf] ?? 'Outros';
      map.putIfAbsent(region, () => []).add(deputy);
    }
    return map;
  }

  List<String> _parties(List<Deputy> items) {
    final set = items.map((d) => d.party).where((p) => p.isNotEmpty).toSet();
    final list = set.toList()..sort();
    return list;
  }

}

const _regions = [
  'Norte',
  'Nordeste',
  'Centro-Oeste',
  'Sudeste',
  'Sul',
  'Outros',
];

const _ufs = [
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
];

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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.regions,
    required this.ufs,
    required this.parties,
    required this.selectedRegion,
    required this.selectedUf,
    required this.selectedParty,
    required this.onRegionChanged,
    required this.onUfChanged,
    required this.onPartyChanged,
    required this.onClear,
  });

  final List<String> regions;
  final List<String> ufs;
  final List<String> parties;
  final String? selectedRegion;
  final String? selectedUf;
  final String? selectedParty;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<String?> onUfChanged;
  final ValueChanged<String?> onPartyChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        selectedRegion != null || selectedUf != null || selectedParty != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filtros rápidos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (hasFilter)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Limpar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _FilterChips(
              title: 'Região',
              items: regions,
              selected: selectedRegion,
              onChanged: onRegionChanged,
            ),
            const SizedBox(height: 8),
            _FilterChips(
              title: 'UF',
              items: ufs,
              selected: selectedUf,
              onChanged: onUfChanged,
            ),
            const SizedBox(height: 8),
            _FilterChips(
              title: 'Partido',
              items: parties,
              selected: selectedParty,
              onChanged: onPartyChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _UfShortcutRow extends StatelessWidget {
  const _UfShortcutRow({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleção rápida de UF',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['RJ', 'SP', 'MG', 'BA', 'RS', 'PE'].map((uf) {
                return InkWell(
                  onTap: () => onSelect(uf),
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        uf,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.title,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> items;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final selectedChip = selected == item;
            return ChoiceChip(
              label: Text(item),
              selected: selectedChip,
              onSelected: (value) => onChanged(value ? item : null),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.options,
    required this.controller,
    required this.onChanged,
    required this.onSelected,
  });

  final List<String> options;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  TextEditingController? _attachedController;
  bool _isAutoCompleting = false;

  void _attach(TextEditingController controller) {
    if (_attachedController == controller) {
      return;
    }
    _attachedController?.removeListener(_onChange);
    _attachedController = controller;
    _attachedController?.addListener(_onChange);
  }

  void _onChange() {
    if (_isAutoCompleting) {
      return;
    }
    final controller = _attachedController;
    if (controller == null) {
      return;
    }
    final raw = controller.text;
    final query = _normalize(raw.trim());
    if (query.isEmpty) {
      setState(() {});
      return;
    }
    final match = widget.options.firstWhere(
      (name) => _normalize(name).startsWith(query),
      orElse: () => '',
    );
    if (match.isNotEmpty && match.toLowerCase() != raw.toLowerCase()) {
      _isAutoCompleting = true;
      controller.value = TextEditingValue(
        text: match,
        selection: TextSelection(
          baseOffset: raw.length,
          extentOffset: match.length,
        ),
      );
      _isAutoCompleting = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _attachedController?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fontSize = 16.0;
    return Autocomplete<String>(
      optionsBuilder: (value) {
        final query = _normalize(value.text.trim());
        if (query.isEmpty) {
          return const Iterable<String>.empty();
        }
        final starts = widget.options
            .where((name) => _normalize(name).startsWith(query));
        final contains = widget.options
            .where((name) =>
                !starts.contains(name) && _normalize(name).contains(query));
        return [...starts, ...contains].take(8);
      },
      onSelected: (value) {
        _attachedController?.text = value;
        widget.onSelected(value);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _attach(widget.controller);
        return TextField(
          controller: widget.controller,
          focusNode: focusNode,
          onChanged: widget.onChanged,
          style: const TextStyle(fontSize: fontSize),
          decoration: InputDecoration(
            hintText: 'Buscar por nome, partido ou UF',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelectedOption, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 240,
                maxWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    hoverColor: Colors.blueGrey.withValues(alpha: 0.12),
                    onTap: () => onSelectedOption(option),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        option,
                        style: const TextStyle(fontSize: fontSize),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _normalize(String value) {
    var text = value.toLowerCase();
    const map = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    map.forEach((key, replacement) {
      text = text.replaceAll(key, replacement);
    });
    return text;
  }
}

class _CacheBanner extends StatelessWidget {
  const _CacheBanner({
    required this.fromCache,
    required this.lastUpdated,
    required this.formattedDate,
  });

  final bool fromCache;
  final DateTime? lastUpdated;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    final color = fromCache ? Colors.amber.shade100 : Colors.green.shade100;
    final text = fromCache
        ? 'Modo offline: exibindo cache ($formattedDate).'
        : 'Dados atualizados em $formattedDate.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            fromCache ? Icons.cloud_off : Icons.cloud_done,
            color: Colors.black87,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeputyCard extends StatelessWidget {
  const _DeputyCard({required this.deputy, required this.onTap});

  final Deputy deputy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade200,
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: deputy.photoUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const SizedBox(width: 56, height: 56, child: Icon(Icons.person)),
              errorWidget: (context, url, error) =>
                  const SizedBox(width: 56, height: 56, child: Icon(Icons.person)),
            ),
          ),
        ),
        title: Text(
          deputy.displayName,
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E4A7A),
            fontSize: 16,
          ),
        ),
        subtitle: Text('${deputy.party} • ${deputy.uf}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar os dados agora.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Nenhum deputado encontrado.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
