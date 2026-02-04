import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/deputy_extras.dart';
import '../models/proposition.dart';
import '../models/voting.dart';
import '../services/deputy_repository.dart';
import '../services/news_service.dart';
import 'deputy_detail_page.dart';
import 'home_page.dart';
import 'senators_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late Future<List<NewsItem>> _newsFuture;
  final ScrollController _pageController = ScrollController();
  final ScrollController _newsController = ScrollController();
  List<NewsItem> _newsItems = [];
  int _newsVisible = 4;
  bool _showToTop = false;
  final ScrollController _votingScrollController = ScrollController();
  final List<_VotingFeedItem> _votingItems = [];
  final Set<String> _votingKeys = {};
  bool _votingLoading = false;
  bool _votingHasMore = true;
  int _votingPage = 1;

  @override
  void initState() {
    super.initState();
    _newsFuture = NewsService().fetchAllNews();
    _loadVotacoes();
    _votingScrollController.addListener(_onVotingScroll);
    _pageController.addListener(_onPageScroll);
    _newsController.addListener(_onNewsScroll);
  }

  @override
  void dispose() {
    _votingScrollController.dispose();
    _pageController.dispose();
    _newsController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final show = _pageController.offset > 500;
    if (show != _showToTop) {
      setState(() => _showToTop = show);
    }
  }

  void _onNewsScroll() {
    if (_newsController.position.pixels >
        _newsController.position.maxScrollExtent - 120) {
      if (_newsVisible < _newsItems.length) {
        setState(() => _newsVisible =
            (_newsVisible + 4).clamp(0, _newsItems.length));
      }
    }
  }

  void _onVotingScroll() {
    if (_votingScrollController.position.pixels >
        _votingScrollController.position.maxScrollExtent - 240) {
      _loadVotacoes();
    }
  }

  Future<void> _loadVotacoes() async {
    if (_votingLoading || !_votingHasMore) {
      return;
    }
    setState(() => _votingLoading = true);
    try {
      final pageItems = await _fetchVotacoesPage(
        page: _votingPage,
        items: 5,
      );
      final uniqueItems = pageItems.where((item) {
        final key = item.voting.propositionId != null
            ? 'P${item.voting.propositionId}'
            : 'V${item.voting.id}';
        return _votingKeys.add(key);
      }).toList();
      if (uniqueItems.isEmpty) {
        _votingHasMore = false;
      } else {
        _votingItems.addAll(uniqueItems);
        _votingPage += 1;
      }
    } catch (_) {
      if (_votingItems.isEmpty) {
        _votingHasMore = false;
      }
    } finally {
      if (mounted) {
        setState(() => _votingLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surface.withValues(alpha: 0.92),
              const Color(0xFFE7ECF1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MetalNoisePainter(),
                ),
              ),
              ListView(
                controller: _pageController,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'InfoPoliticos',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Busque politicos e filtre por cargo, UF e partido.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
              Text(
                'Explorar politicos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _RoleGrid(
                onDeputados: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const HomePage())),
                onSenadores: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const SenatorsPage())),
              ),
              const SizedBox(height: 16),
              _StateShortcut(
                onSelectDeputados: (uf) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HomePage(initialUf: uf)),
                ),
                onSelectSenadores: (uf) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SenatorsPage(initialUf: uf),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Notícias', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              FutureBuilder<List<NewsItem>>(
                future: _newsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  _newsItems = snapshot.data ?? [];
                  if (_newsItems.isEmpty) {
                    return Text(
                      'Sem notícias disponíveis no momento.',
                      style: TextStyle(color: Colors.grey.shade700),
                    );
                  }
                  final visible = _newsItems.take(_newsVisible).toList();
                  return SizedBox(
                    height: 320,
                    child: ListView.builder(
                      controller: _newsController,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(item.title),
                            subtitle: Text(item.source),
                            trailing: const Icon(Icons.open_in_new),
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
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
                  Text(
                    'Votações recentes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _VotingFeed(
                    controller: _votingScrollController,
                    items: _votingItems,
                    isLoading: _votingLoading,
                    hasMore: _votingHasMore,
                  ),
                  const SizedBox(height: 20),
                  Text('Fontes', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Dados: Dados Abertos da Câmara. Notícias: Agência Câmara (RSS).',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _showToTop
          ? FloatingActionButton(
              onPressed: () => _pageController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}

class _MetalNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCAD2DC).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final highlight = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    const stripeWidth = 120.0;
    var x = -size.width;
    while (x < size.width * 2) {
      final rect = Rect.fromLTWH(x, -40, stripeWidth, size.height + 80);
      canvas.drawRect(rect, paint);
      canvas.drawRect(
        Rect.fromLTWH(x + stripeWidth * 0.45, -40, stripeWidth * 0.1,
            size.height + 80),
        highlight,
      );
      x += stripeWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VotingFeedItem {
  _VotingFeedItem({
    required this.voting,
    required this.votes,
    required this.proposition,
  });

  final Voting voting;
  final List<DeputyVote> votes;
  final Proposition? proposition;
}

Future<List<_VotingFeedItem>> _fetchVotacoesPage({
  required int page,
  int items = 5,
}) async {
  final repo = DeputyRepository();
  final votacoes = await repo.getRecentVotacoes(items: items, page: page);
  final results = <_VotingFeedItem>[];
  for (final voting in votacoes) {
    List<DeputyVote> votes = [];
    String? ementa;
    Proposition? proposition;
    try {
      votes = await repo.getVotingVotes(voting.id);
    } catch (_) {}
    try {
      ementa = await repo.getVotingEmenta(voting.id);
    } catch (_) {}
    final votingWithEmenta = Voting(
      id: voting.id,
      dateTime: voting.dateTime,
      summary: voting.summary,
      propositionId: voting.propositionId,
      ementa: ementa ?? voting.ementa,
    );
    if (voting.propositionId != null) {
      try {
        final detail =
            await repo.getPropositionDetail(voting.propositionId!);
        final author =
            await repo.getPropositionAuthor(voting.propositionId!);
        proposition = detail.copyWith(
          authorName: author,
        );
      } catch (_) {
        proposition = null;
      }
    }
    results.add(
      _VotingFeedItem(
        voting: votingWithEmenta,
        votes: votes,
        proposition: proposition,
      ),
    );
  }
  return results;
}

class _VotingFeedCard extends StatelessWidget {
  const _VotingFeedCard({required this.item});

  final _VotingFeedItem item;

  @override
  Widget build(BuildContext context) {
    final approved = _isApproved(item.voting.summary);
    final title = item.proposition?.title ??
        (item.voting.ementa?.trim().isNotEmpty == true
            ? item.voting.ementa!
            : (item.voting.propositionId != null
                ? 'Proposição ${item.voting.propositionId}'
                : 'Votação'));
    final summary = (item.proposition?.summary ?? '').trim().isNotEmpty
        ? item.proposition!.summary
        : (item.voting.ementa?.trim().isNotEmpty == true
            ? item.voting.ementa!
            : item.voting.summary);
    final status = (item.proposition?.statusDescription ?? '').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openVotingDetails(context, item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary.isNotEmpty
                    ? summary
                    : 'Ementa não informada para esta proposição.',
                style: TextStyle(color: Colors.grey.shade700),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Status: $status',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              if ((item.proposition?.relatorName ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Relator: ${item.proposition!.relatorName}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              if ((item.proposition?.authorName ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Autor: ${item.proposition!.authorName}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatusPill(
                    label: approved ? 'Aprovado' : 'Rejeitado/Outro',
                    color: approved
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.voting.dateTime,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                children: item.votes.take(4).map((vote) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _voteIcon(vote.vote),
                    title: Text(vote.name),
                    trailing: Text(
                      vote.vote,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DeputyDetailPage(deputyId: vote.deputyId),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (item.votes.isEmpty)
                Text(
                  'Sem votos nominais registrados.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VotingFeed extends StatelessWidget {
  const _VotingFeed({
    required this.controller,
    required this.items,
    required this.isLoading,
    required this.hasMore,
  });

  final ScrollController controller;
  final List<_VotingFeedItem> items;
  final bool isLoading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Text(
        'Sem votações disponíveis no momento.',
        style: TextStyle(color: Colors.grey.shade700),
      );
    }
    return SizedBox(
      height: 420,
      child: ListView.builder(
        controller: controller,
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
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
          return _VotingFeedCard(item: items[index]);
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

Widget _voteIcon(String vote) {
  final normalized = vote.toLowerCase();
  if (normalized.contains('sim')) {
    return const Icon(Icons.check_circle, color: Colors.green);
  }
  if (normalized.contains('não') || normalized.contains('nao')) {
    return const Icon(Icons.cancel, color: Colors.red);
  }
  return const Icon(Icons.remove_circle, color: Colors.grey);
}

bool _isApproved(String text) {
  final lower = text.toLowerCase();
  return lower.contains('aprovad') ||
      lower.contains('transformado') ||
      lower.contains('promulgad');
}

Future<void> _openVotingDetails(
  BuildContext context,
  _VotingFeedItem item,
) async {
  final title = item.proposition?.title ??
      (item.voting.ementa?.trim().isNotEmpty == true
          ? item.voting.ementa!
          : (item.voting.propositionId != null
              ? 'Proposição ${item.voting.propositionId}'
              : 'Votação'));
  final summary = (item.proposition?.summary ?? '').trim().isNotEmpty
      ? item.proposition!.summary
      : (item.voting.ementa?.trim().isNotEmpty == true
          ? item.voting.ementa!
          : item.voting.summary);
  final status = (item.proposition?.statusDescription ?? '').trim();
  final relator = (item.proposition?.relatorName ?? '').trim();
  final author = (item.proposition?.authorName ?? '').trim();
  final queryTitle = _buildSearchQuery(
    title: title,
    propositionId: item.voting.propositionId,
    summary: summary,
    votingId: item.voting.id,
    ementa: item.voting.ementa,
  );
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
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              summary.isNotEmpty
                  ? summary
                  : 'Ementa não informada para esta proposição.',
            ),
            const SizedBox(height: 8),
            Text(
              'Data: ${item.voting.dateTime}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Status: $status',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (relator.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Relator: $relator',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (author.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Autor: $author',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final officialUrl =
                        _officialPropositionUrl(item.voting.propositionId);
                    final officialUri =
                        officialUrl != null ? Uri.tryParse(officialUrl) : null;
                    if (officialUri != null &&
                        await canLaunchUrl(officialUri)) {
                      await launchUrl(
                        officialUri,
                        mode: LaunchMode.inAppBrowserView,
                      );
                      return;
                    }

                    final query = queryTitle.isNotEmpty
                        ? '$queryTitle site:camara.leg.br proposições'
                        : 'votação ${item.voting.id} site:camara.leg.br';
                    final url = _googleSearchUrl(query);
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.inAppBrowserView,
                      );
                      return;
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Não foi possível abrir o site.'),
                        ),
                      );
                    }
                  },
                  child: Text(
                    _officialPropositionUrl(item.voting.propositionId) != null
                        ? 'Abrir no site oficial'
                        : 'Buscar detalhes no Google',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

String _googleSearchUrl(String query) {
  return Uri.https('www.google.com', '/search', {'q': query}).toString();
}

String? _officialPropositionUrl(int? propositionId) {
  if (propositionId == null) {
    return null;
  }
  return 'https://www.camara.leg.br/proposicoesWeb/'
      'fichadetramitacao?idProposicao=$propositionId';
}

String _buildSearchQuery({
  required String title,
  required int? propositionId,
  required String summary,
  required String votingId,
  required String? ementa,
}) {
  final normalizedTitle = title.toLowerCase();
  if (_containsProposalNumber(normalizedTitle)) {
    return title;
  }
  final normalizedSummary = summary.toLowerCase();
  if (_containsProposalNumber(normalizedSummary)) {
    return summary;
  }
  final normalizedEmenta = (ementa ?? '').toLowerCase();
  if (_containsProposalNumber(normalizedEmenta)) {
    return ementa ?? summary;
  }
  if (propositionId != null) {
    return 'Proposição $propositionId';
  }
  return 'votação $votingId';
}

bool _containsProposalNumber(String text) {
  return text.contains('pl ') ||
      text.contains('plp ') ||
      text.contains('pec ') ||
      text.contains('mp ') ||
      text.contains('pdc ') ||
      text.contains('plv ') ||
      text.contains('plc ');
}

class _RoleGrid extends StatelessWidget {
  const _RoleGrid({required this.onDeputados, required this.onSenadores});

  final VoidCallback onDeputados;
  final VoidCallback onSenadores;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoleCard(
          title: 'Deputados Federais',
          subtitle: 'Câmara dos Deputados',
          icon: Icons.account_balance,
          onTap: onDeputados,
        ),
        const SizedBox(height: 8),
        _RoleCard(
          title: 'Senadores',
          subtitle: 'Senado Federal',
          icon: Icons.account_balance_outlined,
          onTap: onSenadores,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 26),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _StateShortcut extends StatelessWidget {
  const _StateShortcut({
    required this.onSelectDeputados,
    required this.onSelectSenadores,
  });

  final ValueChanged<String> onSelectDeputados;
  final ValueChanged<String> onSelectSenadores;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Atalhos por UF',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Deputados',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['RJ', 'SP', 'MG', 'BA', 'RS', 'PE'].map((uf) {
            return ActionChip(
              label: Text(uf),
              onPressed: () => onSelectDeputados(uf),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          'Senadores',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['RJ', 'SP', 'MG', 'BA', 'RS', 'PE'].map((uf) {
            return ActionChip(
              label: Text(uf),
              onPressed: () => onSelectSenadores(uf),
            );
          }).toList(),
        ),
      ],
    );
  }
}
