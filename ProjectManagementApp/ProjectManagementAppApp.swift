import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        if let o = FirebaseApp.app()?.options {
            print("Firebase ProjectID:", o.projectID ?? "nil")
            print("BundleID:", Bundle.main.bundleIdentifier ?? "nil")
        }
        return true
    }
}

@main
struct ProjectManagementApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.colorScheme)
                .tint(themeManager.accentColor)
                .environmentObject(themeManager)
        }
    }
}
