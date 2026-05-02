import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../main.dart' show sharedPrefs;
import 'package:go_router/go_router.dart';
import 'quran_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (shared with QuranHomeScreen)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0E0E0E);
const _kSurface = Color(0xFF1A1A1A);
const _kGold    = Color(0xFFC9A84C);
const _kGoldMid = Color(0x40C9A84C);
const _kText    = Color(0xFFF5F0E8);
const _kTextSub = Color(0xFF9E9887);
const _kDivider = Color(0xFF2A2A2A);

// ─────────────────────────────────────────────────────────────────────────────
// Quran Reader Screen — native paginated image viewer
// ─────────────────────────────────────────────────────────────────────────────

class QuranScreen extends StatefulWidget {
  final int initialPage;
  const QuranScreen({super.key, this.initialPage = 1});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentPage;
  int? _pinnedPage;
  bool _barsVisible = true;
  late AnimationController _barAnim;
  late Animation<double> _barFade;

  // ── Timer ────────────────────────────────────────────────────────────────
  static const int _defaultMinutes = 15;
  int _timerSeconds = _defaultMinutes * 60;
  Timer? _readingTimer;
  bool _timerRunning = false;

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _imageUrl(int page) {
    final pageStr = page.toString().padLeft(3, '0');
    final url = 'https://android.quran.com/data/width_1024/page$pageStr.png';
    if (kIsWeb) {
      return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  SurahInfo _surahForPage(int page) {
    for (int i = kSurahs.length - 1; i >= 0; i--) {
      if (kSurahs[i].startPage <= page) return kSurahs[i];
    }
    return kSurahs.first;
  }

  String get _timerLabel {
    final m = _timerSeconds ~/ 60;
    final s = _timerSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pinnedPage = sharedPrefs.getInt('quran_pinned_page');
    // BUG-007 fix: use widget.initialPage as the primary target.
    // Only fall back to the last-read page if no explicit page was requested
    // (i.e. when initialPage is the default value of 1).
    final savedPage = sharedPrefs.getInt('quran_last_page');
    final startPage = (widget.initialPage != 1)
        ? widget.initialPage
        : (savedPage ?? widget.initialPage);
    _currentPage = startPage.clamp(1, 604);
    _pageController = PageController(initialPage: _currentPage - 1);

    _barAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _barFade = CurvedAnimation(parent: _barAnim, curve: Curves.easeInOut);
    _barAnim.value = 1.0; // start visible
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    // BUG-009 fix: persist the timer duration so QuranHomeScreen can display it
    sharedPrefs.setInt('quran_reading_minutes', _defaultMinutes);
    _pageController.dispose();
    _barAnim.dispose();
    super.dispose();
  }

  // ── Tap to toggle bars ───────────────────────────────────────────────────
  void _toggleBars() {
    setState(() => _barsVisible = !_barsVisible);
    if (_barsVisible) {
      _barAnim.forward();
    } else {
      _barAnim.reverse();
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
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

  // ── Bookmark ──────────────────────────────────────────────────────────────
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

  // ── Navigation ────────────────────────────────────────────────────────────
  void _navigateTo(int page) {
    if (page < 1 || page > 604) return;
    _pageController.animateToPage(
      page - 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index) {
    final newPage = index + 1;
    setState(() => _currentPage = newPage);
    sharedPrefs.setInt('quran_last_page', newPage);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isBookmarked = _pinnedPage == _currentPage;
    final surah = _surahForPage(_currentPage);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Page Viewer ─────────────────────────────────────────────────
          GestureDetector(
            onTap: _toggleBars,
            child: PageView.builder(
              controller: _pageController,
              reverse: true, // Arabic RTL
              itemCount: 604,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final pageNumber = index + 1;
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: kIsWeb
                      ? Image.network(
                          _imageUrl(pageNumber),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _loadingWidget(progress);
                          },
                          errorBuilder: (_, __, ___) => _errorWidget(),
                        )
                      : CachedNetworkImage(
                          imageUrl: _imageUrl(pageNumber),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, __) =>
                              _loadingWidget(null),
                          errorWidget: (_, __, ___) => _errorWidget(),
                        ),
                );
              },
            ),
          ),

          // ── Top Bar ─────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _barFade,
              child: IgnorePointer(
                ignoring: !_barsVisible,
                child: _TopBar(
                  surah: surah,
                  currentPage: _currentPage,
                  pinnedPage: _pinnedPage,
                  isBookmarked: isBookmarked,
                  timerRunning: _timerRunning,
                  timerLabel: _timerLabel,
                  onBack: () => context.pop(),
                  onBookmark: _toggleBookmark,
                  onToggleTimer: _toggleTimer,
                  onLongPressTimer: _resetTimer,
                  onJumpToBookmark:
                      _pinnedPage != null ? () => _navigateTo(_pinnedPage!) : null,
                ),
              ),
            ),
          ),

          // ── Bottom Pill Nav ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _barFade,
              child: IgnorePointer(
                ignoring: !_barsVisible,
                child: _BottomNav(
                  currentPage: _currentPage,
                  onPrev: _currentPage > 1
                      ? () => _navigateTo(_currentPage - 1)
                      : null,
                  onNext: _currentPage < 604
                      ? () => _navigateTo(_currentPage + 1)
                      : null,
                  onTapPage: () => _showJumpDialog(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingWidget(ImageChunkEvent? progress) {
    final value = (progress?.expectedTotalBytes != null)
        ? progress!.cumulativeBytesLoaded / progress.expectedTotalBytes!
        : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: value,
              color: _kGold,
              backgroundColor: _kDivider,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Loading page…',
              style: TextStyle(color: _kTextSub, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _errorWidget() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: _kTextSub),
            SizedBox(height: 12),
            Text('Could not load page.',
                style: TextStyle(color: _kTextSub, fontSize: 13)),
            SizedBox(height: 4),
            Text('Check your connection.',
                style: TextStyle(color: _kTextSub, fontSize: 12)),
          ],
        ),
      );

  void _showJumpDialog(BuildContext context) {
    // BUG-015 fix: dispose controller after dialog closes to prevent memory leak
    final controller =
        TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Jump to Page',
            style: TextStyle(color: _kText, fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: _kText, fontSize: 18),
          decoration: const InputDecoration(
            hintText: '1 – 604',
            hintStyle: TextStyle(color: _kTextSub),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _kGold)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _kGold, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _kTextSub)),
          ),
          TextButton(
            onPressed: () {
              final page =
                  int.tryParse(controller.text) ?? _currentPage;
              _navigateTo(page);
              Navigator.pop(ctx);
            },
            child: const Text('Go',
                style: TextStyle(
                    color: _kGold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).whenComplete(() => controller.dispose());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.surah,
    required this.currentPage,
    required this.pinnedPage,
    required this.isBookmarked,
    required this.timerRunning,
    required this.timerLabel,
    required this.onBack,
    required this.onBookmark,
    required this.onToggleTimer,
    required this.onLongPressTimer,
    required this.onJumpToBookmark,
  });

  final SurahInfo surah;
  final int currentPage;
  final int? pinnedPage;
  final bool isBookmarked;
  final bool timerRunning;
  final String timerLabel;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onToggleTimer;
  final VoidCallback onLongPressTimer;
  final VoidCallback? onJumpToBookmark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kBg,
            _kBg.withValues(alpha: 0.95),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          child: Row(
            children: [
              // Back
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _kTextSub, size: 18),
              ),
              // Surah info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(surah.name,
                        style: const TextStyle(
                            color: _kText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text('Juzz ${surah.juzz} · Page $currentPage',
                        style: const TextStyle(
                            color: _kTextSub, fontSize: 11)),
                  ],
                ),
              ),
              // Jump to bookmark pill
              if (pinnedPage != null && pinnedPage != currentPage)
                GestureDetector(
                  onTap: onJumpToBookmark,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kGoldMid,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kGold),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark_rounded,
                            size: 12, color: _kGold),
                        const SizedBox(width: 4),
                        Text('p.$pinnedPage',
                            style: const TextStyle(
                                fontSize: 11,
                                color: _kGold,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              // Timer
              GestureDetector(
                onTap: onToggleTimer,
                onLongPress: onLongPressTimer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: timerRunning
                        ? _kGold.withValues(alpha: 0.2)
                        : _kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: timerRunning ? _kGold : _kDivider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        timerRunning
                            ? Icons.pause_rounded
                            : Icons.timer_outlined,
                        size: 13,
                        color: timerRunning ? _kGold : _kTextSub,
                      ),
                      const SizedBox(width: 4),
                      Text(timerLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: timerRunning ? _kGold : _kTextSub,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
              // Bookmark
              IconButton(
                onPressed: onBookmark,
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isBookmarked ? _kGold : _kTextSub,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Floating Pill Nav
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentPage,
    required this.onPrev,
    required this.onNext,
    required this.onTapPage,
  });

  final int currentPage;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onTapPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            _kBg,
            _kBg.withValues(alpha: 0.9),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _kDivider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ← Previous (in Quran RTL = higher page number)
                _NavBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: onNext, // RTL: left arrow = next page number
                ),
                // Page indicator (tap to jump)
                GestureDetector(
                  onTap: onTapPage,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$currentPage',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _kText)),
                      const Text('of 604',
                          style: TextStyle(
                              fontSize: 11, color: _kTextSub)),
                    ],
                  ),
                ),
                // → Next
                _NavBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: onPrev, // RTL: right arrow = lower page number
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onTap != null ? _kGoldMid : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: onTap != null ? _kGold : _kDivider, size: 28),
      ),
    );
  }
}
