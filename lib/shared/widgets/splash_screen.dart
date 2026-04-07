import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../features/settings/providers/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  final Future<void> Function() onReady;

  const SplashScreen({super.key, required this.onReady});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _dotsController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _dotsOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.4, curve: Curves.easeIn),
      ),
    );

    _dotsOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _dotsController,
        curve: Curves.easeIn,
      ),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _dotsController.repeat(reverse: true);
    // Aguarda o callback externo (pluggy check + auth)
    await widget.onReady();
    // Pequena pausa para o usuário ver o loading
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      // Sinaliza ao pai que está pronto
      _dotsController.stop();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo animado
            ScaleTransition(
              scale: _logoScale,
              child: FadeTransition(
                opacity: _logoOpacity,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Quórum',
                      style: AppTextStyles.splineSans(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Finanças pessoais',
                      style: AppTextStyles.label(
                          Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
            // Dots de loading
            FadeTransition(
              opacity: _dotsOpacity,
              child: _LoadingDots(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -10).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    _startWave();
  }

  Future<void> _startWave() async {
    while (mounted) {
      for (int i = 0; i < _controllers.length; i++) {
        _controllers[i].forward();
        await Future.delayed(const Duration(milliseconds: 120));
      }
      await Future.delayed(const Duration(milliseconds: 200));
      for (final c in _controllers) {
        c.reverse();
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}