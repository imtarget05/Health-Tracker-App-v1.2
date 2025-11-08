import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../helpers/app_regex.dart';
import '../../../routing/routes.dart';
import '../../../theming/styles.dart';
import '../../helpers/extensions.dart';
import '../../logic/cubit/auth_cubit.dart';
import 'app_text_button.dart';
import 'app_text_form_field.dart';
import 'password_validations.dart';

// ignore: must_be_immutable
class EmailAndPassword extends StatefulWidget {
  final bool? isSignUpPage;
  final bool? isPasswordPage;
  late GoogleSignInAccount? googleUser;
  late OAuthCredential? credential;

  EmailAndPassword({
    super.key,
    this.isSignUpPage,
    this.isPasswordPage,
    this.googleUser,
    this.credential,
  });

  @override
  State<EmailAndPassword> createState() => _EmailAndPasswordState();
}

class _EmailAndPasswordState extends State<EmailAndPassword> {
  bool isObscureText = true;
  bool hasMinLength = false;
  bool hasUpper = false;
  bool hasLower = false;
  bool hasDigit = false;
  bool hasSpecial = false;
  bool agreedToTerms = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmationController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  final passwordFocuseNode = FocusNode();
  final passwordConfirmationFocuseNode = FocusNode();

  @override
  void initState() {
    super.initState();
    setupPasswordControllerListener();
  }

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    passwordController.dispose();
    passwordConfirmationController.dispose();
    passwordFocuseNode.dispose();
    passwordConfirmationFocuseNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          // ✅ Thay animation Rive bằng ảnh PNG
          SizedBox(
            height: MediaQuery.of(context).size.height / 5,
            child: const Image(
              image: AssetImage('assets/images/doctor.png'),
              fit: BoxFit.contain,
            ),
          ),
          nameField(),
          emailField(),
          passwordField(),
          Gap(18.h),
          passwordConfirmationField(),
          forgetPasswordTextButton(),
          Gap(10.h),
          PasswordValidations(
            hasMinLength: hasMinLength,
            hasUppercase: hasUpper,
            hasLowercase: hasLower,
            hasDigit: hasDigit,
            hasSpecialChar: hasSpecial,
          ),
          Gap(20.h),
          if (widget.isSignUpPage == true)
            Row(
              children: [
                Checkbox(
                  value: agreedToTerms,
                  onChanged: (v) => setState(() => agreedToTerms = v ?? false),
                ),
                Expanded(
                  child: Text(
                    'I agree to the Terms & Privacy Policy',
                    style: TextStyles.font11MediumLightShadeOfGray400Weight,
                  ),
                ),
              ],
            ),
          loginOrSignUpOrPasswordButton(context)!,
        ],
      ),
    );
  }

  Widget emailField() {
    if (widget.isPasswordPage == null) {
      return Column(
        children: [
          AppTextFormField(
            hint: 'Email',
            validator: (value) {
              final email = (value ?? '').trim();
              emailController.text = email;

              if (email.isEmpty) {
                return 'Please enter an email address';
              }
              if (!AppRegex.isEmailValid(email)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            controller: emailController,
          ),
          Gap(18.h),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget forgetPasswordTextButton() {
    if (widget.isSignUpPage == null && widget.isPasswordPage == null) {
      return TextButton(
        onPressed: () {
          context.pushNamed(Routes.forgetScreen);
        },
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            'forget password?',
            style: TextStyles.font14Blue400Weight,
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  AppTextButton loginButton(BuildContext context) {
    return AppTextButton(
      buttonText: "Login",
      textStyle: TextStyles.font16White600Weight,
      onPressed: () async {
        passwordFocuseNode.unfocus();
        if (formKey.currentState!.validate()) {
          context.read<AuthCubit>().signInWithEmail(
                emailController.text,
                passwordController.text,
              );
        }
      },
    );
  }

  Widget? loginOrSignUpOrPasswordButton(BuildContext context) {
    if (widget.isSignUpPage == true) return signUpButton(context);
    if (widget.isSignUpPage == null && widget.isPasswordPage == null) {
      return loginButton(context);
    }
    if (widget.isPasswordPage == true) return passwordButton(context);
    return null;
  }

  Widget nameField() {
    if (widget.isSignUpPage == true) {
      return Column(
        children: [
          AppTextFormField(
            hint: 'Name',
            validator: (value) {
              final name = (value ?? '').trim();
              nameController.text = name;
              if (name.isEmpty) {
                return 'Please enter a valid name';
              }
              return null;
            },
            controller: nameController,
          ),
          Gap(18.h),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  AppTextButton passwordButton(BuildContext context) {
    return AppTextButton(
      buttonText: "Create Password",
      textStyle: TextStyles.font16White600Weight,
      onPressed: () async {
        passwordFocuseNode.unfocus();
        passwordConfirmationFocuseNode.unfocus();
        if (formKey.currentState!.validate()) {
          await context
              .read<AuthCubit>()
              .createAccountAndLinkItWithGoogleAccount(
                email: FirebaseAuth.instance.currentUser?.email ??
                    widget.googleUser?.email ??
                    emailController.text, // cuối cùng mới tới controller
                password: passwordController.text,
              );
        }
      },
    );
  }

  Widget passwordConfirmationField() {
    if (widget.isSignUpPage == true || widget.isPasswordPage == true) {
      return AppTextFormField(
        focusNode: passwordConfirmationFocuseNode,
        controller: passwordConfirmationController,
        hint: 'Password Confirmation',
        isObscureText: isObscureText,
        suffixIcon: GestureDetector(
          onTap: () {
            setState(() {
              isObscureText = !isObscureText;
            });
          },
          child: Icon(
            isObscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
        validator: (value) {
          if (value != passwordController.text) {
            return 'Enter a matched passwords';
          }
          if (value == null ||
              value.isEmpty ||
              !AppRegex.isPasswordValid(value)) {
            return 'Please enter a valid password';
          }
          return null;
        },
      );
    }
    return const SizedBox.shrink();
  }

  AppTextFormField passwordField() {
    return AppTextFormField(
      focusNode: passwordFocuseNode,
      controller: passwordController,
      hint: 'Password',
      isObscureText: isObscureText,
      suffixIcon: GestureDetector(
        onTap: () {
          setState(() {
            isObscureText = !isObscureText;
          });
        },
        child: Icon(
          isObscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
      validator: (value) {
        if (value == null ||
            value.isEmpty ||
            !AppRegex.isPasswordValid(value)) {
          return 'Please enter a valid password';
        }
        return null;
      },
    );
  }

  void setupPasswordControllerListener() {
    passwordController.addListener(() {
      setState(() {
        final pwd = passwordController.text;
        hasMinLength = AppRegex.isPasswordMinLength(pwd);
        hasUpper = AppRegex.hasUppercase(pwd);
        hasLower = AppRegex.hasLowercase(pwd);
        hasDigit = AppRegex.hasDigit(pwd);
        hasSpecial = AppRegex.hasSpecialChar(pwd);
      });
    });
  }

  AppTextButton signUpButton(BuildContext context) {
    return AppTextButton(
      buttonText: "Create Account",
      textStyle: TextStyles.font16White600Weight,
      onPressed: () async {
        passwordFocuseNode.unfocus();
        passwordConfirmationFocuseNode.unfocus();
        if (!agreedToTerms) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please agree to Terms & Privacy Policy.'),
            ),
          );
          return;
        }
        if (formKey.currentState!.validate()) {
          context.read<AuthCubit>().signUpWithEmail(
                nameController.text,
                emailController.text,
                passwordController.text,
              );
        }
      },
    );
  }
}
