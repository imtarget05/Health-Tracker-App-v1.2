import 'package:flutter/material.dart';

import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';

class ProfileStatsCard extends StatelessWidget {
  final Animation<double> animation;
  final AnimationController animationController;
  final String calories;
  final String weight;
  final String height;

  const ProfileStatsCard({
    super.key,
    required this.animation,
    required this.animationController,
    this.calories = '0 kcal',
    this.weight = '0 kg',
    this.height = '0 cm',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: animation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FitnessAppTheme.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: "Năng lượng", value: calories),
                _StatItem(label: "Cân nặng", value: weight),
                _StatItem(label: "Chiều cao", value: height),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
