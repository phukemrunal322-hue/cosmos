import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct ClientDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showSideMenu = false
    @State private var showCompletedProjects = false
    
    var body: some View {
        ZStack {
            // Main Content
            TabView(selection: $selectedTab) {
                ClientDashboardHomeView(selectedTab: $selectedTab, showCompletedProjects: $showCompletedProjects)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Dashboard")
                    }
                    .tag(0)
                
                ClientProjectsView(showCompletedOnly: $showCompletedProjects)
                    .tabItem {
                        Image(systemName: "folder.fill")
                        Text("Projects")
                    }
                    .tag(1)
                
                ClientTasksView()
                    .tabItem {
                        Image(systemName: "checklist")
                        Text("Tasks")
                    }
                    .tag(2)
                
                ClientTasksAndMeetingsCalendarView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(4)
                
                ClientProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .tag(3)
            }
            .tint(themeManager.accentColor)
            
            // Side Menu
            if showSideMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showSideMenu = false
                        }
                    }
                
                HStack {
                    ClientSideMenuView(
                        selectedTab: $selectedTab,
                        showMenu: $showSideMenu,
                        onLogout: {
                            appState.logout()
                            // Reset to main screen
                            if let window = UIApplication.shared.windows.first {
                                let root = ContentView().environmentObject(ThemeManager())
                                window.rootViewController = UIHostingController(rootView: root)
                                window.makeKeyAndVisible()
                            }
                        }
                    )
                    .frame(width: 280)
                    .offset(x: showSideMenu ? 0 : -280)
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            withAnimation {
                showSideMenu.toggle()
            }
        }) {
            Image(systemName: "line.horizontal.3")
                .font(.title2)
                .foregroundColor(themeManager.accentColor)
        })
        .navigationTitle(getNavigationTitle())
        .preferredColorScheme(themeManager.colorScheme)
        .tint(themeManager.accentColor)
        
    }
    
    private func getNavigationTitle() -> String {
        switch selectedTab {
        case 0: return "Dashboard"
        case 1: return "Projects"
        case 2: return "Tasks"
        case 3: return "Profile"
        case 4: return "Calendar"
        default: return "Dashboard"
        }
    }
}

struct ClientDashboardHomeView: View {
    @Binding var selectedTab: Int
    @Binding var showCompletedProjects: Bool
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var projectProgress: Double = 0.0
    
    private var completedProjects: Int {
        firebaseService.projects.filter { normalizedProgress($0.progress) >= 1.0 }.count
    }
    private var activeProjects: Int {
        firebaseService.projects.filter { normalizedProgress($0.progress) < 1.0 }.count
    }
    private var onHoldProjects: Int { 0 }
    
    private var totalProjects: Int { firebaseService.projects.count }

    private var clientTasks: [Task] {
        firebaseService.tasks
    }

    private var totalTasks: Int {
        clientTasks.count
    }

    private var overdueTasksCount: Int {
        let now = Date()
        return clientTasks.filter {
            $0.status != .completed &&
            Calendar.current.compare($0.dueDate, to: now, toGranularity: .day) == .orderedAscending
        }.count
    }
    
    private var calculatedProgress: Double {
        let progresses = firebaseService.projects.map { normalizedProgress($0.progress) }
        guard !progresses.isEmpty else { return 0.0 }
        let sum = progresses.reduce(0.0, +)
        return sum / Double(progresses.count)
    }
    
    private var projects: [Project] {
        Array(
            firebaseService.projects
                .filter { normalizedProgress($0.progress) < 1.0 }
                .sorted { $0.endDate < $1.endDate }
                .prefix(2)
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Welcome Card
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cosmos Triology Solution")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("Welcome back,")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text(authService.currentUser?.name ?? "Client")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundColor(.green)
                        Text("Client Dashboard")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Group {
                        if let urlString = authService.currentUser?.profileImage, !urlString.isEmpty {
                            if urlString.hasPrefix("data:"), let range = urlString.range(of: "base64,") {
                                let b64 = String(urlString[range.upperBound...])
                                if let data = Data(base64Encoded: b64) {
                                    #if canImport(UIKit)
                                    if let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    #elseif canImport(AppKit)
                                    if let nsImage = NSImage(data: data) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    #else
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                    #endif
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                }
                            } else if let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFill()
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.green.opacity(0.3), lineWidth: 2)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(minHeight: 180)
                .background(.background)
                .cornerRadius(20)
                .shadow(color: .gray.opacity(0.25), radius: 8, x: 0, y: 3)
                
                // Stats Overview
                HStack(spacing: 15) {
                    Button(action: {
                        showCompletedProjects = false
                        selectedTab = 1
                    }) {
                        ClientStatCard(title: "Total Projects", value: "\(totalProjects)", color: .blue, icon: "square.stack.3d.up.fill")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        selectedTab = 2
                    }) {
                        ClientStatCard(title: "Total Tasks", value: "\(totalTasks)", color: .purple, icon: "checklist")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        showCompletedProjects = true
                        selectedTab = 1
                    }) {
                        ClientStatCard(title: "Complete Projects", value: "\(completedProjects)", color: .green, icon: "checkmark.circle.fill")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        selectedTab = 2
                    }) {
                        ClientStatCard(title: "Pending Tasks", value: "\(overdueTasksCount)", color: .orange, icon: "clock.fill")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Project Progress Wheel
                VStack(alignment: .leading, spacing: 16) {
                    Text("Overall Project Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 20) {
                        // Progress Wheel
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0.0, to: projectProgress)
                                .stroke(
                                    getProjectProgressColor(),
                                    style: StrokeStyle(
                                        lineWidth: 12,
                                        lineCap: .round
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(Angle(degrees: -90))
                            
                            VStack(spacing: 2) {
                                Text("\(Int(projectProgress * 100))%")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(getProjectProgressColor())
                                
                                Text("Complete")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            DashboardProgressStat(title: "Completed", value: "\(completedProjects)", color: .green, icon: "checkmark.circle.fill")
                            DashboardProgressStat(title: "Active", value: "\(activeProjects)", color: .blue, icon: "play.circle.fill")
                            DashboardProgressStat(title: "On Hold", value: "\(onHoldProjects)", color: .orange, icon: "pause.circle.fill")
                        }
                        
                        Spacer()
                    }
                    
                    // Progress description
                    Text("Your projects are progressing well. Keep monitoring the milestones.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                }
                .padding()
                .background(.background)
                .cornerRadius(15)
                .shadow(color: .gray.opacity(0.2), radius: 5)
                
                
                // Active Projects
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Active Projects")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("See All") { selectedTab = 1 }
                            .foregroundColor(.green)
                    }
                    
                    ForEach(projects) { project in
                        ClientProjectRow(project: project)
                    }
                }
                .padding()
                .background(.background)
                .cornerRadius(15)
                .shadow(color: .gray.opacity(0.2), radius: 5)
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            // Initialize wheel from any projects already loaded
            projectProgress = calculatedProgress
            // Always (re)start client-specific listeners when dashboard appears
            firebaseService.fetchProjectsForClient(
                userUid: authService.currentUid,
                userEmail: authService.currentUser?.email,
                clientName: authService.currentUser?.name
            )
            firebaseService.fetchTasks(
                forUserUid: authService.currentUid,
                userEmail: authService.currentUser?.email
            )
        }
        .onReceive(firebaseService.$projects) { _ in
            projectProgress = calculatedProgress
        }
        .onReceive(authService.$currentUser) { user in
            // When client info changes, restart listeners so dashboard shows fresh data
            guard let user = user else { return }
            firebaseService.fetchProjectsForClient(
                userUid: authService.currentUid,
                userEmail: user.email,
                clientName: user.name
            )
            firebaseService.fetchTasks(forUserUid: authService.currentUid, userEmail: user.email)
        }
    }
    
    private func normalizedProgress(_ value: Double) -> Double {
        if value > 1 { return min(max(value, 0), 100) / 100.0 }
        return max(0.0, min(1.0, value))
    }

    private func getProjectProgressColor() -> Color {
        switch projectProgress {
        case 0.0..<0.3: return .red
        case 0.3..<0.7: return .orange
        case 0.7...1.0: return .green
        default: return .blue
        }
    }
    
    private func simulateProjectProgressUpdates() {
        // Simulate real-time project progress changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 1.5)) {
                // Random progress update for demonstration
                let randomChange = Double.random(in: -0.05...0.1)
                projectProgress = max(0, min(1, projectProgress + randomChange))
            }
            
            // Continue simulating updates
            simulateProjectProgressUpdates()
        }
    }
}

struct ClientStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(.background)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct DashboardProgressStat: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct ClientProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    let norm = (project.progress > 1) ? min(max(project.progress, 0), 100) / 100.0 : max(0.0, min(1.0, project.progress))
                    ProgressView(value: norm)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .frame(width: 80)
                    
                    Text("\(Int(norm * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(project.endDate, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("Remaining")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}
