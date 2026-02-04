import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/deputy.dart';
import '../models/deputy_extras.dart';
import '../models/expense.dart';
import '../models/presence_stats.dart';
import '../models/proposition.dart';
import '../models/voting.dart';
import '../services/deputy_repository.dart';
import '../services/news_service.dart';
import '../services/summary_service.dart';
import '../services/parliament_activity_service.dart';

class DeputyDetailPage extends StatefulWidget {
  const DeputyDetailPage({super.key, required this.deputyId});

  final int deputyId;

  @override
  State<DeputyDetailPage> createState() => _DeputyDetailPageState();
}

class _DeputyDetailPageState extends State<DeputyDetailPage> {
  final _repository = DeputyRepository();
  final _newsService = NewsService();
  final _activityService = ParliamentActivityService();
  final ScrollController _approvedController = ScrollController();
  final ScrollController _pendingController = ScrollController();
  final ScrollController _expensesController = ScrollController();
  late Future<_HeaderBundle> _headerFuture;
  final List<Proposition> _approved = [];
  final List<Proposition> _pending = [];
  final Set<int> _loadedIds = {};
  final List<_RecentVoteItem> _recentVotes = [];
  bool _loadingRecentVotes = false;
  final List<ExpenseItem> _expenses = [];
  bool _expensesLoading = false;
  bool _expensesHasMore = true;
  int _expensesPage = 1;
  late int _expensesYear;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _expensesYear = DateTime.now().year;
    _headerFuture = _loadHeader();
    _approvedController.addListener(() => _onScroll(_approvedController));
    _pendingController.addListener(() => _onScroll(_pendingController));
    _expensesController.addListener(_onExpensesScroll);
    _loadMore();
    _loadExpenses(reset: true);
  }

  @override
  void dispose() {
    _approvedController.dispose();
    _pendingController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  Future<_HeaderBundle> _loadHeader() async {
    final detail = await _repository.getDeputyDetail(widget.deputyId);
    final presence = await _activityService.fetchPresence(widget.deputyId);
    final allNews = await _newsService.fetchAllNews();
    final deputyNews =
        _newsService.filterByQuery(allNews, detail.data.displayName);
    return _HeaderBundle(
      detail: detail,
      newsDeputy: deputyNews,
      presence: presence,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _headerFuture = _loadHeader();
      _approved.clear();
      _pending.clear();
      _loadedIds.clear();
      _recentVotes.clear();
      _expenses.clear();
      _expensesPage = 1;
      _expensesHasMore = true;
      _page = 1;
      _hasMore = true;
    });
    await _loadMore();
    await _loadExpenses(reset: true);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final result = await _repository.getPropositions(
        widget.deputyId,
        page: _page,
        items: _pageSize,
      );
      if (result.data.isEmpty) {
        _hasMore = false;
      } else {
        final detailed = await Future.wait(
          result.data.map((item) async {
            try {
              return await _repository.getPropositionDetail(item.id);
            } catch (_) {
              return item;
            }
          }),
        );
        for (final item in detailed) {
          if (_loadedIds.contains(item.id)) {
            continue;
          }
          _loadedIds.add(item.id);
          if (item.isApproved) {
            _approved.add(item);
          } else {
            _pending.add(item);
          }
        }
        _page += 1;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
    if (_recentVotes.isEmpty && mounted) {
      _loadRecentVotes();
    }
  }

  void _onScroll(ScrollController controller) {
    if (controller.position.pixels >
        controller.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  void _onExpensesScroll() {
    if (_expensesController.position.pixels >
        _expensesController.position.maxScrollExtent - 120) {
      _loadExpenses();
    }
  }


  Future<void> _loadExpenses({bool reset = false}) async {
    if (reset) {
      _expenses.clear();
      _expensesPage = 1;
      _expensesHasMore = true;
    }
    if (_expensesLoading || !_expensesHasMore) {
      return;
    }
    setState(() => _expensesLoading = true);
    try {
      final items = await _activityService.fetchExpenses(
        widget.deputyId,
        page: _expensesPage,
        items: 10,
        year: _expensesYear,
      );
      if (items.isEmpty) {
        _expensesHasMore = false;
      } else {
        _expenses.addAll(items);
        _expensesPage += 1;
      }
    } finally {
      if (mounted) {
        setState(() => _expensesLoading = false);
      }
    }
  }

  Future<void> _loadRecentVotes() async {
    if (_loadingRecentVotes) {
      return;
    }
    setState(() => _loadingRecentVotes = true);
    try {
      final candidates = [..._approved, ..._pending].take(10).toList();
      for (final proposition in candidates) {
        if (_recentVotes.length >= 5) {
          break;
        }
        final votacoes =
            await _repository.getPropositionVotacoes(proposition.id);
        if (votacoes.isEmpty) {
          continue;
        }
        votacoes.sort((a, b) {
          final da = DateTime.tryParse(a.dateTime) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse(b.dateTime) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        final latest = votacoes.first;
        final votos = await _repository.getVotingVotes(latest.id);
        final vote = votos.firstWhere(
          (item) => item.deputyId == widget.deputyId,
          orElse: () => DeputyVote(
            deputyId: widget.deputyId,
            vote: 'Sem voto registrado',
            name: '',
          ),
        );
        _recentVotes.add(
          _RecentVoteItem(
            proposition: proposition,
            voting: latest,
            vote: vote,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRecentVotes = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
      body: FutureBuilder<_HeaderBundle>(
        future: _headerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _DetailError(onRetry: _reload);
          }

          final bundle = snapshot.data!;
          final deputy = bundle.detail.data;

          final showApproved = _approved.isNotEmpty;

          return DefaultTabController(
            length: showApproved ? 2 : 1,
            key: ValueKey(showApproved),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 260,
                  toolbarHeight: 64,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final topPadding = MediaQuery.of(context).padding.top;
                      final collapsed =
                          constraints.biggest.height <= kToolbarHeight + topPadding + 12;
                      return FlexibleSpaceBar(
                        title: _OutlinedName(
                          text: deputy.displayName,
                          maxLines: 1,
                          fillColor: collapsed ? Colors.black : Colors.white,
                          strokeColor: collapsed ? Colors.white : Colors.black,
                        ),
                        background: SafeArea(
                          bottom: false,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: deputy.photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.black12,
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.black12,
                                  child: const Icon(Icons.person, size: 80),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusRow(deputy: deputy),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: CachedNetworkImage(
                                imageUrl: deputy.photoUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.black12,
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.black12,
                                  child: const Icon(Icons.person, size: 32),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                deputy.fullName?.isNotEmpty == true
                                    ? deputy.fullName!
                                    : deputy.displayName,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(label: deputy.party),
                            _InfoChip(label: deputy.uf),
                            _InfoChip(
                              label: deputy.isCurrent
                                  ? 'Em exercício'
                                  : 'Fora do exercício',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          title: 'Telefone',
                          value: deputy.phone?.isNotEmpty == true
                              ? deputy.phone!
                              : 'Não informado',
                        ),
                        _InfoRow(
                          title: 'E-mail',
                          value: deputy.email?.isNotEmpty == true
                              ? deputy.email!
                              : 'Não informado',
                        ),
                        const SizedBox(height: 12),
                        if (_hasPersonalInfo(deputy)) ...[
                          Text(
                            'Dados pessoais',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (deputy.birthDate?.isNotEmpty == true)
                            _InfoRow(
                              title: 'Nascimento',
                              value: _formatBirthDate(deputy.birthDate),
                            ),
                          if (_formatBirthPlace(deputy) != 'Não informado')
                            _InfoRow(
                              title: 'Naturalidade',
                              value: _formatBirthPlace(deputy),
                            ),
                          if (deputy.education?.isNotEmpty == true)
                            _InfoRow(
                              title: 'Escolaridade',
                              value: deputy.education!,
                            ),
                          if (deputy.gender?.isNotEmpty == true)
                            _InfoRow(
                              title: 'Sexo',
                              value: deputy.gender!,
                            ),
                        ],
                      _InfoRow(
                        title: 'Gabinete',
                        value: deputy.officeName?.isNotEmpty == true
                            ? deputy.officeName!
                            : 'Não informado',
                      ),
                      _InfoRow(
                        title: 'Endereço',
                        value: _formatOfficeAddress(deputy),
                      ),
                      if (_hasLinks(deputy)) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Links oficiais',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (deputy.website?.isNotEmpty == true)
                              _SocialIconButton(
                                icon: Icons.public,
                                label: 'Site oficial',
                                color: Colors.blueGrey,
                                onPressed: () async {
                                  await _openExternalUrl(deputy.website!);
                                },
                              ),
                            ...deputy.socialLinks.map(
                              (link) {
                                final meta = _socialMetaFromUrl(link);
                                return _SocialIconButton(
                                  icon: meta.icon,
                                  label: meta.label,
                                  color: meta.color,
                                  onPressed: () async {
                                    await _openExternalUrl(link);
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                        const SizedBox(height: 20),
                        const SizedBox(height: 4),
                        _PresenceSection(presence: bundle.presence),
                        const SizedBox(height: 20),
                        _ExpensesSection(
                          expenses: _expenses,
                          isLoading: _expensesLoading,
                          hasMore: _expensesHasMore,
                          controller: _expensesController,
                          selectedYear: _expensesYear,
                          onYearChanged: (year) {
                            setState(() => _expensesYear = year);
                            _loadExpenses(reset: true);
                          },
                        ),
                        const SizedBox(height: 20),
                        const _AllowancesSection(),
                        const SizedBox(height: 20),
                        _RecentVotesSection(
                          items: _recentVotes,
                          isLoading: _loadingRecentVotes,
                          onRefresh: _loadRecentVotes,
                        ),
                        const SizedBox(height: 20),
                        _NewsSection(
                          deputyNews: bundle.newsDeputy,
                        ),
                        const SizedBox(height: 20),
                        const _VotesSection(),
                        const SizedBox(height: 20),
                      // Removido feed de rede social (sem API pública).
                        Text(
                          'Projetos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _CacheFooter(
                          detailFromCache: bundle.detail.fromCache,
                          propsFromCache: false,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (showApproved)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabHeaderDelegate(),
                  ),
              ],
              body: TabBarView(
                children: showApproved
                    ? [
                        _PropositionsList(
                          controller: _approvedController,
                          propositions: _approved,
                          isLoading: _isLoadingMore,
                          hasMore: _hasMore,
                          emptyLabel: 'Nenhum projeto aprovado encontrado.',
                          deputyId: deputy.id,
                        ),
                        _PropositionsList(
                          controller: _pendingController,
                          propositions: _pending,
                          isLoading: _isLoadingMore,
                          hasMore: _hasMore,
                          emptyLabel: 'Nenhum projeto em tramitação encontrado.',
                          deputyId: deputy.id,
                        ),
                      ]
                    : [
                        _PropositionsList(
                          controller: _pendingController,
                          propositions: _pending,
                          isLoading: _isLoadingMore,
                          hasMore: _hasMore,
                          emptyLabel: 'Nenhum projeto em tramitação encontrado.',
                          deputyId: deputy.id,
                        ),
                      ],
              ),
            ),
          );
        },
      ),
    ),
    );
  }
}

class _HeaderBundle {
  _HeaderBundle({
    required this.detail,
    required this.newsDeputy,
    required this.presence,
  });

  final RepositoryResult<Deputy> detail;
  final List<NewsItem> newsDeputy;
  final PresenceStats? presence;
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.deputy});

  final Deputy deputy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          deputy.isCurrent ? Icons.verified : Icons.info_outline,
          color: deputy.isCurrent ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            deputy.situation?.isNotEmpty == true
                ? deputy.situation!
                : 'Situação não informada',
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.blueGrey.shade50,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _OutlinedName extends StatelessWidget {
  const _OutlinedName({
    required this.text,
    this.maxLines = 2,
    required this.fillColor,
    required this.strokeColor,
  });

  final String text;
  final int maxLines;
  final Color fillColor;
  final Color strokeColor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.roboto(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: fillColor,
    );
    return Stack(
      children: [
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: baseStyle.copyWith(
            color: fillColor,
          ),
        ),
      ],
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 54;

  @override
  double get maxExtent => 54;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: TabBar(
        labelColor: Theme.of(context).colorScheme.primary,
        indicatorColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey.shade600,
        tabs: const [
          Tab(text: 'Aprovados'),
          Tab(text: 'Em tramitação'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class _PropositionsList extends StatelessWidget {
  const _PropositionsList({
    required this.controller,
    required this.propositions,
    required this.isLoading,
    required this.hasMore,
    required this.emptyLabel,
    required this.deputyId,
  });

  final ScrollController controller;
  final List<Proposition> propositions;
  final bool isLoading;
  final bool hasMore;
  final String emptyLabel;
  final int deputyId;

  @override
  Widget build(BuildContext context) {
    if (propositions.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (propositions.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: propositions.length + 1,
      itemBuilder: (context, index) {
        if (index == propositions.length) {
          if (isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Fim da lista.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        final proposition = propositions[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(proposition.title),
              subtitle: Text(
                proposition.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusChip(isApproved: proposition.isApproved),
                  const SizedBox(height: 6),
                  const Icon(Icons.how_to_vote_outlined, size: 18),
                ],
              ),
              onTap: () => _showProposition(context, proposition, deputyId),
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isApproved});

  final bool isApproved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isApproved ? 'Aprovado' : 'Em tramitação',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isApproved ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }
}

Future<void> _showProposition(
  BuildContext context,
  Proposition proposition,
  int deputyId,
) async {
  final summaryService = SummaryService();
  final repository = DeputyRepository();
  SummaryResult? summaryResult;
  bool isLoading = false;
  bool isLoadingVote = false;
  DeputyVote? deputyVote;
  Voting? latestVoting;
  String? voteMessage;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proposition.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    proposition.statusLabel,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    proposition.summary.isNotEmpty
                        ? proposition.summary
                        : 'Sem descrição disponível.',
                  ),
                  if ((proposition.detailedSummary ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Emendas / Detalhes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(proposition.detailedSummary!),
                  ],
                  const SizedBox(height: 16),
                  if (summaryResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(summaryResult!.summary),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  if (latestVoting != null)
                    Text(
                      'Última votação: ${latestVoting!.dateTime}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  if (deputyVote != null)
                    Text(
                      'Voto do deputado: ${deputyVote!.vote}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  if (voteMessage != null)
                    Text(
                      voteMessage!,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      FilledButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setState(() => isLoading = true);
                                final result =
                                    await summaryService.getSummary(
                                  propositionId: proposition.id,
                                  text: proposition.summary,
                                );
                                setState(() {
                                  summaryResult = result;
                                  isLoading = false;
                                });
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Resumir'),
                      ),
                      OutlinedButton(
                        onPressed: isLoadingVote
                            ? null
                            : () async {
                                setState(() => isLoadingVote = true);
                                final votacoes =
                                    await repository.getPropositionVotacoes(
                                  proposition.id,
                                );
                                if (votacoes.isEmpty) {
                                  voteMessage = 'Sem votação registrada.';
                                } else {
                                  votacoes.sort((a, b) {
                                    final da = DateTime.tryParse(a.dateTime) ??
                                        DateTime.fromMillisecondsSinceEpoch(0);
                                    final db = DateTime.tryParse(b.dateTime) ??
                                        DateTime.fromMillisecondsSinceEpoch(0);
                                    return db.compareTo(da);
                                  });
                                  latestVoting = votacoes.first;
                                  final votos = await repository.getVotingVotes(
                                    latestVoting!.id,
                                  );
                                  deputyVote = votos.firstWhere(
                                    (vote) => vote.deputyId == deputyId,
                                    orElse: () => DeputyVote(
                                      deputyId: deputyId,
                                      vote: 'Sem voto registrado',
                                      name: '',
                                    ),
                                  );
                                  voteMessage = null;
                                }
                                setState(() => isLoadingVote = false);
                              },
                        child: isLoadingVote
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Ver voto'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final url = _propositionSiteUrl(proposition.id);
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.inAppBrowserView,
                            );
                          }
                        },
                        child: const Text('Abrir no site'),
                      ),
                      OutlinedButton(
                        onPressed: latestVoting == null
                            ? null
                            : () async {
                                final url = _propositionSiteUrl(proposition.id);
                                final uri = Uri.tryParse(url);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.inAppBrowserView,
                                  );
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Não foi possível abrir o site.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: const Text('Ver tramitação e votação'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

String _formatOfficeAddress(Deputy deputy) {
  final parts = <String>[];
  if (deputy.officeBuilding != null && deputy.officeBuilding!.isNotEmpty) {
    parts.add('Prédio ${deputy.officeBuilding}');
  }
  if (deputy.officeFloor != null && deputy.officeFloor!.isNotEmpty) {
    parts.add('Andar ${deputy.officeFloor}');
  }
  if (deputy.officeRoom != null && deputy.officeRoom!.isNotEmpty) {
    parts.add('Sala ${deputy.officeRoom}');
  }
  if (parts.isEmpty) {
    return 'Não informado';
  }
  return parts.join(' • ');
}

bool _hasPersonalInfo(Deputy deputy) {
  return (deputy.birthDate?.isNotEmpty == true) ||
      (deputy.birthCity?.isNotEmpty == true) ||
      (deputy.birthUf?.isNotEmpty == true) ||
      (deputy.education?.isNotEmpty == true) ||
      (deputy.gender?.isNotEmpty == true);
}

bool _hasLinks(Deputy deputy) {
  return (deputy.website?.isNotEmpty == true) ||
      deputy.socialLinks.isNotEmpty;
}

String _formatBirthDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return 'Não informado';
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw;
  }
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString();
  return '$day/$month/$year';
}

String _formatBirthPlace(Deputy deputy) {
  final city = deputy.birthCity?.trim() ?? '';
  final uf = deputy.birthUf?.trim() ?? '';
  if (city.isEmpty && uf.isEmpty) {
    return 'Não informado';
  }
  if (city.isEmpty) {
    return uf;
  }
  if (uf.isEmpty) {
    return city;
  }
  return '$city - $uf';
}

String _monthLabel(int month) {
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
  return labels[month] ?? month.toString();
}

String _shortLinkLabel(String url) {
  final normalized = _normalizeUrl(url);
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return url;
  }
  final host = uri.host.replaceFirst('www.', '');
  return host.isNotEmpty ? host : url;
}

String _normalizeUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

Future<void> _openExternalUrl(String url) async {
  final normalized = _normalizeUrl(url);
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

_SocialMeta _socialMetaFromUrl(String url) {
  final normalized = url.toLowerCase();
  if (normalized.contains('instagram.com')) {
    return _SocialMeta(
      label: 'Instagram',
      icon: Icons.camera_alt,
      color: const Color(0xFFE1306C),
    );
  }
  if (normalized.contains('facebook.com') || normalized.contains('fb.com')) {
    return _SocialMeta(
      label: 'Facebook',
      icon: Icons.facebook,
      color: const Color(0xFF1877F2),
    );
  }
  if (normalized.contains('twitter.com') ||
      normalized.contains('x.com')) {
    return _SocialMeta(
      label: 'X/Twitter',
      icon: Icons.alternate_email,
      color: const Color(0xFF111827),
    );
  }
  if (normalized.contains('youtube.com') || normalized.contains('youtu.be')) {
    return _SocialMeta(
      label: 'YouTube',
      icon: Icons.play_circle_fill,
      color: const Color(0xFFFF0000),
    );
  }
  if (normalized.contains('tiktok.com')) {
    return _SocialMeta(
      label: 'TikTok',
      icon: Icons.music_note,
      color: const Color(0xFF111827),
    );
  }
  if (normalized.contains('linkedin.com')) {
    return _SocialMeta(
      label: 'LinkedIn',
      icon: Icons.business_center,
      color: const Color(0xFF0A66C2),
    );
  }
  return _SocialMeta(
    label: _shortLinkLabel(url),
    icon: Icons.public,
    color: Colors.blueGrey,
  );
}

class _SocialMeta {
  const _SocialMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

String _propositionSiteUrl(int id) {
  return 'https://www.camara.leg.br/proposicoesWeb/'
      'fichadetramitacao?idProposicao=$id';
}


class _PresenceSection extends StatelessWidget {
  const _PresenceSection({required this.presence});

  final PresenceStats? presence;

  @override
  Widget build(BuildContext context) {
    final presenceData = presence;
    if (presenceData == null) {
      return const SizedBox.shrink();
    }
    final total = presenceData.total == 0 ? 1 : presenceData.total;
    final presenceRatio = presenceData.presences / total;
    final absenceRatio = presenceData.absences / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Presença (últimos 30 dias)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Período: ${presenceData.startDate} a ${presenceData.endDate}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text('Presenças: ${presenceData.presences}'),
            Text('Faltas: ${presenceData.absences}'),
            Text('Total de sessões: ${presenceData.total}'),
            const SizedBox(height: 12),
            _PresenceChart(
              presenceRatio: presenceRatio,
              absenceRatio: absenceRatio,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenceChart extends StatelessWidget {
  const _PresenceChart({
    required this.presenceRatio,
    required this.absenceRatio,
  });

  final double presenceRatio;
  final double absenceRatio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: presenceRatio.clamp(0.0, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('Presenças'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: absenceRatio.clamp(0.0, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade500,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('Faltas'),
          ],
        ),
      ],
    );
  }
}

class _ExpensesSection extends StatelessWidget {
  const _ExpensesSection({
    required this.expenses,
    required this.isLoading,
    required this.hasMore,
    required this.controller,
    required this.selectedYear,
    required this.onYearChanged,
  });

  final List<ExpenseItem> expenses;
  final bool isLoading;
  final bool hasMore;
  final ScrollController controller;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final total = expenses.fold<double>(0, (sum, item) => sum + item.value);
    final grouped = <String, double>{};
    for (final item in expenses) {
      final key = item.type.isNotEmpty ? item.type : 'Outros';
      grouped[key] = (grouped[key] ?? 0) + item.value;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos recentes (CEAP)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _YearFilter(
              selectedYear: selectedYear,
              onChanged: onYearChanged,
            ),
            const SizedBox(height: 8),
            if (expenses.isNotEmpty) ...[
              Text(
                'Total listado: R\$ ${total.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              _ExpenseCharts(data: grouped),
              const SizedBox(height: 12),
              _MonthlySummary(expenses: expenses),
              const SizedBox(height: 12),
            ] else
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sem despesas registradas para este ano.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            SizedBox(
              height: 320,
              child: ListView.builder(
                controller: controller,
                itemCount: expenses.length + 1,
                itemBuilder: (context, index) {
                  if (index == expenses.length) {
                    if (isLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!hasMore) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Fim dos gastos do ano.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  final item = expenses[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.type.isNotEmpty ? item.type : 'Despesa',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (item.description.isNotEmpty)
                          Text(
                            item.description,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        Text(item.supplier.isNotEmpty
                            ? item.supplier
                            : 'Fornecedor não informado'),
                        Text(
                          '${item.date} • R\$ ${item.value.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if ((item.documentNumber ?? '').isNotEmpty)
                              _MetaChip(label: 'Doc: ${item.documentNumber}'),
                            if ((item.cnpjCpf ?? '').isNotEmpty)
                              _MetaChip(label: 'CNPJ/CPF: ${item.cnpjCpf}'),
                            if (item.year != null && item.month != null)
                              _MetaChip(
                                label:
                                    'Competência: ${item.month}/${item.year}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: item.documentUrl?.isNotEmpty == true
                                  ? () async {
                                      final uri =
                                          Uri.tryParse(item.documentUrl!);
                                      if (uri != null &&
                                          await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.inAppBrowserView,
                                        );
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Ver documento'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  _showExpenseDetails(context, item),
                              child: const Text('Mais detalhes'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearFilter extends StatelessWidget {
  const _YearFilter({
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

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.expenses});

  final List<ExpenseItem> expenses;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const SizedBox.shrink();
    }
    final totals = <int, double>{};
    for (final item in expenses) {
      final month = item.month ?? 0;
      if (month == 0) continue;
      totals[month] = (totals[month] ?? 0) + item.value;
    }
    if (totals.isEmpty) {
      return const SizedBox.shrink();
    }
    final ordered = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final max = ordered.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo mensal',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Column(
          children: ordered.map((entry) {
            final ratio = (entry.value / max).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      _monthLabel(entry.key),
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

class _VotesSection extends StatelessWidget {
  const _VotesSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votações em PLs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Abra uma proposição para ver o voto nominal do deputado '
              'quando houver registro na Câmara.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentVoteItem {
  const _RecentVoteItem({
    required this.proposition,
    required this.voting,
    required this.vote,
  });

  final Proposition proposition;
  final Voting voting;
  final DeputyVote vote;
}

class _RecentVotesSection extends StatelessWidget {
  const _RecentVotesSection({
    required this.items,
    required this.isLoading,
    required this.onRefresh,
  });

  final List<_RecentVoteItem> items;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Votações recentes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              Text(
                'Sem votações recentes encontradas.',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else
              Column(
                children: items.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.proposition.title),
                    subtitle: Text(item.voting.summary),
                    trailing: Text(
                      item.vote.vote,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {},
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _AllowancesSection extends StatelessWidget {
  const _AllowancesSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auxílios e benefícios',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Informações detalhadas de auxílios (ex.: auxílio-moradia) '
              'não estão disponíveis diretamente na API pública.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Future<void> _showExpenseDetails(
  BuildContext context,
  ExpenseItem item,
) async {
  final totalByCategory = _calcCategoryTotals([item]);
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.type.isNotEmpty ? item.type : 'Despesa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              item.supplier.isNotEmpty
                  ? item.supplier
                  : 'Fornecedor não informado',
            ),
            const SizedBox(height: 8),
            Text('Valor: R\$ ${item.value.toStringAsFixed(2)}'),
            if (item.date.isNotEmpty) Text('Data: ${item.date}'),
            if ((item.documentNumber ?? '').isNotEmpty)
              Text('Documento: ${item.documentNumber}'),
            if ((item.cnpjCpf ?? '').isNotEmpty)
              Text('CNPJ/CPF: ${item.cnpjCpf}'),
            if (item.year != null && item.month != null)
              Text('Competência: ${item.month}/${item.year}'),
            const SizedBox(height: 12),
            if (totalByCategory.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total por categoria (amostra atual)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...totalByCategory.entries.map(
                    (entry) => Text(
                      '${entry.key}: R\$ ${entry.value.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            if (item.documentUrl?.isNotEmpty == true)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    final uri = Uri.tryParse(item.documentUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.inAppBrowserView,
                      );
                    }
                  },
                  child: const Text('Abrir documento'),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Map<String, double> _calcCategoryTotals(List<ExpenseItem> items) {
  final grouped = <String, double>{};
  for (final item in items) {
    final key = item.type.isNotEmpty ? item.type : 'Outros';
    grouped[key] = (grouped[key] ?? 0) + item.value;
  }
  return grouped;
}

class _ExpenseCharts extends StatelessWidget {
  const _ExpenseCharts({required this.data});

  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    final top = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final limited = top.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            height: 120,
            width: 120,
            child: CustomPaint(
              painter: _PieChartPainter(limited),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _BarChart(data: limited),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});

  final List<MapEntry<String, double>> data;

  @override
  Widget build(BuildContext context) {
    final max = data.isEmpty
        ? 1.0
        : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: data.map((entry) {
        final ratio = (entry.value / max).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                flex: 4,
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
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter(this.data);

  final List<MapEntry<String, double>> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2.4;
    var start = -1.5708; // -90deg

    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF0F172A),
      const Color(0xFF1E293B),
      const Color(0xFF64748B),
      const Color(0xFF94A3B8),
    ];

    for (var i = 0; i < data.length; i++) {
      final sweep = (data[i].value / total) * 6.283185307179586;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NewsSection extends StatefulWidget {
  const _NewsSection({
    required this.deputyNews,
  });

  final List<NewsItem> deputyNews;

  @override
  State<_NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<_NewsSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final benefits = widget.deputyNews.where((item) {
      final text =
          '${item.title} ${item.description ?? ''}'.toLowerCase();
      return text.contains('subsídio') ||
          text.contains('remuneração') ||
          text.contains('salário') ||
          text.contains('auxílio') ||
          text.contains('verba') ||
          text.contains('cota') ||
          text.contains('ceap') ||
          text.contains('ajuda de custo') ||
          text.contains('indenizat');
    }).toList();

    final items = _tab == 0 ? widget.deputyNews : benefits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notícias',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: _tab == 0,
              onSelected: (_) => setState(() => _tab = 0),
            ),
            ChoiceChip(
              label: const Text('Benefícios e verbas'),
              selected: _tab == 1,
              onSelected: (_) => setState(() => _tab = 1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(
            _tab == 0
                ? 'Nenhuma notícia específica encontrada no RSS.'
                : 'Nenhuma notícia de benefícios/verbas encontrada.',
          ),
        Column(
          children: items.map((item) => _NewsCard(item: item)).toList(),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: item.url == null
            ? null
            : () async {
                final uri = Uri.tryParse(item.url!);
                if (uri != null) {
                  await launchUrl(
                    uri,
                    mode: LaunchMode.inAppBrowserView,
                  );
                }
              },
        child: Row(
          children: [
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  width: 96,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.black12),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.black12),
                ),
              )
            else
              Container(
                width: 96,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.article_outlined),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.source,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if ((item.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Se precisar de redes sociais no futuro, plugamos uma API oficial aqui.

class _CacheFooter extends StatelessWidget {
  const _CacheFooter({
    required this.detailFromCache,
    required this.propsFromCache,
  });

  final bool detailFromCache;
  final bool propsFromCache;

  @override
  Widget build(BuildContext context) {
    final text = detailFromCache || propsFromCache
        ? 'Exibindo informações em cache (offline).'
        : 'Dados atualizados com a API da Câmara.';
    return Text(
      text,
      style: TextStyle(color: Colors.grey.shade700),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

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
              'Não foi possível carregar os detalhes.',
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
