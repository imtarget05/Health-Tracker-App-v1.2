// Guard UIKit import so editors or tools that don't have iOS SDK available
// (SourceKit in some VS Code setups) won't report 'No such module UIKit'.
#if canImport(UIKit)
  import UIKit
#endif

// Guard Flutter import for editors that don't have Flutter module indexed.
#if canImport(Flutter)
  import Flutter
#endif

#if canImport(FirebaseCore)
  import FirebaseCore
#endif

#if canImport(FBSDKCoreKit)
  import FBSDKCoreKit
#endif

// Guard GoogleSignIn import so SourceKit won't fail when the iOS SDK or
// plugin modules aren't available in the editor environment.
#if canImport(GoogleSignIn)
  import GoogleSignIn
#endif

// Firebase and GoogleSignIn imports are guarded above; wrap the iOS-specific
// AppDelegate implementation so editors without the iOS SDK do not attempt to
// resolve UIKit/Foundation/Flutter symbols and produce errors.

// The actual AppDelegate implementation is only compiled when UIKit is available.
#if canImport(UIKit)
  @main
  @objc class AppDelegate: FlutterAppDelegate {
    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      // Configure Firebase
      if FirebaseApp.app() == nil {
        FirebaseApp.configure()
      }

      // Initialize Facebook SDK (safe if FB keys are missing - no-op in that case)
      if Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String != nil {
        ApplicationDelegate.shared.application(
          application,
          didFinishLaunchingWithOptions: launchOptions
        )
      }

      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Handle incoming URL (iOS < 13 and general handling)
    override func application(
      _ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
      // Let Google Sign-In SDK handle the URL if possible
      if GIDSignIn.sharedInstance.handle(url) {
        return true
      }
      // Let Facebook SDK handle the URL
      if ApplicationDelegate.shared.application(app, open: url, options: options) {
        return true
      }
      return super.application(app, open: url, options: options)
    }
  }
#endif
