import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Extension pour animer une liste d'enfants avec décalage (staging).
extension StaggerAnimation on Widget {
  Widget staggerFadeSlide({
    int index = 0,
    int baseDelayMs = 0,
    int stepMs = 60,
    Duration duration = const Duration(milliseconds: 450),
    Offset beginOffset = const Offset(0, 0.08),
  }) {
    return animate(delay: (baseDelayMs + index * stepMs).ms)
        .fadeIn(duration: duration, curve: Curves.easeOut)
        .slideY(
          begin: beginOffset.dy,
          end: 0,
          duration: duration,
          curve: Curves.easeOut,
        );
  }
}
