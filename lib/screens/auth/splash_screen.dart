import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/decor.dart';

/// Green reading room; the lamp switches on while the app connects.
class SplashScreen extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const SplashScreen({super.key, this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return Scaffold(
      body: RoomPanel(
        radius: BorderRadius.zero,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: still ? 1.0 : 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutBack,
                    builder: (_, v, child) => Transform.scale(
                      scale: 0.6 + 0.4 * v,
                      child: Opacity(
                        opacity: v.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(color: AppColors.lamp.withAlpha((110 * v).round()), blurRadius: 40 * v, spreadRadius: 4 * v),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    ),
                    child: const Icon(Icons.local_library_rounded, size: 56, color: AppColors.green),
                  ),
                  const SizedBox(height: 22),
                  Text(AppConfig.appName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Seats, fees and students in one place', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 36),
                  if (error == null)
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(color: AppColors.lamp, strokeWidth: 3),
                    )
                  else ...[
                    Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        minimumSize: const Size(160, 46),
                      ),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
