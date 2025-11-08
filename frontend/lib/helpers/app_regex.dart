class AppRegex {
  static bool isEmailValid(String email) {
    return RegExp(r'^.+@[a-zA-Z]+\.{1}[a-zA-Z]+(\.{0,1}[a-zA-Z]+)$')
        .hasMatch(email);
  }

  static bool isPasswordMinLength(String password) {
    return RegExp(r'^.{6,}$').hasMatch(password);
  }

  static bool hasUppercase(String password) {
    return RegExp(r'[A-Z]').hasMatch(password);
  }

  static bool hasLowercase(String password) {
    return RegExp(r'[a-z]').hasMatch(password);
  }

  static bool hasDigit(String password) {
    return RegExp(r'\d').hasMatch(password);
  }

  static bool hasSpecialChar(String password) {
    return RegExp(r'[!@#\$%\^&*(),.?":{}|<>_\-]').hasMatch(password);
  }

  static bool isPasswordValid(String password) {
    return isPasswordMinLength(password) &&
        hasUppercase(password) &&
        hasLowercase(password) &&
        hasDigit(password) &&
        hasSpecialChar(password);
  }
}
