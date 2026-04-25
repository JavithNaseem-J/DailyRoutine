import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../main.dart' show sharedPrefs;
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Quran Screen — Mushaf Image CDN (Option A)
//
// Pages served from: cdn.islamic.network/quran/images/
// 604 pages, each a high-resolution Mushaf page image.
// ─────────────────────────────────────────────────────────────────────────────

class QuranScreen extends StatefulWidget {
  final int initialPage;
  const QuranScreen({super.key, this.initialPage = 1});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late PageController _pageController;
  late int _currentPage;
  int? _pinnedPage;

  // ── Reading Timer ──────────────────────────────────────────────────────────
  static const int _defaultMinutes = 15;
  int _timerSeconds = _defaultMinutes * 60;
  Timer? _readingTimer;
  bool _timerRunning = false;

  // CDN base — islamic.network serves Mushaf images (CORS-friendly)
  static String _pageImageUrl(int page) {
    final p = page.toString().padLeft(3, '0');
    return 'https://cdn.islamic.network/quran/images/high-resolution/page$p.png';
  }

  @override
  void initState() {
    super.initState();
    _pinnedPage = sharedPrefs.getInt('quran_pinned_page');
    final lastPage = sharedPrefs.getInt('quran_last_page') ?? widget.initialPage;
    _currentPage = lastPage.clamp(1, 604);
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
  void _toggleTimer() {
    HapticFeedback.lightImpact();
    if (_timerRunning) {
      _readingTimer?.cancel();
      setState(() => _timerRunning = false);
    } else {
      if (_timerSeconds == 0) _timerSeconds = _defaultMinutes * 60;
      setState(() => _timerRunning = true);
      _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_timerSeconds > 0) {
          setState(() => _timerSeconds--);
        } else {
          _readingTimer?.cancel();
          setState(() => _timerRunning = false);
          HapticFeedback.heavyImpact();
        }
      });
    }
  }

  void _resetTimer() {
    HapticFeedback.mediumImpact();
    _readingTimer?.cancel();
    setState(() {
      _timerRunning = false;
      _timerSeconds = _defaultMinutes * 60;
    });
  }

  String get _timerLabel {
    final m = _timerSeconds ~/ 60;
    final s = _timerSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Bookmark ───────────────────────────────────────────────────────────────
  void _onPageChanged(int idx) {
    setState(() => _currentPage = idx + 1);
    sharedPrefs.setInt('quran_last_page', _currentPage);
  }

  void _toggleBookmark() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_pinnedPage == _currentPage) {
        _pinnedPage = null;
        sharedPrefs.remove('quran_pinned_page');
      } else {
        _pinnedPage = _currentPage;
        sharedPrefs.setInt('quran_pinned_page', _currentPage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBookmarked = _pinnedPage == _currentPage;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
        actions: [
          // ── Jump-to-bookmark ─────────────────────────────────
          if (_pinnedPage != null && _pinnedPage != _currentPage)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _pageController.animateToPage(
                  _pinnedPage! - 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_rounded, size: 13, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      'Go to p.$_pinnedPage',
                      style: const TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),

          // ── Timer chip: tap = play/pause, long-press = reset ──
          GestureDetector(
            onTap: _toggleTimer,
            onLongPress: _resetTimer,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: _timerRunning
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _timerRunning ? AppColors.primary : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _timerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 14,
                    color: _timerRunning ? AppColors.primary : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _timerLabel,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _timerRunning ? AppColors.primary : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bookmark ─────────────────────────────────────────
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isBookmarked ? Colors.amber : Colors.white54,
            ),
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Page indicator bar ─────────────────────────────────
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page $_currentPage',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${((_currentPage / 604) * 100).toStringAsFixed(0)}% complete',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Page image view ────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: 604,
              reverse: true, // Arabic RTL — page 1 is on the right
              itemBuilder: (context, index) {
                final pageNum = index + 1;
                return _MushafImagePage(
                  imageUrl: _pageImageUrl(pageNum),
                  page: pageNum,
                  isBookmarked: _pinnedPage == pageNum,
                );
              },
            ),
          ),

          // ── Navigation arrows ──────────────────────────────────
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Next page (RTL: "next" = lower page number visually)
                IconButton(
                  onPressed: _currentPage < 604
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: Colors.white38,
                  iconSize: 32,
                ),
                // Quick page jump
                GestureDetector(
                  onTap: () => _showPageJumpDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_currentPage / 604',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _currentPage > 1
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: Colors.white38,
                  iconSize: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page jump dialog ─────────────────────────────────────────────────────
  void _showPageJumpDialog(BuildContext context) {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Jump to Page',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: '1 – 604',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text) ?? _currentPage;
              if (page >= 1 && page <= 604) {
                _pageController.jumpToPage(page - 1);
              }
              Navigator.pop(ctx);
            },
            child: Text('Go', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Mushaf page — loads from CDN
// ─────────────────────────────────────────────────────────────────────────────

class _MushafImagePage extends StatelessWidget {
  const _MushafImagePage({
    required this.imageUrl,
    required this.page,
    required this.isBookmarked,
  });

  final String imageUrl;
  final int page;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // ── Mushaf page image ──────────────────────────────────
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Loading page $page...',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load page',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check your internet connection',
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bookmark badge ─────────────────────────────────────
          if (isBookmarked)
            Positioned(
              top: 8,
              right: 12,
              child: Icon(
                Icons.bookmark_rounded,
                color: Colors.amber.withValues(alpha: 0.8),
                size: 28,
              ),
            ),
        ],
      ),
    );
  }
}
