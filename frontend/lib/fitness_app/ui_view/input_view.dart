import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../fitness_app_theme.dart';


class InputView extends StatelessWidget {
  final AnimationController? animationController;
  final Animation<double>? animation;
  final String title;
  final String hint;
  final TextEditingController controller;
  final bool isNumber;
  final List<String>? options;
  final String? suffixText;
  final bool readOnly;
  final VoidCallback? onTap;

  const InputView({
    super.key,
    this.animationController,
    this.animation,
    required this.title,
    required this.hint,
    required this.controller,
    this.isNumber = false,
  this.options,
  this.suffixText,
  this.readOnly = false,
  this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController!,
      builder: (BuildContext context, Widget? child) {
        return FadeTransition(
          opacity: animation!,
          child: Transform(
            transform: Matrix4.translationValues(
                0.0, 30 * (1.0 - animation!.value), 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ===== TITLE =====
                Padding(
                  padding: const EdgeInsets.only(left: 48, right: 32, bottom: 0, top: 20),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: FitnessAppTheme.nearlyDarkBlue,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: FitnessAppTheme.white,
                      borderRadius: const BorderRadius.all(Radius.circular(64)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: FitnessAppTheme.grey.withAlpha((0.4 * 255).round()),
                          offset: const Offset(1.1, 1.1),
                          blurRadius: 10.0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: (options != null && options!.isNotEmpty)
                          ? Builder(builder: (context) {
                              final dropdown = DropdownButtonFormField<String>(
                                initialValue: controller.text.isNotEmpty && options!.contains(controller.text) ? controller.text : null,
                                items: options!.map((o) => DropdownMenuItem<String>(value: o, child: Text(o))).toList(),
                                onChanged: (v) {
                                  if (v != null) controller.text = v;
                                },
                                decoration: InputDecoration(
                                  hintText: hint,
                                  fillColor: FitnessAppTheme.nearlyWhite,
                                  filled: true,
                                  suffixText: suffixText,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                              );

                              if (readOnly || onTap != null) {
                                return GestureDetector(onTap: onTap ?? () {}, child: AbsorbPointer(child: dropdown));
                              }

                              return dropdown;
                            })
                          : TextField(
                              controller: controller,

                              keyboardType: isNumber ? TextInputType.number : TextInputType.text,

                              inputFormatters: isNumber
                                  ? [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ]
                                  : null,

                              decoration: InputDecoration(
                                  hintText: hint,
                                  fillColor: FitnessAppTheme.nearlyWhite,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
