import SwiftUI

struct AdminLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var isLoading = false
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case email, password }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient - Purple/Indigo theme for Admin
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.4, green: 0.2, blue: 0.8),
                        Color(red: 0.6, green: 0.3, blue: 0.9)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer(minLength: 50)
                        
                        // Header
                        VStack(spacing: 15) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            
                            Text("Admin Portal")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Cosmos Solution Consultancy")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("Administrative Access")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                        }
                        
                        // Login Form
                        VStack(spacing: 20) {
                            // Email Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                TextField("Enter your email", text: $email)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(10)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                            }
                            
                            // Password Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    if isPasswordVisible {
                                        TextField("Enter your password", text: $password)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .focused($focusedField, equals: .password)
                                            .submitLabel(.go)
                                            .onSubmit { login() }
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .focused($focusedField, equals: .password)
                                            .submitLabel(.go)
                                            .onSubmit { login() }
                                    }
                                    
                                    Button(action: {
                                        isPasswordVisible.toggle()
                                    }) {
                                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.trailing, 8)
                                }
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(10)
                            }
                            
                            Button(action: login) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Login as Admin")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    !email.isEmpty && !password.isEmpty ?
                                    Color.white :
                                    Color.white.opacity(0.5)
                                )
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.8))
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                            }
                            .disabled(email.isEmpty || password.isEmpty || isLoading)
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Login Failed"),
                    message: Text("Invalid email or password, or insufficient permissions"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func login() {
        isLoading = true
        
        FirebaseAuthService.shared.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let (user, role)):
                    if role == .admin {
                        print("✅ Admin login successful for \(user.email)")
                        // Navigate to Admin dashboard
                        let rootView = AdminDashboardView()
                            .environmentObject(AppState())
                            .environmentObject(ThemeManager())
                        if let window = UIApplication.shared.windows.first {
                            window.rootViewController = UIHostingController(rootView: rootView)
                            window.makeKeyAndVisible()
                        }
                    } else {
                        showError = true
                    }
                    
                case .failure(_):
                    showError = true
                }
            }
        }
    }
}
