import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:best_flutter_ui_templates/fitness_app/models/meals_list_data.dart';
import 'package:best_flutter_ui_templates/main.dart';
import 'package:flutter/material.dart';

class MealsListView extends StatefulWidget {
  const MealsListView({
    super.key,
    this.mainScreenAnimationController,
    this.mainScreenAnimation,
    this.diary,
    this.profile,
    this.localSlotTotals,
  });

  final AnimationController? mainScreenAnimationController;
  final Animation<double>? mainScreenAnimation;
  final dynamic diary;
  final Map<String, dynamic>? profile;
  final Map<String, Map<String, int>>? localSlotTotals;

  @override
  State<MealsListView> createState() => _MealsListViewState();
}

class _MealsListViewState extends State<MealsListView>
    with TickerProviderStateMixin {
  final List<MealsListData> mealsListData = MealsListData.tabIconsList;
  AnimationController? internalController;

  @override
  Widget build(BuildContext context) {
    final slotNames = ['Breakfast', 'Lunch', 'Snack', 'Dinner'];
    // Use provided animation if available; otherwise render static list.
    final animationController = widget.mainScreenAnimationController;
    final animation = widget.mainScreenAnimation;

    return SizedBox(
      height: 240,
      width: double.infinity,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 0, bottom: 0, right: 16, left: 16),
        itemCount: slotNames.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          final slotKey = slotNames[index].toLowerCase();
          int kcalForSlot = 0;
          List<String> mealNames = [];

          // Extract meals from diary if available
          try {
            if (widget.diary != null && widget.diary.meals != null) {
              for (var m in widget.diary.meals) {
                try {
                  final type = (m.type ?? '').toString().toLowerCase();
                  if (type == slotKey) {
                    if (m.kcal != null) kcalForSlot += (m.kcal as num).toInt();
                    if (m.name != null) mealNames.add(m.name.toString());
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}

          // fallback to localSlotTotals if diary empty
          if ((widget.diary == null || widget.diary.meals == null || (widget.diary.meals is List && widget.diary.meals.isEmpty)) && widget.localSlotTotals != null) {
            try {
              kcalForSlot = widget.localSlotTotals![slotKey]?['calories'] ?? kcalForSlot;
            } catch (_) {}
          }

          final fallback = mealsListData[index % mealsListData.length];
          final displayData = MealsListData(
            titleTxt: slotNames[index],
            meals: mealNames.isNotEmpty ? mealNames : fallback.meals,
            imagePath: fallback.imagePath,
            startColor: fallback.startColor,
            endColor: fallback.endColor,
            kacl: kcalForSlot != 0 ? kcalForSlot : fallback.kacl,
          );

          // If animations provided, create staggered animation for item
          if (animationController != null && animation != null) {
            final start = (index * 0.1).clamp(0.0, 1.0);
            final end = ((index + 1) * 0.1 + 0.2).clamp(0.0, 1.0);
            final itemAnimation = CurvedAnimation(
              parent: animationController,
              curve: Interval(start, end, curve: Curves.easeOut),
            );

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FadeTransition(
                opacity: itemAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(itemAnimation),
                  child: MealsView(
                    key: ValueKey('meals_slot_$index'),
                    slotKey: slotKey,
                    mealsListData: displayData,
                    profile: widget.profile,
                    localSlotTotals: widget.localSlotTotals,
                  ),
                ),
              ),
            );
          }

          // static fallback
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: MealsView(
              key: ValueKey('meals_slot_$index'),
              slotKey: slotKey,
              mealsListData: displayData,
              profile: widget.profile,
              localSlotTotals: widget.localSlotTotals,
            ),
          );
        },
      ),
    );
  }
}

class MealsView extends StatelessWidget {
  const MealsView({
    super.key,
    required this.slotKey,
    required this.mealsListData,
    this.profile,
    this.localSlotTotals,
  });

  final String slotKey;
  final MealsListData mealsListData;
  final Map<String, dynamic>? profile;
  final Map<String, Map<String, int>>? localSlotTotals;

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }

  // Compute an integer recommendation for the given slot based on profile target
  // and the aggregated localSlotTotals. Returns null if no recommendation.
  int? _computeRecommendationForSlot(String slotKey) {
    try {
      if (profile == null) return null;
      final targetRaw = profile!['targetCaloriesPerDay'];
      if (targetRaw == null) return null;
      final target = (targetRaw is num) ? targetRaw.toInt() : int.tryParse(targetRaw.toString());
      if (target == null) return null;

  final slots = ['breakfast', 'lunch', 'snack', 'dinner'];
      final totals = localSlotTotals ?? <String, Map<String,int>>{};

      // compute sum of known calories
      int consumedByKnown = 0;
      for (final s in slots) {
        consumedByKnown += totals[s]?['calories'] ?? 0;
      }

      final remaining = target - consumedByKnown;
      if (remaining <= 0) return null;

      // count empty slots (those with zero calories)
      int emptySlots = 0;
      for (final s in slots) {
        final c = totals[s]?['calories'] ?? 0;
        if (c == 0) emptySlots++;
      }
      if (emptySlots == 0) return null;

      // recommended per-empty-slot (integer division)
      final perSlot = (remaining ~/ emptySlots).clamp(0, remaining);
      return perSlot;
    } catch (_) {
      return null;
    }
  }

  Widget _buildCard(BuildContext context) {
    return SizedBox(
      // slightly wider to avoid tiny right-overflow markers on some devices
      width: 150,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 32, left: 8, right: 8, bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: HexColor(mealsListData.endColor).withAlpha((0.6 * 255).round()),
                    offset: const Offset(1.1, 4.0),
                    blurRadius: 8.0,
                  ),
                ],
                gradient: LinearGradient(
                  colors: <HexColor>[
                    HexColor(mealsListData.startColor),
                    HexColor(mealsListData.endColor),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(8.0),
                  bottomLeft: Radius.circular(8.0),
                  topLeft: Radius.circular(8.0),
                  topRight: Radius.circular(54.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 40, left: 12, right: 12, bottom: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mealsListData.titleTxt,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.2,
                        color: FitnessAppTheme.white,
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 68),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // If there are explicit meal names, render them as bullets.
                                  // Otherwise, render a single bullet with the recommendation
                                  if ((mealsListData.meals ?? []).isNotEmpty)
                                    for (final m in (mealsListData.meals ?? []))
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('\u2022 ', style: TextStyle(color: FitnessAppTheme.white)),
                                            SizedBox(
                                              width: 72,
                                              child: Text(
                                                m,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: FitnessAppTheme.fontName,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 9,
                                                  letterSpacing: 0.2,
                                                  color: FitnessAppTheme.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                  else
                                    // use fallback samples from MealsListData.tabIconsList for this slot
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2.0),
                                      child: Builder(builder: (ctx) {
                                        final rec = _computeRecommendationForSlot(this.slotKey);
                                        // find fallback entry by title matching the canonical slotKey
                                        final fallback = MealsListData.tabIconsList.firstWhere(
                                          (e) => e.titleTxt.toLowerCase() == this.slotKey,
                                          orElse: () => MealsListData(),
                                        );
                                        final fallbackMeals = (fallback.meals ?? []).where((s) => s.trim().isNotEmpty).toList();
                                        if (fallbackMeals.isNotEmpty) {
                                          // render up to two fallback items as bullets
                                          final items = fallbackMeals.take(2).toList();
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              for (final f in items)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 2.0),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('\u2022 ', style: TextStyle(color: FitnessAppTheme.white)),
                                                      SizedBox(
                                                        width: 72,
                                                        child: Text(
                                                          f,
                                                          style: TextStyle(
                                                            fontFamily: FitnessAppTheme.fontName,
                                                            fontWeight: FontWeight.w500,
                                                            fontSize: 9,
                                                            letterSpacing: 0.2,
                                                            color: FitnessAppTheme.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              // then render recommendation if available
                                              if (rec != null && rec > 0)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Text('Recommend: ~${rec.toString()} kcal', style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: FitnessAppTheme.white.withAlpha((0.95 * 255).round()))),
                                                ),
                                            ],
                                          );
                                        }
                                        // fallback to showing recommendation only
                                        if (rec != null && rec > 0) {
                                          return Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('\u2022 ', style: TextStyle(color: FitnessAppTheme.white)),
                                              SizedBox(
                                                width: 72,
                                                child: Text(
                                                  'Recommend: ~${rec.toString()} kcal',
                                                  style: TextStyle(
                                                    fontFamily: FitnessAppTheme.fontName,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 9,
                                                    letterSpacing: 0.2,
                                                    color: FitnessAppTheme.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          // If card has calories, show them; otherwise try to show a computed recommendation
          mealsListData.kacl != 0
            ? Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                mealsListData.kacl.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 24,
                                  letterSpacing: 0.2,
                                  color: FitnessAppTheme.white,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 3),
                                child: Text(
                                  'kcal',
                                  style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10,
                                    letterSpacing: 0.2,
                                    color: FitnessAppTheme.white,
                                  ),
                                ),
                              ),
                            ],
                          )
            : Builder(builder: (ctx) {
              final rec = _computeRecommendationForSlot(this.slotKey);
                            if (rec != null && rec > 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  'Recommend: ~${rec.toString()} kcal',
                                  style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName,
                                    fontSize: 12,
                                    color: FitnessAppTheme.white.withAlpha((0.95 * 255).round()),
                                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                '—',
                                style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 20,
                                  color: FitnessAppTheme.white,
                                ),
                              ),
                            );
                          }),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FitnessAppTheme.nearlyWhite.withAlpha((0.2 * 255).round()),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 6,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Image.asset(mealsListData.imagePath),
            ),
          )
        ],
      ),
    );
  }
}
