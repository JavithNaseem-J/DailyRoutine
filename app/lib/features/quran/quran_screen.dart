import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../main.dart' show sharedPrefs;
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
    _pinnedPage = sharedPrefs.getInt('quran_pinned_page');
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int idx) {
    setState(() => _currentPage = idx + 1);
    sharedPrefs.setInt('quran_last_page', _currentPage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFBF8F1), // Slight warm paper color
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Page $_currentPage',
          style: AppTypography.screenTitle(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _pinnedPage == _currentPage
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _pinnedPage == _currentPage
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            onPressed: () {
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
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Khatm Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Khatm Progress',
                      style: AppTypography.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${((_currentPage / 604) * 100).toStringAsFixed(1)}%',
                      style: AppTypography.mono(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _currentPage / 604,
                  backgroundColor: AppColors.surfaceRaised,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
                if (_pinnedPage != null && _pinnedPage != _currentPage) ...[
                  SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _pageController.jumpToPage(_pinnedPage! - 1);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.turn_right_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Jump to Pinned Page $_pinnedPage',
                          style: AppTypography.body(
                            size: 13,
                            weight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: 604,
              reverse: true, // Arabic is RTL
              itemBuilder: (context, index) {
                final pageNum = index + 1; // 1 to 604
                return _buildQuranPage(pageNum);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuranPage(int page) {
    final pageData = quran.getPageData(page);
    List<Widget> content = [];

    for (int i = 0; i < pageData.length; i++) {
      final data = pageData[i];
      final surah = data['surah'] as int;
      final start = data['start'] as int;
      final end = data['end'] as int;

      // Render Surah Banner if it starts at 1
      if (start == 1) {
        content.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              quran.getSurahNameArabic(surah),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Amiri', // Or default if Amiri isn't added
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        );

        // Bismillah for all except Surah At-Tawbah (9) and Al-Fatihah (1) has it inside ayah 1.
        if (surah != 1 && surah != 9) {
          content.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Center(
                child: Text(
                  quran.basmala,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 22,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }
      }

      // Concatenate verses for this section
      String verses = "";
      for (int v = start; v <= end; v++) {
        verses += "${quran.getVerse(surah, v, verseEndSymbol: true)} ";
      }

      content.add(
        Text(
          verses,
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily:
                'Amiri', // Will fallback to system arabic font if not present
            fontSize: 24,
            height: 1.8,
            color: Colors.black87,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(children: content),
    );
  }
}
