// CreateTestUsers.swift
// Temporary helper to create test users
// Add this as a button in ContentView for initial setup, then remove

import SwiftUI

struct CreateTestUsersView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var message = ""
    @State private var showMessage = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Test Users")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Use this to create initial test accounts")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Divider()
            
            // Create Employee Button
            Button(action: {
                createEmployee()
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Create Test Employee")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // Create Client Button
            Button(action: {
                createClient()
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Create Test Client")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if showMessage {
                Text(message)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Test Credentials:")
                    .font(.headline)
                
                Group {
                    Text("Employee:")
                        .fontWeight(.semibold)
                    Text("Email: employee@test.com")
                    Text("Password: Test123!")
                    
                    Divider()
                    
                    Text("Client:")
                        .fontWeight(.semibold)
                    Text("Email: client@test.com")
                    Text("Password: Test123!")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
    }
    
    private func createEmployee() {
        authService.signUp(
            email: "employee@test.com",
            password: "Test123!",
            name: "Test Employee",
            role: .employee
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    message = "✅ Employee created: \(user.email)\nYou can now login with these credentials"
                    showMessage = true
                case .failure(let error):
                    message = "❌ Error: \(error.localizedDescription)"
                    showMessage = true
                }
            }
        }
    }
    
    private func createClient() {
        authService.signUp(
            email: "client@test.com",
            password: "Test123!",
            name: "Test Client",
            role: .client
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    message = "✅ Client created: \(user.email)\nYou can now login with these credentials"
                    showMessage = true
                case .failure(let error):
                    message = "❌ Error: \(error.localizedDescription)"
                    showMessage = true
                }
            }
        }
    }
}

// MARK: - How to Use
/*
 1. Temporarily add this to your ContentView:
 
    Button("Setup Test Users") {
        let setupView = CreateTestUsersView()
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UIHostingController(rootView: setupView)
            window.makeKeyAndVisible()
        }
    }
 
 2. Run the app and tap "Setup Test Users"
 3. Create both test users
 4. Remove this button from ContentView
 5. Test login with the created credentials
 */

struct CreateTestUsersView_Previews: PreviewProvider {
    static var previews: some View {
        CreateTestUsersView()
    }
}
