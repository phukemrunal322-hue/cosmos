import SwiftUI

struct ManagerDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showDailyReportForm = false
    @StateObject private var notificationManager = NotificationManager()
    @State private var showNotifications = false
    @State private var showReminders = false
    @State private var showReminderNotesHub = false
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    // Panel Switching Props
    var availablePanels: [UserRole] = []
    var currentPanel: UserRole? = nil
    var onSwitchPanel: ((UserRole) -> Void)? = nil
    
    // Reminder state
    @State private var activeReminder: SavedReminder? = nil
    @State private var showReminderAlert = false
    @State private var reminderTimer: Timer? = nil
    @State private var dueReminderCount: Int = 0
    
    // Internal state for when acting as root
    @State private var internalCurrentPanel: UserRole = .manager
    
    var body: some View {
        Group {
            if let onSwitchPanel = onSwitchPanel {
                // Controlled mode (e.g. by SuperAdmin)
                managerView(
                    available: availablePanels,
                    current: currentPanel ?? .manager,
                    switcher: onSwitchPanel
                )
            } else {
                // Root mode (e.g. actual Manager logged in)
                switch internalCurrentPanel {
                case .manager:
                    managerView(
                        available: [.manager, .employee],
                        current: .manager,
                        switcher: { newRole in
                            withAnimation {
                                internalCurrentPanel = newRole
                            }
                        }
                    )
                case .employee:
                    EmployeeDashboardView(
                        availablePanels: [.manager, .employee],
                        currentPanel: .employee,
                        onSwitchPanel: { newRole in
                            withAnimation {
                                internalCurrentPanel = newRole
                            }
                        }
                    )
                default:
                    managerView(
                        available: [.manager, .employee],
                        current: .manager,
                        switcher: { newRole in
                            withAnimation {
                                internalCurrentPanel = newRole
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func managerView(available: [UserRole], current: UserRole, switcher: ((UserRole) -> Void)?) -> some View {
        NavigationView {
            ZStack {
                // Main Content
                TabView(selection: $selectedTab) {
                    ManagerDashboardHomeView(
                        showDailyReportForm: $showDailyReportForm,
                        onSelectProject: { projectId in
                            selectedTab = 1
                        },
                        onSeeAllTasks: {
                            selectedTab = 2
                        }
                    )
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Dashboard")
                    }
                    .tag(0)
                    
                    ManagerProjectsView()
                        .tabItem {
                            Image(systemName: "folder.fill")
                            Text("Projects")
                        }
                        .tag(1)
                    
                    ManagerTasksView()
                        .tabItem {
                            Image(systemName: "checklist")
                            Text("Tasks")
                        }
                        .tag(2)
                    
                    ManagerTasksAndMeetingsCalendarView()
                        .tabItem {
                            Image(systemName: "calendar")
                            Text("Calendar")
                        }
                        .tag(3)
                    
                    ProfileView(
                        availablePanels: available,
                        currentPanel: current,
                        onSwitchPanel: switcher
                    )
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .tag(4)
                }
                .tint(themeManager.accentColor)
                
                // Reminder Banner
                if showReminderAlert, let reminder = activeReminder {
                    VStack {
                        HStack {
                            Spacer()
                            ReminderBannerView(reminder: reminder) {
                                let id = reminder.id
                                ReminderAcknowledgement.markAcknowledged(id: id)
                                activeReminder = nil
                                checkDueReminders()
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showReminderAlert)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle(getNavigationTitle())
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedTab != 0 {
                        Button(action: { selectedTab = 0 }) {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showReminderNotesHub = true }) {
                            ZStack {
                                Circle()
                                    .fill(.background)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                                    .overlay(
                                        Circle()
                                            .stroke(LinearGradient(colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                    )
                                
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.yellow.opacity(0.9))
                                    .frame(width: 18, height: 14)
                                    .offset(y: 3)
                                
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.orange)
                                    .offset(x: 8, y: -8)
                            }
                            .overlay(alignment: .topTrailing) {
                                if dueReminderCount > 0 {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 16, height: 16)
                                        Text("\(min(dueReminderCount, 9))")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                        
                        NotificationBellIcon(
                            notificationManager: notificationManager,
                            showNotifications: $showNotifications
                        )
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView(notificationManager: notificationManager)
            }
            .sheet(isPresented: $showReminders) {
                RemindersFormView()
            }
            .sheet(isPresented: $showReminderNotesHub) {
                ReminderNotesHubView()
            }
            .sheet(isPresented: $showDailyReportForm) {
                DailyReportFormView()
            }
            .onAppear {
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                firebaseService.listenReminders(forUserUid: uid, userEmail: email)
                startReminderTimer()
            }
            .onDisappear {
                reminderTimer?.invalidate()
                reminderTimer = nil
            }
        }
    }
    
    private func getNavigationTitle() -> String {
        switch selectedTab {
        case 0: return "Dashboard"
        case 1: return "Projects"
        case 2: return "Tasks"
        case 3: return "Calendar"
        case 4: return "Profile"
        default: return "Dashboard"
        }
    }
    
    private func startReminderTimer() {
        reminderTimer?.invalidate()
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            checkDueReminders()
        }
        if let timer = reminderTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        checkDueReminders()
    }
    
    private func checkDueReminders() {
        let now = Date()
        let dueReminders = firebaseService.reminders
            .filter { reminder in
                reminder.date <= now && !ReminderAcknowledgement.isAcknowledged(id: reminder.id)
            }
            .sorted { $0.date < $1.date }
        
        dueReminderCount = dueReminders.count
        
        guard let next = dueReminders.first else {
            activeReminder = nil
            showReminderAlert = false
            return
        }
        
        if activeReminder?.id != next.id {
            activeReminder = next
            showReminderAlert = true
        }
        
    }
    
    // Reuse Reminder components if they are not public in EmployeeDashboardView
    // However, since they were file-private or private in EmployeeDashboardView, we might need to duplicate them or check if they are in a shared file.
    // Checking EmployeeDashboardView again...
    // SavedReminder is a struct but not public? It's just 'struct SavedReminder'. It is internal by default.
    // But ReminderAcknowledgement and ReminderSeenState were 'fileprivate'.
    // So I need to duplicate those helpers here or move them to a shared file.
    // Ideally, creating a SharedReminders.swift would be better, but to fix the immediate error without refactoring too much, I will include them here as fileprivate.
    
    fileprivate struct ReminderAcknowledgement {
        private static let storageKey = "acknowledgedReminderIds"
        
        static func isAcknowledged(id: String) -> Bool {
            let stored = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
            return stored.contains(id)
        }
        
        static func markAcknowledged(id: String) {
            var stored = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
            if !stored.contains(id) {
                stored.append(id)
                UserDefaults.standard.set(stored, forKey: storageKey)
            }
        }
    }
}
