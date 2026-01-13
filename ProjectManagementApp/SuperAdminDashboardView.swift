import SwiftUI

struct SuperAdminDashboardView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSideMenu = false
    @State private var selectedMenuItem: MenuItem = .dashboard
    @State private var showLogoutAlert = false
    

    
    // Panel Management
    @State private var currentPanel: PanelType = .superAdmin
    @State private var isPanelDropdownExpanded = false
    
    enum PanelType: String, CaseIterable {
        case superAdmin = "Super Admin Panel"
        case admin = "Admin Panel"
        case manager = "Manager Panel"
        case employee = "Employee Panel"
        
        var icon: String {
            switch self {
            case .superAdmin: return "shield.fill"
            case .admin: return "person.badge.key.fill"
            case .manager: return "briefcase.fill"
            case .employee: return "person.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .superAdmin: return .purple
            case .admin: return .blue
            case .manager: return .green
            case .employee: return .orange
            }
        }
    }
    
    private var availablePanels: [PanelType] {
        guard let role = authService.currentUser?.role else { return [] }
        switch role {
        case .superAdmin:
            return [.superAdmin, .admin, .manager, .employee]
        case .admin:
            return [.admin, .manager, .employee]
        case .manager:
            return [.manager, .employee]
        default:
            return []
        }
    }
    
    enum MenuItem: String, CaseIterable {
        case dashboard = "Dashboard"
        case manageResources = "Manage Resources"
        case manageClients = "Manage Clients"
        case manageProjects = "Manage Projects"
        case taskManagement = "Task Management"
        case knowledgeManagement = "Knowledge Management"
        case expenses = "Expenses"
        case reports = "Reports"
        case minutesOfMeeting = "Minutes of Meeting"
        case calendar = "Calendar"
        case leadManagement = "Lead Management"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .manageResources: return "wrench.and.screwdriver.fill"
            case .manageClients: return "person.2.fill"
            case .manageProjects: return "square.grid.2x2.fill"
            case .taskManagement: return "list.bullet.clipboard.fill"
            case .knowledgeManagement: return "book.fill"
            case .expenses: return "chart.bar.fill"
            case .reports: return "chart.line.uptrend.xyaxis"
            case .minutesOfMeeting: return "doc.text.fill"
            case .calendar: return "calendar"
            case .leadManagement: return "person.3.sequence.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .dashboard: return .orange
            case .manageResources: return .orange
            case .manageClients: return .orange
            case .manageProjects: return .orange
            case .taskManagement: return .orange
            case .knowledgeManagement: return .orange
            case .expenses: return .orange
            case .reports: return .orange
            case .minutesOfMeeting: return .orange
            case .calendar: return .orange
            case .leadManagement: return .orange
            case .settings: return .orange
            }
        }
    }
    
    var body: some View {
        Group {
            switch currentPanel {
            case .superAdmin:
                dashboardLayout
            case .admin:
                AdminDashboardView()
            case .manager:
                ManagerDashboardView(
                    availablePanels: availableUserRoles,
                    currentPanel: mapToUserRole(currentPanel),
                    onSwitchPanel: { role in
                        if let panel = mapToPanelType(role) {
                            currentPanel = panel
                        }
                    }
                )
            case .employee:
                EmployeeDashboardView(
                    availablePanels: availableUserRoles,
                    currentPanel: mapToUserRole(currentPanel),
                    onSwitchPanel: { role in
                        if let panel = mapToPanelType(role) {
                            currentPanel = panel
                        }
                    }
                )
            }
        }
    }
    
    // Helpers for switching panels via ProfileView
    private var availableUserRoles: [UserRole] {
        availablePanels.compactMap { mapToUserRole($0) }
    }
    
    private func mapToUserRole(_ panel: PanelType) -> UserRole? {
        switch panel {
        case .superAdmin: return .superAdmin
        case .admin: return .admin
        case .manager: return .manager
        case .employee: return .employee
        }
    }
    
    private func mapToPanelType(_ role: UserRole) -> PanelType? {
        switch role {
        case .superAdmin: return .superAdmin
        case .admin: return .admin
        case .manager: return .manager
        case .employee: return .employee
        default: return nil
        }
    }

    private var dashboardLayout: some View {
        ZStack {
            // Main Content
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    Button(action: {
                        withAnimation(.spring()) {
                            showSideMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Super Admin")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(authService.currentUser?.name ?? "Administrator")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                        .padding()
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.9, green: 0.2, blue: 0.2),
                            Color(red: 1.0, green: 0.4, blue: 0.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Content Area
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Side Menu Overlay
            if showSideMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            showSideMenu = false
                        }
                    }
                
                HStack {
                    sideMenuView
                        .frame(width: UIScreen.main.bounds.width * 0.83)
                        .background(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 5, y: 0)
                        .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Logout"),
                message: Text("Are you sure you want to logout?"),
                primaryButton: .destructive(Text("Logout")) {
                    logout()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedMenuItem {
        case .dashboard:
            AnalyticsDashboardView()
        case .manageResources:
            ManageResourcesView()
        case .manageClients:
            ManageClientsView()
        case .manageProjects:
            ManageProjectsView()
        case .taskManagement:
            TaskManagementView()
        case .knowledgeManagement:
            KnowledgeManagementView()
        case .expenses:
            BlankExpensesPlaceholderView()
        case .reports:
            SuperAdminAdminReportsView()
        case .minutesOfMeeting:
            MinutesOfMeetingView()
        case .calendar:
            ProjectCalendarView()
        case .leadManagement:
            LeadManagementView()
        case .settings:
            SettingsView()
        }
    }
    
    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Welcome Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome, \(authService.currentUser?.name ?? "Super Admin")!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Super Admin Dashboard")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.1), radius: 5)
                
                // Quick Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    DashboardStatCard(title: "Total Users", value: "\(firebaseService.employees.count)", icon: "person.3.fill", color: .blue)
                    DashboardStatCard(title: "Projects", value: "\(firebaseService.projects.count)", icon: "square.grid.2x2.fill", color: .green)
                    DashboardStatCard(title: "Meetings", value: "\(firebaseService.events.count)", icon: "calendar", color: .purple)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            // Refresh user data (profile image, etc.)
            authService.refreshCurrentUser()
            
            // Fetch all data
            if firebaseService.employees.isEmpty {
                firebaseService.fetchEmployees()
            }
            if firebaseService.projects.isEmpty {
                firebaseService.fetchProjects()
            }
        }
    }
    
    private func placeholderView(for item: MenuItem) -> some View {
        VStack(spacing: 20) {
            Image(systemName: item.icon)
                .font(.system(size: 60))
                .foregroundColor(item.iconColor.opacity(0.5))
            
            Text(item.rawValue)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This feature is coming soon")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
    
    private var sideMenuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Menu Header
            HStack(spacing: 12) {
                // Profile Image with Ring
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 52, height: 52)
                    
                    if let profileURL = authService.currentUser?.profileImage, let url = URL(string: profileURL) {
                        CachedAsyncImage(url: url) {
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .frame(width: 46, height: 46)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 46, height: 46)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                // Text Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("COSMOS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    Text(currentPanel.rawValue)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Close Button
                Button(action: {
                    withAnimation(.spring()) {
                        showSideMenu = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider()

            
            // Panel Switcher Dropdown
            if !availablePanels.isEmpty {
                VStack(spacing: 0) {
                    Text("SWITCH PANEL")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    VStack(spacing: 0) {
                        // Selected Panel (Header of Dropdown)
                        Button(action: {
                            withAnimation(.spring()) {
                                isPanelDropdownExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: currentPanel.icon)
                                    .foregroundColor(currentPanel.color)
                                    .frame(width: 24)
                                
                                Text(currentPanel.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .rotationEffect(.degrees(isPanelDropdownExpanded ? 180 : 0))
                            }
                            .padding()
                            .background(currentPanel.color.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Dropdown Options
                        if isPanelDropdownExpanded {
                            VStack(spacing: 4) {
                                ForEach(availablePanels.filter { $0 != currentPanel }, id: \.self) { panel in
                                    Button(action: {
                                        withAnimation {
                                            currentPanel = panel
                                            isPanelDropdownExpanded = false
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: panel.icon)
                                                .foregroundColor(.gray)
                                                .frame(width: 24)
                                            
                                            Text(panel.rawValue)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                        }
                    }
                }
                .padding(.vertical)
            }
            
            // Menu Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(MenuItem.allCases, id: \.self) { item in
                        Button(action: {
                            selectedMenuItem = item
                            withAnimation(.spring()) {
                                showSideMenu = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.body)
                                    .foregroundColor(selectedMenuItem == item ? themeManager.accentColor : themeManager.accentColor.opacity(0.7))
                                    .frame(width: 24)
                                
                                Text(item.rawValue)
                                    .font(.body)
                                    .foregroundColor(selectedMenuItem == item ? themeManager.accentColor : .primary)
                                    .fontWeight(selectedMenuItem == item ? .bold : .regular)
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                selectedMenuItem == item ?
                                themeManager.accentColor.opacity(0.15) : Color.clear
                            )
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
            
            Spacer()
            
            // Logout Button
            Button(action: {
                showLogoutAlert = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title3)
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Logout")
                        .font(.body)
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 20)
        }
    }
    
    private func logout() {
        authService.logout { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Navigate back to login
                    let rootView = ContentView()
                        .environmentObject(ThemeManager())
                    if let window = UIApplication.shared.windows.first {
                        window.rootViewController = UIHostingController(rootView: rootView)
                        window.makeKeyAndVisible()
                    }
                case .failure(let error):
                    print("Logout error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Dashboard Stat Card Component
struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}
