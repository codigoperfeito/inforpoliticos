import 'package:flutter/material.dart';
import '../models/senator.dart';
import '../models/senator_ceaps.dart';
import '../services/senate_api.dart';

class SenatorDetailPage extends StatefulWidget {
  const SenatorDetailPage({
    super.key,
    required this.senatorId,
    this.initialYear,
  });

  final int senatorId;
  final int? initialYear;

  @override
  State<SenatorDetailPage> createState() => _SenatorDetailPageState();
}

class _SenatorDetailPageState extends State<SenatorDetailPage> {
  final _api = SenateApi();
  late Future<Senator> _detailFuture;
  late Future<SenatorCeaps> _ceapsFuture;
  final ScrollController _expenseScrollController = ScrollController();
  late int _year;
  int _visibleExpenses = 20;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear ?? DateTime.now().year;
    _detailFuture = _api.fetchSenatorDetail(widget.senatorId);
    _ceapsFuture = _api.fetchSenatorCeaps(
      id: widget.senatorId,
      year: _year,
    );
    _expenseScrollController.addListener(_onExpenseScroll);
  }

  @override
  void dispose() {
    _expenseScrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _detailFuture = _api.fetchSenatorDetail(widget.senatorId);
      _ceapsFuture = _api.fetchSenatorCeaps(
        id: widget.senatorId,
        year: _year,
      );
      _visibleExpenses = _pageSize;
    });
  }

  void _onExpenseScroll() {
    if (!_expenseScrollController.hasClients) return;
    if (_expenseScrollController.position.pixels >
        _expenseScrollController.position.maxScrollExtent - 120) {
      setState(() {
        _visibleExpenses += _pageSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Senador'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Senator>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final senator = snapshot.data;
          if (senator == null) {
            return _ErrorState(onRetry: _reload);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(senator: senator),
              const SizedBox(height: 16),
              const _HousingBenefitCard(status: 'Indisponivel'),
              const SizedBox(height: 16),
              FutureBuilder<SenatorCeaps>(
                future: _ceapsFuture,
                builder: (context, ceapsSnapshot) {
                  if (ceapsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (ceapsSnapshot.hasError) {
                    return _ErrorState(
                      message: ceapsSnapshot.error.toString(),
                      onRetry: _reload,
                    );
                  }
                  final ceaps = ceapsSnapshot.data;
                  if (ceaps == null) {
                    return _ErrorState(onRetry: _reload);
                  }
                  final monthly = _calcMonthlyTotals(ceaps.expenses);
                  final imovel = _filterImovelExpenses(ceaps.expenses);
                  final top5 = _topExpenses(ceaps.expenses, 5);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _YearChips(
                        selectedYear: _year,
                        onChanged: (value) {
                          setState(() {
                            _year = value;
                            _ceapsFuture = _api.fetchSenatorCeaps(
                              id: widget.senatorId,
                              year: _year,
                            );
                            _visibleExpenses = _pageSize;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _CeapsSummary(ceaps: ceaps),
                      const SizedBox(height: 12),
                      _MonthlyChart(data: monthly),
                      const SizedBox(height: 12),
                      Text(
                        'Despesas com imovel',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (imovel.isEmpty)
                        const Text('Sem despesas de imovel no ano.'),
                      for (final item in imovel) _ExpenseTile(expense: item),
                      const SizedBox(height: 12),
                      Text(
                        'Principais gastos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (top5.isEmpty)
                        const Text(
                          'Nenhuma despesa encontrada para o ano selecionado.',
                        )
                      else
                        _TopExpensesList(
                          items: top5,
                          controller: _expenseScrollController,
                          visibleCount: _visibleExpenses,
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.senator});

  final Senator senator;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  senator.photoUrl.isNotEmpty ? NetworkImage(senator.photoUrl) : null,
              child: senator.photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 36)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senator.fullName?.isNotEmpty == true
                        ? senator.fullName!
                        : senator.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('${senator.party} • ${senator.uf}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearChips extends StatelessWidget {
  const _YearChips({
    required this.selectedYear,
    required this.onChanged,
  });

  final int selectedYear;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(6, (index) => currentYear - index);
    return Wrap(
      spacing: 8,
      children: years.map((year) {
        return ChoiceChip(
          label: Text(year.toString()),
          selected: year == selectedYear,
          onSelected: (_) => onChanged(year),
        );
      }).toList(),
    );
  }
}

class _CeapsSummary extends StatelessWidget {
  const _CeapsSummary({required this.ceaps});

  final SenatorCeaps ceaps;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: const Text('Total gasto (CEAPS)'),
        subtitle: Text('R\$ ${ceaps.total.toStringAsFixed(2)}'),
      ),
    );
  }
}

class _HousingBenefitCard extends StatelessWidget {
  const _HousingBenefitCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.home_work_outlined),
        title: const Text('Auxilio-moradia'),
        subtitle: Text(status),
      ),
    );
  }
}

class _ExpenseTile extends StatefulWidget {
  const _ExpenseTile({required this.expense});

  final dynamic expense;

  @override
  State<_ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<_ExpenseTile>
    with TickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final description = expense.description.isNotEmpty
        ? expense.description
        : 'Despesa';
    final icon = _expenseIcon(expense);
    final iconColor = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(bottom: 10, top: _expanded ? 2 : 0),
      transform: Matrix4.translationValues(0, _expanded ? -2 : 0, 0),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: _expanded ? 6 : 1,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                              child: Text(description),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _expenseCategoryLabel(expense),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            expense.amount != null
                                ? 'R\$ ${expense.amount!.toStringAsFixed(2)}'
                                : 'R\$ -',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: !_expanded
                        ? const SizedBox.shrink()
                        : Padding(
                            key: const ValueKey('details'),
                            padding: const EdgeInsets.only(top: 12, left: 56),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (expense.supplier.isNotEmpty)
                                  _ExpenseInfoRow(
                                    icon: Icons.storefront_outlined,
                                    label: expense.supplier,
                                  ),
                                if (expense.cnpjCpf.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _ExpenseInfoRow(
                                    icon: Icons.badge_outlined,
                                    label: expense.cnpjCpf,
                                  ),
                                ],
                                if (expense.date.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _ExpenseInfoRow(
                                    icon: Icons.calendar_month_outlined,
                                    label: expense.date,
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseInfoRow extends StatelessWidget {
  const _ExpenseInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }
}

class _TopExpensesList extends StatelessWidget {
  const _TopExpensesList({
    required this.items,
    required this.controller,
    required this.visibleCount,
  });

  final List<dynamic> items;
  final ScrollController controller;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final count = visibleCount < items.length ? visibleCount : items.length;
    return SizedBox(
      height: 360,
      child: ListView.builder(
        controller: controller,
        itemCount: count + 1,
        itemBuilder: (context, index) {
          if (index == count) {
            if (count >= items.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Fim dos gastos do ano.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = items[index];
          return _ExpenseTile(expense: item);
        },
      ),
    );
  }
}

Map<String, double> _calcMonthlyTotals(List<dynamic> items) {
  final grouped = <String, double>{};
  for (final item in items) {
    final month = _monthLabel(_extractMonth(item.date as String?));
    final amount = (item.amount as num?)?.toDouble() ?? 0;
    grouped[month] = (grouped[month] ?? 0) + amount;
  }
  return grouped;
}

List<dynamic> _topExpenses(List<dynamic> items, int limit) {
  final sorted = [...items];
  sorted.sort((a, b) {
    final av = (a.amount as num?)?.toDouble() ?? 0;
    final bv = (b.amount as num?)?.toDouble() ?? 0;
    return bv.compareTo(av);
  });
  return sorted;
}

List<dynamic> _filterImovelExpenses(List<dynamic> items) {
  return items.where((item) {
    final description = (item.description as String?)?.toLowerCase() ?? '';
    return description.contains('imovel') ||
        description.contains('imóvel') ||
        description.contains('imovel funcional') ||
        description.contains('imóvel funcional');
  }).toList();
}

IconData _expenseIcon(dynamic expense) {
  final raw = _expenseText(expense).toLowerCase();
  if (raw.contains('passagem') ||
      raw.contains('transporte') ||
      raw.contains('locomo') ||
      raw.contains('combust')) {
    return Icons.directions_car_filled_outlined;
  }
  if (raw.contains('aluguel') ||
      raw.contains('imovel') ||
      raw.contains('imóvel') ||
      raw.contains('hospedagem') ||
      raw.contains('hotel')) {
    return Icons.home_work_outlined;
  }
  if (raw.contains('consultoria') ||
      raw.contains('assessoria') ||
      raw.contains('serviço') ||
      raw.contains('servico')) {
    return Icons.work_outline;
  }
  if (raw.contains('aliment') ||
      raw.contains('refeição') ||
      raw.contains('restaurante') ||
      raw.contains('café')) {
    return Icons.restaurant_outlined;
  }
  if (raw.contains('telefone') ||
      raw.contains('internet') ||
      raw.contains('comunica')) {
    return Icons.phone_iphone_outlined;
  }
  if (raw.contains('passagem aérea') ||
      raw.contains('passagem aerea') ||
      raw.contains('aéreo') ||
      raw.contains('aereo')) {
    return Icons.flight_outlined;
  }
  return Icons.receipt_long_outlined;
}

String _expenseCategoryLabel(dynamic expense) {
  final raw = _expenseText(expense).toLowerCase();
  if (raw.contains('imovel') || raw.contains('imóvel')) return 'Imóvel / moradia';
  if (raw.contains('passagem') || raw.contains('transporte')) return 'Transporte';
  if (raw.contains('aliment') || raw.contains('restaurante')) return 'Alimentação';
  if (raw.contains('consultoria') || raw.contains('assessoria')) return 'Serviços';
  if (raw.contains('telefone') || raw.contains('internet')) return 'Comunicação';
  return 'Despesa registrada';
}

String _expenseText(dynamic expense) {
  final parts = <String>[
    if ((expense.description as String?)?.isNotEmpty == true)
      expense.description as String,
    if ((expense.supplier as String?)?.isNotEmpty == true)
      expense.supplier as String,
    if ((expense.cnpjCpf as String?)?.isNotEmpty == true)
      expense.cnpjCpf as String,
    if ((expense.date as String?)?.isNotEmpty == true)
      expense.date as String,
  ];
  return parts.join(' ').trim();
}

String _monthLabel(int? month) {
  const labels = {
    1: 'Jan',
    2: 'Fev',
    3: 'Mar',
    4: 'Abr',
    5: 'Mai',
    6: 'Jun',
    7: 'Jul',
    8: 'Ago',
    9: 'Set',
    10: 'Out',
    11: 'Nov',
    12: 'Dez',
  };
  if (month == null || month < 1 || month > 12) {
    return 'Outros';
  }
  return labels[month] ?? 'Outros';
}

int? _extractMonth(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final normalized = raw.replaceAll('/', '-');
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) return parsed.month;
  final parts = normalized.split('-');
  if (parts.length >= 2) {
    final month = int.tryParse(parts[1]);
    if (month != null) return month;
  }
  return null;
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.data});

  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    final ordered = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
      'Outros',
    ];
    final entries = ordered
        .where((key) => data.containsKey(key))
        .map((key) => MapEntry(key, data[key] ?? 0))
        .toList();
    final max = entries.isEmpty
        ? 1.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastos por mes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Column(
          children: entries.map((entry) {
            final ratio = (entry.value / max).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'R\$ ${entry.value.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
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
