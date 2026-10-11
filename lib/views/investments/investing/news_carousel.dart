// "Recent financial news" block: an auto-sliding carousel of the latest
// local and world headlines. Slides advance every few seconds, pause while
// the user is swiping, and open the article in the browser when tapped.
// Headlines refresh in the background every 5 minutes.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/investing_models.dart';
import '../../../services/investing_data_service.dart';
import 'investing_widgets.dart';

enum _NewsFilter { all, local, world }

class NewsCarousel extends StatefulWidget {
  const NewsCarousel({super.key});

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  static const _slideEvery = Duration(seconds: 5);
  static const _resumeAfterTouch = Duration(seconds: 8);
  static const _refreshEvery = Duration(minutes: 5);
  static const _maxSlides = 15;

  final _service = InvestingDataService();
  final _controller = PageController(viewportFraction: 0.92);

  List<NewsItem> _all = [];
  bool _loading = true;
  bool _failed = false;
  DateTime? _fetchedAt;
  _NewsFilter _filter = _NewsFilter.all;
  int _page = 0;

  Timer? _slideTimer;
  Timer? _refreshTimer;
  Timer? _resumeTimer;

  List<NewsItem> get _visible => _all
      .where((n) => switch (_filter) {
            _NewsFilter.all => true,
            _NewsFilter.local => n.isLocal,
            _NewsFilter.world => !n.isLocal,
          })
      .take(_maxSlides)
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _load());
    _startSliding();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _refreshTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _service.fetchNews();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = items == null;
      if (items != null && items.isNotEmpty) {
        _all = items;
        _fetchedAt = DateTime.now();
      }
    });
  }

  void _startSliding() {
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(_slideEvery, (_) {
      final count = _visible.length;
      if (count < 2 || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % count,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Stop auto-advancing while the user swipes; pick up again shortly after.
  void _pauseSliding() {
    _slideTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeAfterTouch, _startSliding);
  }

  void _setFilter(_NewsFilter f) {
    setState(() {
      _filter = f;
      _page = 0;
    });
    if (_controller.hasClients) _controller.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: InvestColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.newspaper_rounded, size: 20, color: InvestColors.green),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Recent financial news',
                        style: investText(16, weight: FontWeight.w700))),
                LiveBadge(
                  live: _fetchedAt != null && !_failed,
                  label: _loading
                      ? 'Loading…'
                      : (_fetchedAt == null ? 'Offline' : formatUpdated(_fetchedAt)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                _chip('All', _NewsFilter.all),
                _chip('Sri Lanka', _NewsFilter.local),
                _chip('World', _NewsFilter.world),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: _loading && _all.isEmpty
                ? const Center(child: CircularProgressIndicator(color: InvestColors.green))
                : items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: Text(
                            _failed
                                ? "Couldn't load the news right now. It will retry automatically."
                                : 'No stories in this category right now.',
                            textAlign: TextAlign.center,
                            style: investText(13, color: InvestColors.muted),
                          ),
                        ),
                      )
                    : NotificationListener<ScrollStartNotification>(
                        onNotification: (n) {
                          if (n.dragDetails != null) _pauseSliding();
                          return false;
                        },
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: items.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (context, i) => _NewsSlide(item: items[i]),
                        ),
                      ),
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? InvestColors.green : InvestColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, _NewsFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label,
          style: investText(12,
              weight: FontWeight.w600, color: selected ? Colors.white : InvestColors.text)),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: InvestColors.green,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? InvestColors.green : InvestColors.border),
      onSelected: (_) => _setFilter(value),
    );
  }
}

class _NewsSlide extends StatelessWidget {
  final NewsItem item;
  const _NewsSlide({required this.item});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [InvestColors.green, Color(0xFF147A4D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.trending_up_rounded,
          size: 56, color: Colors.white.withValues(alpha: 0.25)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openExternal(item.url),
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.image == null
                  ? fallback
                  : Image.network(
                      item.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => fallback,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : fallback,
                    ),
              // Darken the bottom so the headline stays readable on any photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x10000000), Color(0xD9000000)],
                    stops: [0.25, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _tag(item.isLocal ? 'Sri Lanka' : 'World'),
                        const SizedBox(width: 6),
                        Flexible(child: _tag(item.source)),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: investText(16, weight: FontWeight.w700, color: Colors.white)
                          .copyWith(height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(formatUpdated(item.publishedAt),
                            style: investText(11, color: Colors.white70)),
                        const Spacer(),
                        Text('Read on site',
                            style: investText(11, weight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: investText(10, weight: FontWeight.w700, color: Colors.white)),
      );
}
