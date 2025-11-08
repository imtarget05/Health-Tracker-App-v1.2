import 'package:flutter/material.dart';
import 'package:healthy_tracker/helpers/extensions.dart';
import 'package:healthy_tracker/routing/routes.dart';
import 'package:healthy_tracker/theming/styles.dart';

class DontHaveAccountText extends StatelessWidget {
  const DontHaveAccountText({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(Routes.signupScreen),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: "Don’t have an account?",
              style: TextStyles.font11DarkBlue400Weight,
            ),
            TextSpan(
              text: ' Sign up',
              style: TextStyles.font11Blue600Weight,
            ),
          ],
        ),
      ),
    );
  }
}
