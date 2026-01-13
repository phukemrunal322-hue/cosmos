import Combine
import Foundation
import SwiftUI

class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var userRole: UserRole?
    
    func login(user: User) {
        self.currentUser = user
        self.userRole = user.role
    }
    
    func logout() {
        // Logout from Firebase
        FirebaseAuthService.shared.logout { result in
            switch result {
            case .success():
                print("✅ Logged out from Firebase")
            case .failure(let error):
                print("❌ Logout error: \(error.localizedDescription)")
            }
        }
        
        self.currentUser = nil
        self.userRole = nil
        
        // Navigate back to ContentView
        DispatchQueue.main.async {
            let rootView = ContentView().environmentObject(ThemeManager())
            if let window = UIApplication.shared.windows.first {
                window.rootViewController = UIHostingController(rootView: rootView)
                window.makeKeyAndVisible()
            }
        }
    }
}
