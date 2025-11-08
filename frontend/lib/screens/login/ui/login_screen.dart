import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_offline/flutter_offline.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../../../core/widgets/login_and_signup_animated_form.dart';
import '../../../core/widgets/no_internet.dart';
import '../../../core/widgets/progress_indicator_helper.dart';
import '../../../core/widgets/sign_in_with_google_text.dart';
import '../../../core/widgets/terms_and_conditions_text.dart';
import '../../../helpers/extensions.dart';
import '../../../logic/cubit/auth_cubit.dart';
import '../../../routing/routes.dart';
import '../../../theming/styles.dart';
import 'widgets/do_not_have_account.dart';
import '../../../core/widgets/png_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    BlocProvider.of<AuthCubit>(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OfflineBuilder(
        connectivityBuilder: (
          BuildContext context,
          ConnectivityResult connectivity,
          Widget child,
        ) {
          final bool connected = connectivity != ConnectivityResult.none;
          return connected ? _loginPage(context) : const BuildNoInternet();
        },
        // Thay vì Rive animation, hiển thị ảnh PNG
        child: Center(
          child: PngControllerHelper().getImageWidget(height: 200),
        ),
      ),
    );
  }

  SafeArea _loginPage(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(left: 30.w, right: 30.w, bottom: 15.h, top: 5.h),
        child: SingleChildScrollView(
          child: BlocConsumer<AuthCubit, AuthState>(
            buildWhen: (previous, current) => previous != current,
            listenWhen: (previous, current) => previous != current,
            listener: (context, state) async {
              if (state is AuthLoading) {
                ProgressIndicaror.showProgressIndicator(context);
              } else if (state is AuthError) {
                context.pop();
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.error,
                  title: 'Error',
                  desc: (state.message != ''
                      ? state.message
                      : 'Authentication error'),
                ).show();
              } else if (state is UserSignIn) {
                debugPrint('UserSignIn state triggered');
                if (!context.mounted) return;
                context.pushNamedAndRemoveUntil(
                  Routes.homeScreen,
                  predicate: (route) => false,
                );
              } else if (state is UserNotVerified) {
                if (!context.mounted) return;
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.info,
                  animType: AnimType.rightSlide,
                  title: 'Email Not Verified',
                  desc:
                      'Please check your email and verify your account. If you didn\'t receive the email, we can send it again.',
                  btnCancelOnPress: () {},
                  btnOkOnPress: () {
                    context
                        .read<AuthCubit>()
                        .resendVerificationEmail(state.email, state.password);
                  },
                  btnCancelText: 'Cancel',
                  btnOkText: 'Resend Email',
                ).show();
              } else if (state is VerificationEmailSent) {
                context.pop();
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.success,
                  animType: AnimType.rightSlide,
                  title: 'Email Sent',
                  desc:
                      'Verification email has been sent. Please check your inbox.',
                ).show();
              } else if (state is IsNewUser) {
                if (!context.mounted) return;
                context.pushNamedAndRemoveUntil(
                  Routes.createPassword,
                  predicate: (route) => false,
                  arguments: [state.googleUser, state.credential],
                );
              }
            },
            builder: (context, state) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login',
                          style: TextStyles.font24Blue700Weight,
                        ),
                        Gap(10.h),
                        Text(
                          "Login To Continue Using The App",
                          style: TextStyles.font14Grey400Weight,
                        ),
                      ],
                    ),
                  ),
                  Gap(20.h),
                  EmailAndPassword(),
                  Gap(10.h),
                  const SigninWithGoogleText(),
                  Gap(5.h),
                  InkWell(
                    radius: 50.r,
                    onTap: () {
                      context.read<AuthCubit>().signInWithGoogle();
                    },
                    child: SvgPicture.asset(
                      'assets/svgs/google_logo.svg',
                      width: 40.w,
                      height: 40.h,
                    ),
                  ),
                  const TermsAndConditionsText(),
                  Gap(15.h),
                  TextButton(
                    onPressed: () {
                      context.read<AuthCubit>().reloadAndCheckVerification();
                    },
                    child: const Text("I've verified, continue"),
                  ),
                  Gap(15.h),
                  const DontHaveAccountText(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
