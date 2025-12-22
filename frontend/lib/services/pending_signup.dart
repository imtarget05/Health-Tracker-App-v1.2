class PendingSignup {
  // temporarily store signup info between Register -> Onboarding -> Habit
  static Map<String, String?>? data;

  static void set({required String email, required String password, required String fullName, String? phone}) {
    data = {
      'email': email,
      'password': password,
      'fullName': fullName,
      'phone': phone,
    };
  }

  static Map<String, String?>? consume() {
    final d = data;
    data = null;
    return d;
  }

  // Peek at pending signup without consuming it.
  static Map<String, String?>? peek() {
    return data;
  }
}
