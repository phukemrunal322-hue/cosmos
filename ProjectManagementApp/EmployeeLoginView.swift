import SwiftUI

struct EmployeeLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var isLoading = false
    
    // Dummy employee credentials
    private let dummyEmployee = User(
        email: "employee@trilogy.com",
        password: "employee123",
        name: "John Doe",
        role: .employee,
        profileImage: "person.circle"
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "briefcase.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        
                        Text("Employee Portal")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Trilogy Solution Consultancy")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Login Form
                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .padding()
                            .background(.background)
                            .cornerRadius(10)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $password)
                            .padding()
                            .background(.background)
                            .cornerRadius(10)
                        
                        Button(action: login) {
                            Text("Login as Employee")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        // Demo credentials
                        VStack(spacing: 5) {
                            Text("Demo Credentials")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Email: employee@trilogy.com")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Password: employee123")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Login Failed"),
                    message: Text("Invalid email or password"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func login() {
        if email == dummyEmployee.email && password == dummyEmployee.password {
            // Navigate to employee dashboard
            let rootView = EmployeeDashboardView()
                .environmentObject(AppState())
                .environmentObject(ThemeManager())
            if let window = UIApplication.shared.windows.first {
                window.rootViewController = UIHostingController(rootView: rootView)
                window.makeKeyAndVisible()
            }
        } else {
            showError = true
        }
    }
}
