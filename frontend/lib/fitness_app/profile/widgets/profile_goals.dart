import 'package:flutter/material.dart';

import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';

class ProfileGoalCard extends StatelessWidget {
  final Animation<double> animation;
  final AnimationController animationController;
  final List<String> goals;

  const ProfileGoalCard({
    super.key,
    required this.animation,
    required this.animationController,
    this.goals = const [],
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
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Daily Goal",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final g in goals) Text(g),
              ],
            ),
          ),
        );
      },
    );
  }
}
