import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _rippleController;
  late AnimationController _textController;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;
  late Animation<double> _rippleScale2;
  late Animation<double> _rippleOpacity2;
  
  final List<String> _words = ["MY", "MINDFUL", "ALIGNED", "DAY"];
  final List<Animation<double>> _wordOpacities = [];
  final List<Animation<double>> _wordSlides = [];
  final List<Animation<double>> _wordScales = [];
  final List<Animation<Color?>> _wordColors = [];

  @override
  void initState() {
    super.initState();

    // 1. Logo Animation (0s to 1.2s)
    // Snaps in with Curves.elasticOut and does a counterclockwise spin
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _logoRotation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    // 2. Dual Ripple Animation (0.3s to 1.3s)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Ripple 1: Gold, rapid
    _rippleScale = Tween<double>(begin: 0.5, end: 2.4).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _rippleOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // Ripple 2: Translucent White, trailing
    _rippleScale2 = Tween<double>(begin: 0.5, end: 3.2).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _rippleOpacity2 = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // 3. Tagline Word-by-word animation (0.6s to 1.8s)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final double step = 1.0 / _words.length;
    for (int i = 0; i < _words.length; i++) {
      final double start = i * step * 0.4; // Slightly tighter spacing for crispness
      final double end = (start + step).clamp(0.0, 1.0);
      
      _wordOpacities.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _textController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );

      _wordSlides.add(
        Tween<double>(begin: 20.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _textController,
            curve: Interval(start, end, curve: Curves.easeOutBack),
          ),
        ),
      );

      _wordScales.add(
        Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(
            parent: _textController,
            curve: Interval(start, end, curve: Curves.easeOutBack),
          ),
        ),
      );

      _wordColors.add(
        ColorTween(begin: AppColors.primary, end: AppColors.textPrimary).animate(
          CurvedAnimation(
            parent: _textController,
            curve: Interval(start, end, curve: Curves.easeIn),
          ),
        ),
      );
    }

    // Start execution sequence
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // Start Logo scale and spin
    _logoController.forward();

    // Trigger haptic and ripples at the moment of logo impact/settling
    Future.delayed(const Duration(milliseconds: 300), () {
      HapticFeedback.mediumImpact();
      _rippleController.forward();
    });

    // Start text animation
    Future.delayed(const Duration(milliseconds: 500), () {
      _textController.forward();
    });

    // Synchronized light haptic ticks for tagline words clicking into place
    // Step is 0.4 of word index, start timings relative to 500ms:
    // Word 0 (0.0): 500ms
    // Word 1 (0.1): 500 + 120 = 620ms
    // Word 2 (0.2): 500 + 240 = 740ms
    // Word 3 (0.3): 500 + 360 = 860ms
    Future.delayed(const Duration(milliseconds: 500), () => HapticFeedback.lightImpact());
    Future.delayed(const Duration(milliseconds: 620), () => HapticFeedback.lightImpact());
    Future.delayed(const Duration(milliseconds: 740), () => HapticFeedback.lightImpact());
    Future.delayed(const Duration(milliseconds: 860), () => HapticFeedback.lightImpact());

    // After 3.2 seconds total, navigate
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  void _checkAuthAndNavigate() {
    final session = supabaseClient.auth.currentSession;
    if (session == null) {
      context.go('/auth');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _rippleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Staggered Twin Ripples
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rippleController,
              builder: (context, child) {
                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ripple 1: Gold
                      Opacity(
                        opacity: _rippleOpacity.value,
                        child: Transform.scale(
                          scale: _rippleScale.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      ),
                      // Ripple 2: White/Translucent
                      Opacity(
                        opacity: _rippleOpacity2.value,
                        child: Transform.scale(
                          scale: _rippleScale2.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Logo & tagline
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScale.value,
                      child: Transform.rotate(
                        angle: _logoRotation.value * 2 * 3.14159,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(_words.length, (index) {
                        return Opacity(
                          opacity: _wordOpacities[index].value,
                          child: Transform.translate(
                            offset: Offset(0, _wordSlides[index].value),
                            child: Transform.scale(
                              scale: _wordScales[index].value,
                              child: Text(
                                _words[index],
                                style: AppTypography.body(
                                  size: 15,
                                  weight: FontWeight.w800,
                                  color: _wordColors[index].value,
                                ).copyWith(
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
