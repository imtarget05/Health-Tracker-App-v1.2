Flutter Google Sign-In -> Backend (Health-Tracker-App)

1) Add dependency in `pubspec.yaml`:

```yaml
dependencies:
  google_sign_in: ^6.0.0
  http: ^0.13.0
```

2) Example usage

```dart
import 'package:your_app/services/google_auth_service.dart';

final svc = GoogleAuthService();
try {
  final result = await svc.signInToBackend('http://10.0.2.2:5001'); // or http://127.0.0.1:5001 for macOS
  // result contains { uid, fullName, email, profilePic, token }
  // Store token in secure storage for mobile if needed
} catch (e) {
  print('Google sign-in failed: $e');
}
```

3) Notes
- Ensure `GOOGLE_CLIENT_ID` in backend `.env` matches OAuth client used by the app.
- For Android emulator, use `10.0.2.2` to reach host machine.
- Backend endpoint is `/auth/google` and expects `{ idToken }`.

4) Quick curl test (obtain id_token from OAuth Playground and POST):

```bash
curl -v -X POST http://127.0.0.1:5001/auth/google \
  -H "Content-Type: application/json" \
  -d '{"idToken":"PASTE_ID_TOKEN_HERE"}'
```
