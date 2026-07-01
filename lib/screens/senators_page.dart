import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../models/senator.dart';
import '../stores/senators_store.dart';
import '../utils/text_utils.dart';
import 'senator_detail_page.dart';

class SenatorsPage extends StatefulWidget {
  const SenatorsPage({super.key, this.initialUf});

  final String? initialUf;

  @override
  State<SenatorsPage> createState() => _SenatorsPageState();
}

class _SenatorsPageState extends State<SenatorsPage> {
  late final SenatorsStore _store;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    _store = SenatorsStore();
    _store.setInitialUf(widget.initialUf);
    _store.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _store.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final loading = _store.loading.value;
        final error = _store.errorMessage.value;
        final items = _store.filteredSenators;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Senadores'),
            actions: [
              IconButton(
                tooltip: 'Atualizar',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: loading && _store.senators.value.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    controller: _listController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (error != null && _store.senators.value.isEmpty)
                        _ErrorState(
                          message: error,
                          onRetry: _reload,
                        )
                      else ...[
                        _SearchField(
                          options: _store.senators.value
                              .map((d) => d.displayName)
                              .toList(),
                          controller: _searchController,
                          onChanged: _store.setQuery,
                          onSelected: _store.setQuery,
                        ),
                        const SizedBox(height: 12),
                        _FilterPanel(
                          ufs: _ufs,
                          parties: _store.parties,
                          selectedUf: _store.selectedUf.value,
                          selectedParty: _store.selectedParty.value,
                          onUfChanged: _store.setSelectedUf,
                          onPartyChanged: _store.setSelectedParty,
                          onClear: _store.clearFilters,
                        ),
                        const SizedBox(height: 12),
                        if (items.isEmpty)
                          _EmptyState(onRetry: _reload)
                        else
                          for (final senator in items)
                            _SenatorCard(
                              senator: senator,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SenatorDetailPage(
                                      senatorId: senator.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

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


class _SearchField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (value) {
        final query = normalizeText(value.text.trim());
        if (query.isEmpty) {
          return const Iterable<String>.empty();
        }
        final starts = options.where((name) => normalizeText(name).startsWith(query));
        final contains = options.where(
          (name) => !starts.contains(name) && normalizeText(name).contains(query),
        );
        return [...starts, ...contains].take(8);
      },
      onSelected: (value) {
        controller.text = value;
        onSelected(value);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: (_) => onFieldSubmitted(),
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
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelectedOption(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.ufs,
    required this.parties,
    required this.selectedUf,
    required this.selectedParty,
    required this.onUfChanged,
    required this.onPartyChanged,
    required this.onClear,
  });

  final List<String> ufs;
  final List<String> parties;
  final String? selectedUf;
  final String? selectedParty;
  final ValueChanged<String?> onUfChanged;
  final ValueChanged<String?> onPartyChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilter = selectedUf != null || selectedParty != null;
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
                  'Filtros',
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

class _SenatorCard extends StatelessWidget {
  const _SenatorCard({required this.senator, required this.onTap});

  final Senator senator;
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
              imageUrl: senator.photoUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.person),
              ),
              errorWidget: (context, url, error) => const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
        title: Text(
          senator.displayName,
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E4A7A),
            fontSize: 16,
          ),
        ),
        subtitle: Text('${senator.party} • ${senator.uf}'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

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
              'Nao foi possivel carregar os dados agora.',
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
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
              'Nenhum senador encontrado.',
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
