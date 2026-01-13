import SwiftUI

struct ContentView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSplashScreen = true
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isPasswordVisible = false
    @StateObject private var appState = AppState()
    @State private var showEmployeeDashboard = false
    @State private var showClientDashboard = false
    @State private var showManagerDashboard = false
    @State private var showSuperAdminDashboard = false
    @State private var showAdminDashboard = false
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case email, password }
    
    var body: some View {
        ZStack {
            if showSplashScreen {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showSplashScreen = false
                            }
                        }
                    }
            } else {
                NavigationView {
                    ZStack {
                        // Background image
                        Image("background_image")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                            .ignoresSafeArea()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        
                        // Overlay for better text visibility
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.6),
                                Color.black.opacity(0.4),
                                Color.black.opacity(0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 20) {
                                    // App Icon and Title
                                    VStack(spacing: 15) {
                                        Image("company_logo")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 100, height: 100)
                                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                            .padding(.horizontal, 20)
                                        
                                        Text("Cosmos Solution Consultancy")
                                            .font(.custom("Arial", size: 32))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                        
                                        Text("Triology Business Lab")
                                            .font(.headline)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.top, 30)
                                    
                                    // Login Form - Role selection removed
                                    VStack(spacing: 25) {
                                        Text("Login")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        
                                        // Email Input
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Email")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            TextField("Enter your email", text: $email)
                                                .padding()
                                                .background(.background)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.yellow, lineWidth: 2)
                                                )
                                                .cornerRadius(8)
                                                .keyboardType(.emailAddress)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled(true)
                                                .focused($focusedField, equals: .email)
                                                .submitLabel(.next)
                                                .onSubmit { focusedField = .password }
                                                .id("emailField")
                                                .onTapGesture {
                                                    withAnimation(.easeInOut(duration: 0.25)) {
                                                        proxy.scrollTo("emailField", anchor: .center)
                                                    }
                                                }
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
                                            .id("passwordField")
                                            .onTapGesture {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    proxy.scrollTo("passwordField", anchor: .center)
                                                }
                                            }
                                            .background(.background)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.yellow, lineWidth: 2)
                                            )
                                            .cornerRadius(8)
                                            .cornerRadius(8)
                                        }
                                        
                                        // Forgot Password Button
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                withAnimation {
                                                    showForgotPassword = true
                                                }
                                            }) {
                                                Text("Forgot Password?")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                            }
                                        }
                                        .padding(.top, -15)
                                        .padding(.bottom, 5)
                                        
                                        Button(action: login) {
                                            Text("Login")
                                                .fontWeight(.semibold)
                                                .font(.title3)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(
                                                    !email.isEmpty && !password.isEmpty ?
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color(red: 0.0, green: 0.6, blue: 0.4),  // Peacock green
                                                            Color(red: 0.2, green: 0.8, blue: 0.6),  // Lighter green
                                                            Color(red: 0.1, green: 0.7, blue: 0.5),  // Mid green
                                                            Color(red: 0.0, green: 0.5, blue: 0.3)   // Dark green
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ) :
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.5)]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .foregroundColor(.white)
                                                .cornerRadius(15)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 15)
                                                        .stroke(!email.isEmpty && !password.isEmpty ? Color.yellow : Color.gray.opacity(0.5), lineWidth: 2)
                                                )
                                                .shadow(color: !email.isEmpty && !password.isEmpty ? Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.4) : Color.clear, radius: 10, x: 0, y: 5)
                                        }
                                        .disabled(email.isEmpty || password.isEmpty)
                                        .padding(.top, 10)
                                    }
                                    .padding(.horizontal, 40)
                                    
                                    Spacer()
                                    
                                    // Footer
                                    VStack(spacing: 8) {
                                        Divider()
                                            .background(Color.white.opacity(0.3))
                                        
                                        Text("ERP System • Triology Business Lab")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        Text("v1.0.0 • Secure & Professional")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(.bottom, 20)
                                }
                                .padding(.bottom, (focusedField == nil) ? 0 : 260)
                                .animation(.easeInOut(duration: 0.25), value: focusedField != nil)
                                .onChange(of: focusedField) { field in
                                    guard let field = field else { return }
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(field == .email ? "emailField" : "passwordField", anchor: .center)
                                    }
                                }
                                .onTapGesture { focusedField = nil }
                            }
                        }
                    }
                }
                .navigationViewStyle(DefaultNavigationViewStyle())
                .transition(.opacity)
                .alert(isPresented: $showError) {
                    Alert(
                        title: Text("Login Failed"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .fullScreenCover(isPresented: $showEmployeeDashboard) {
                    EmployeeDashboardView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                        .tint(themeManager.accentColor)
                }
                .fullScreenCover(isPresented: $showClientDashboard) {
                    ClientDashboardView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                        .tint(themeManager.accentColor)
                }
                .fullScreenCover(isPresented: $showManagerDashboard) {
                    ManagerDashboardView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                        .tint(themeManager.accentColor)
                }
                .fullScreenCover(isPresented: $showSuperAdminDashboard) {
                    SuperAdminDashboardView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                        .tint(themeManager.accentColor)
                }
                .fullScreenCover(isPresented: $showAdminDashboard) {
                    AdminDashboardView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                        .tint(themeManager.accentColor)
                }
                .preferredColorScheme(themeManager.colorScheme)
                .tint(themeManager.accentColor)
            }
            
            // Forgot Password Overlay
            if showForgotPassword {
                ForgotPasswordOverlay(isPresented: $showForgotPassword, email: email)
                    .zIndex(2)
                    .transition(.opacity)
            }
        }
    }
    
    private func login() {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter email and password"
            showError = true
            return
        }
        
        authService.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (user, role)):
                    print("✅ Login successful for \(user.email) with role: \(role)")
                    
                    // Navigate based on role instantly using SwiftUI fullScreenCover
                    appState.login(user: user)
                    switch role {
                    case .client:
                        showClientDashboard = true
                    case .employee:
                        showEmployeeDashboard = true
                    case .manager:
                        showManagerDashboard = true
                    case .admin:
                        showAdminDashboard = true
                    case .superAdmin:
                        showSuperAdminDashboard = true
                    }
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                    print("❌ Login failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Splash Screen View
struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var cosmosOpacity: Double = 0.0
    @State private var cosmosScale: CGFloat = 0.8
    @State private var solutionOpacity: Double = 0.0
    @State private var solutionScale: CGFloat = 0.8
    @State private var consultancyOpacity: Double = 0.0
    @State private var consultancyScale: CGFloat = 0.8
    @State private var triologyOpacity: Double = 0.0
    @State private var showProgress: Bool = false
    
    var body: some View {
        ZStack {
            // Background image with subtle animation
            Image("background_image")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .ignoresSafeArea()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.5)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // Logo with quick entrance
                Image("company_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: .white.opacity(0.3), radius: 15, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Company name with sequential reveal - all text displayed
                VStack(spacing: 12) {
                    Text("Cosmos")
                        .font(.custom("Arial", size: 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(cosmosOpacity)
                        .scaleEffect(cosmosScale)
                        .shadow(color: .white.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Text("Solution")
                        .font(.custom("Arial", size: 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(solutionOpacity)
                        .scaleEffect(solutionScale)
                        .shadow(color: .white.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Text("Consultancy")
                        .font(.custom("Arial", size: 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(consultancyOpacity)
                        .scaleEffect(consultancyScale)
                        .shadow(color: .white.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Text("Triology Business Lab")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .opacity(triologyOpacity)
                        .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                
                Spacer()
                
                // Professional loading indicator
                if showProgress {
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.3)
                        
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .opacity(showProgress ? 1.0 : 0.0)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // Quick logo entrance
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            // Fast sequential text reveal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    cosmosOpacity = 1.0
                    cosmosScale = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    solutionOpacity = 1.0
                    solutionScale = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    consultancyOpacity = 1.0
                    consultancyScale = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    triologyOpacity = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showProgress = true
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(ThemeManager())
    }
}

// MARK: - Forgot Password Overlay
struct ForgotPasswordOverlay: View {
    @Binding var isPresented: Bool
    @State var email: String
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var isLoading = false
    @State private var message: String?
    @State private var isSuccess = false
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            // Card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: isSuccess ? "envelope.badge.fill" : "lock.rotation")
                    .font(.system(size: 40))
                    .foregroundColor(isSuccess ? .green : .blue)
                    .padding(.bottom, 10)
                
                Text(isSuccess ? "Check your email" : "Reset Password")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white) // Dark mode: white text
                
                Text(isSuccess ? "We have sent a password reset link to \(email). Please check your inbox and spam folder." : "Enter your email address below to receive a password reset link.")
                    .font(.subheadline)
                    .foregroundColor(.gray) // Dark mode: gray text
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if !isSuccess {
                    TextField("Enter your email", text: $email)
                        .padding()
                        .background(Color(red: 0.2, green: 0.2, blue: 0.25)) // Dark mode input background
                        .cornerRadius(12)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .foregroundColor(.white) // Dark mode input text
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                if let message = message {
                    Text(message)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSuccess ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if isSuccess {
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Text("Back to Login")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    HStack(spacing: 15) {
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.2, green: 0.2, blue: 0.25)) // Dark mode button background
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: resetPassword) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send Link")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.0, green: 0.6, blue: 0.4),
                                    Color(red: 0.0, green: 0.5, blue: 0.3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(email.isEmpty || isLoading)
                        .opacity(email.isEmpty ? 0.6 : 1.0)
                    }
                }
            }
            .padding(30)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12)) // Dark mode card background
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
        }
    }
    
    private func resetPassword() {
        guard !email.isEmpty else { return }
        
        // Basic email validation
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        if !emailPred.evaluate(with: email) {
            message = "Please enter a valid email address"
            return
        }
        
        isLoading = true
        message = nil
        
        // Add a small delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            authService.resetPassword(email: email) { result in
                isLoading = false
                switch result {
                case .success:
                    withAnimation {
                        isSuccess = true
                        message = "Reset link sent successfully!"
                    }
                case .failure(let error):
                    withAnimation {
                        message = error.localizedDescription
                        isSuccess = false
                    }
                }
            }
        }
    }
}
