Run the app against the Firebase Emulator Suite (local dev)

Prerequisites
- Install the Firebase CLI: https://firebase.google.com/docs/cli
- Start the Emulator Suite in the project directory (where `firebase.json` lives):

  firebase emulators:start --only firestore,auth,storage

How to run the Flutter app against the emulators
- Start the Emulator Suite (previous step).
- Run the app with a Dart define so the Flutter app wires to localhost emulators:

  flutter run --dart-define=USE_FIREBASE_EMULATOR=1

Notes
- By default this repo expects Firestore emulator on localhost:8080 and Auth emulator on localhost:9099.
- If you want to use the emulator in the backend server, set environment variable `USE_FIREBASE_EMULATOR=1` before starting the backend:

  USE_FIREBASE_EMULATOR=1 npm run dev

- Emulator mode avoids needing a real service account and prevents permission-denied errors when running locally.
