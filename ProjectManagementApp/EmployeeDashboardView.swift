import SwiftUI
import Foundation

struct EmployeeDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showDailyReportForm = false
    @StateObject private var notificationManager = NotificationManager()
    @State private var showNotifications = false
    @State private var showReminders = false
    @State private var showNotes = false
    @State private var showReminderNotesHub = false
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var activeReminder: SavedReminder? = nil
    @State private var showReminderAlert = false
    @State private var reminderTimer: Timer? = nil
    @State private var dueReminderCount: Int = 0
    var availablePanels: [UserRole] = []
    var currentPanel: UserRole? = nil
    var onSwitchPanel: ((UserRole) -> Void)? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main Content
                TabView(selection: $selectedTab) {
                    DashboardHomeView(showDailyReportForm: $showDailyReportForm, onSelectProject: { projectId in
                        // Post a notification that ProjectsView can observe to show issues for project
                        NotificationCenter.default.post(name: Notification.Name("ShowIssuesForProject"), object: projectId)
                        selectedTab = 1
                    }, onSeeAllTasks: {
                        selectedTab = 2
                    })
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Dashboard")
                    }
                    .tag(0)
                    
                    ProjectsView()
                        .tabItem {
                            Image(systemName: "folder.fill")
                            Text("Project Tasks")
                        }
                        .tag(1)
                    
                    TasksView()
                        .tabItem {
                            Image(systemName: "checklist")
                            Text("Tasks")
                        }
                        .tag(2)
                    
                    TasksAndMeetingsCalendarView()
                        .tabItem {
                            Image(systemName: "calendar")
                            Text("Calendar")
                        }
                        .tag(4)
                    
                    ProfileView(availablePanels: availablePanels, currentPanel: currentPanel, onSwitchPanel: onSwitchPanel)
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Profile")
                        }
                        .tag(3)
                }
                .tint(themeManager.accentColor)

                // In-app reminder banner near the top-right reminder icon
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
                                // Circular container (matches PinnedNoteButton style)
                                Circle()
                                    .fill(.background)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                lineWidth: 1
                                            )
                                    )

                                // Sticky note card
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.yellow.opacity(0.9))
                                    .frame(width: 18, height: 14)
                                    .offset(y: 3)

                                // Pin overlay
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
                            .accessibilityLabel("Open Reminders & Notes")
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
            .sheet(isPresented: $showNotes) {
                NotesFormView()
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
        .preferredColorScheme(themeManager.colorScheme)
        .tint(themeManager.accentColor)
    }
    
    private func getNavigationTitle() -> String {
        switch selectedTab {
        case 0: return "Dashboard"
        case 1: return "Project"
        case 2: return "Tasks"
        case 3: return "Profile"
        case 4: return "Calendar"
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
}

struct ReminderBannerView: View {
    let reminder: SavedReminder
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Reminder")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(reminder.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

struct SavedReminder: Identifiable {
    let id: String
    let title: String
    let date: Date
    let priority: String

    init(id: String = UUID().uuidString, title: String, date: Date, priority: String) {
        self.id = id
        self.title = title
        self.date = date
        self.priority = priority
    }
}

struct SavedNote: Identifiable {
    let id: String
    let title: String
    let category: String
    let isPinned: Bool

    init(id: String = UUID().uuidString, title: String, category: String, isPinned: Bool) {
        self.id = id
        self.title = title
        self.category = category
        self.isPinned = isPinned
    }
}

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

fileprivate struct ReminderSeenState {
    private static let storageKey = "seenReminderIds"

    static func isSeen(id: String) -> Bool {
        let stored = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return stored.contains(id)
    }

    static func markSeen(id: String) {
        var stored = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        if !stored.contains(id) {
            stored.append(id)
            UserDefaults.standard.set(stored, forKey: storageKey)
        }
    }
}

// MARK: - Reminder Form
struct RemindersFormView: View {
    var onSave: ((SavedReminder) -> Void)? = nil
    var existingReminder: SavedReminder? = nil
    var documentId: String? = nil
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var date: Date = Date().addingTimeInterval(60 * 10)
    @State private var priority: String = "Medium"
    @State private var repeats: String = "None"
    @State private var notifyEnabled: Bool = true
    @State private var notifyMinutesBefore: Int = 10
    private let priorities = ["Low", "Medium", "High"]
    private let repeatOptions = ["None", "Daily", "Weekly", "Monthly"]
    private let leadTimes = [5, 10, 15, 30, 60]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminder")) {
                    TextField("Title (required)", text: $title)
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                }

                Section(header: Text("Schedule")) {
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle(existingReminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveReminder() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let existing = existingReminder {
                self.title = existing.title
                self.date = existing.date
                self.priority = existing.priority
            }
        }
    }

    private func saveReminder() {
        // Placeholder persistence: print to console; integrate with your storage later
        print("✅ Saved reminder: title=\(title), date=\(date), priority=\(priority), repeat=\(repeats), notify=\(notifyEnabled ? "\(notifyMinutesBefore)" : "off")")
        let item = SavedReminder(title: title, date: date, priority: priority)
        onSave?(item)

        let uid = authService.currentUid
        let email = authService.currentUser?.email
        if let docId = documentId {
            firebaseService.updateReminder(
                documentId: docId,
                title: title,
                details: details,
                date: date,
                priority: priority,
                repeats: repeats,
                notifyEnabled: notifyEnabled,
                notifyMinutesBefore: notifyMinutesBefore
            ) { error in
                if let error = error {
                    print("❌ Failed to update reminder in Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Reminder updated in Firestore")
                }
            }
        } else {
            firebaseService.saveReminder(
                userUid: uid,
                userEmail: email,
                title: title,
                details: details,
                date: date,
                priority: priority,
                repeats: repeats,
                notifyEnabled: notifyEnabled,
                notifyMinutesBefore: notifyMinutesBefore
            ) { error in
                if let error = error {
                    print("❌ Failed to save reminder to Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Reminder saved to Firestore /reminders collection")
                }
            }
        }

        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Notes Form
struct NotesFormView: View {
    var onSave: ((SavedNote) -> Void)? = nil
    var existingNote: SavedNote? = nil
    var documentId: String? = nil
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var category: String = "General"
    @State private var isPinned: Bool = false
    @State private var color: String = "Yellow"
    private let categories = ["General", "Task", "Meeting", "Idea"]
    private let colors = ["Yellow", "Blue", "Green", "Purple", "Gray"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Note")) {
                    TextField("Title (required)", text: $title)
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 120)
                }

                Section(header: Text("Metadata")) {
                    Toggle("Pin to top", isOn: $isPinned)
                }
            }
            .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveNote() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let existing = existingNote {
                self.title = existing.title
                self.category = existing.category
                self.isPinned = existing.isPinned
            }
        }
    }

    private func saveNote() {
        print("✅ Saved note: title=\(title), category=\(category), color=\(color), pinned=\(isPinned)")
        let item = SavedNote(title: title, category: category, isPinned: isPinned)
        onSave?(item)
        let uid = authService.currentUid
        let email = authService.currentUser?.email
        if let docId = documentId {
            firebaseService.updateNote(
                documentId: docId,
                title: title,
                bodyText: bodyText,
                category: category,
                isPinned: isPinned,
                color: color
            ) { error in
                if let error = error {
                    print("❌ Failed to update note in Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Note updated in Firestore")
                }
            }
        } else {
            firebaseService.saveNote(
                userUid: uid,
                userEmail: email,
                title: title,
                bodyText: bodyText,
                category: category,
                isPinned: isPinned,
                color: color
            ) { error in
                if let error = error {
                    print("❌ Failed to save note to Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Note saved to Firestore /notes collection")
                }
            }
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct NotesQuickView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("Notes")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text("Create and manage quick notes here.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - Hub Page for Reminders & Notes
struct ReminderNotesHubView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var showRemindersForm = false
    @State private var showNotesForm = false
    @State private var editingReminderItem: SavedReminder? = nil
    @State private var editingNoteItem: SavedNote? = nil
    @State private var reminderToConfirmSeen: SavedReminder? = nil
    @State private var showSeenConfirmAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Button(action: { showRemindersForm = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill").foregroundColor(.orange)
                            Text("Reminders")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                        .padding()
                        .background(.background)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                    }

                    Button(action: { showNotesForm = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "note.text").foregroundColor(.blue)
                            Text("Notes")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                        .padding()
                        .background(.background)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(.horizontal)

                if !firebaseService.reminders.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Saved Reminders")
                            .font(.headline)
                        ForEach(firebaseService.reminders) { reminder in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reminder.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(reminder.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    let isDue = reminder.date <= Date()
                                    let isSeen = ReminderSeenState.isSeen(id: reminder.id)
                                    if isDue {
                                        HStack(spacing: 6) {
                                            Text(isSeen ? "Seen" : "Due")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(isSeen ? .green : .red)
                                                .onTapGesture {
                                                    if !isSeen {
                                                        reminderToConfirmSeen = reminder
                                                        showSeenConfirmAlert = true
                                                    }
                                                }
                                        }
                                    }
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Text(reminder.priority)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(6)
                                    Button(action: {
                                        editingReminderItem = reminder
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    Button(action: {
                                        firebaseService.deleteReminder(documentId: reminder.id) { success in
                                            if success {
                                                print("✅ Reminder deleted from Firestore")
                                            } else {
                                                print("❌ Failed to delete reminder from Firestore")
                                            }
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(10)
                            .background(.background)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                }

                if !firebaseService.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Saved Notes")
                            .font(.headline)
                        ForEach(firebaseService.notes) { note in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: note.isPinned ? "pin.fill" : "note.text")
                                    .foregroundColor(note.isPinned ? .orange : .blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(note.category)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Button(action: {
                                        editingNoteItem = note
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    Button(action: {
                                        firebaseService.deleteNote(documentId: note.id) { success in
                                            if success {
                                                print("✅ Note deleted from Firestore")
                                            } else {
                                                print("❌ Failed to delete note from Firestore")
                                            }
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(10)
                            .background(.background)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.05).ignoresSafeArea())
            .navigationTitle("Reminders & Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $showRemindersForm) {
                RemindersFormView()
            }
            .sheet(isPresented: $showNotesForm) {
                NotesFormView()
            }
            .sheet(item: $editingReminderItem) { reminder in
                RemindersFormView(existingReminder: reminder, documentId: reminder.id)
            }
            .sheet(item: $editingNoteItem) { note in
                NotesFormView(existingNote: note, documentId: note.id)
            }
            .onAppear {
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                firebaseService.listenReminders(forUserUid: uid, userEmail: email)
                firebaseService.listenNotes(forUserUid: uid, userEmail: email)
            }
            .alert(isPresented: $showSeenConfirmAlert) {
                Alert(
                    title: Text("Reminder"),
                    message: Text("Did you see this reminder?"),
                    primaryButton: .default(Text("Yes")) {
                        if let reminder = reminderToConfirmSeen {
                            ReminderSeenState.markSeen(id: reminder.id)
                        }
                        reminderToConfirmSeen = nil
                    },
                    secondaryButton: .cancel(Text("No")) {
                        reminderToConfirmSeen = nil
                    }
                )
            }
        }
    }
}

struct DashboardHomeView: View {
    @Binding var showDailyReportForm: Bool
    var onSelectProject: ((UUID) -> Void)? = nil
    var onSeeAllTasks: (() -> Void)? = nil
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var assignedTasks: [Task] = []
    
    // All projects data - same as in ProjectsView
    let allProjects = [
        Project(name: "Mobile App Development", description: "Build iOS application with SwiftUI", progress: 0.7, startDate: Date(), endDate: Date().addingTimeInterval(86400 * 30), tasks: [], assignedEmployees: ["John Doe", "Jane Smith"], department: Department.sampleDepartments.first { $0.name == "Software Development" }),
        Project(name: "Website Redesign", description: "Redesign company website", progress: 0.4, startDate: Date(), endDate: Date().addingTimeInterval(86400 * 45), tasks: [], assignedEmployees: ["John Doe"], department: Department.sampleDepartments.first { $0.name == "UI/UX Design" }),
        Project(name: "ERP System", description: "Enterprise Resource Planning", progress: 0.9, startDate: Date(), endDate: Date().addingTimeInterval(86400 * 10), tasks: [], assignedEmployees: ["John Doe"], department: Department.sampleDepartments.first { $0.name == "Software Development" }),
        Project(name: "AI Integration", description: "Implement AI features", progress: 0.2, startDate: Date(), endDate: Date().addingTimeInterval(86400 * 60), tasks: [], assignedEmployees: ["John Doe"], department: Department.sampleDepartments.first { $0.name == "Data Analytics" }),
        Project(name: "FoodDeliveryApp", description: "Food delivery application development", progress: 0.6, startDate: Date(), endDate: Date().addingTimeInterval(86400 * 40), tasks: [], assignedEmployees: ["John Doe"], department: Department.sampleDepartments.first { $0.name == "Software Development" }),
        Project(name: "Vidhunsukha2024", description: "Vidhansabha project implementation", progress: 0.8, startDate: Date(), endDate: Date().addingTimeInterval(86400 * 25), tasks: [], assignedEmployees: ["John Doe"], department: Department.sampleDepartments.first { $0.name == "Software Development" }),
        Project(name: "Security Tools", description: "Security tools development", progress: 0.3, startDate: Date(), endDate: Date().addingTimeInterval(86400 * 50), tasks: [], assignedEmployees: ["John Doe"], department: Department.sampleDepartments.first { $0.name == "Cybersecurity" })
    ]
    
    // Live tasks assigned to the logged-in employee will populate these stats
    
    // Computed properties for task counts
    var completedTasksCount: Int {
        assignedTasks.filter { $0.status == .completed }.count
    }
    
    var pendingTasksCount: Int {
        assignedTasks.filter { $0.status != .completed }.count
    }
    
    var inProgressTasksCount: Int {
        assignedTasks.filter { $0.status == .inProgress }.count
    }
    
    var notStartedTasksCount: Int {
        assignedTasks.filter { $0.status == .notStarted }.count
    }
    
    // Computed property for upcoming tasks (overdue tasks - not completed and past due date)
    var upcomingTasks: [Task] {
        let overdue = assignedTasks
            .filter { $0.status != .completed && Calendar.current.compare($0.dueDate, to: Date(), toGranularity: .day) == .orderedAscending }
            .sorted { $0.dueDate < $1.dueDate }
        let dueSoon = assignedTasks
            .filter { $0.status != .completed && Calendar.current.compare($0.dueDate, to: Date(), toGranularity: .day) != .orderedAscending }
            .sorted { $0.dueDate < $1.dueDate }
        return overdue + dueSoon
    }
    
    // Tasks due today only
    var dueTodayTasksCount: Int {
        let blocked = Set(["M", "Mmm", "F"])
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return assignedTasks.filter { task in
            guard task.status != .completed else { return false }
            guard !blocked.contains(task.title) else { return false }

            if task.isRecurring {
                let start = calendar.startOfDay(for: task.dueDate)
                if let end = task.recurringEndDate {
                    let endDay = calendar.startOfDay(for: end)
                    return today >= start && today <= endDay
                } else {
                    return calendar.isDateInToday(task.dueDate)
                }
            } else {
                return calendar.isDateInToday(task.dueDate)
            }
        }.count
    }
    
    // Recently assigned tasks (completed only, most recent first)
    var recentTasks: [Task] {
        assignedTasks
            .filter { $0.status == .completed }
            .sorted { $0.startDate > $1.startDate }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Welcome Card
                WelcomeCard()
                
                // Stats Overview
                StatsOverview(
                    showDailyReportForm: $showDailyReportForm,
                    tasksCount: dueTodayTasksCount,
                    completedTasksCount: completedTasksCount,
                    pendingTasksCount: pendingTasksCount,
                    onOpenTasks: { onSeeAllTasks?() }
                )
                
                // Upcoming Tasks (overdue first, then due soon)
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Upcoming Tasks")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("See All") { onSeeAllTasks?() }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    if upcomingTasks.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No upcoming tasks")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(upcomingTasks.prefix(4)) { task in
                            ZStack(alignment: .topTrailing) {
                                DashboardTaskRow(task: task)
                                if Calendar.current.compare(task.dueDate, to: Date(), toGranularity: .day) == .orderedAscending && task.status != .completed {
                                    Text("Overdue")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    // Show overdue task count
                    HStack {
                        Text("Total Overdue:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill((assignedTasks.filter { $0.status != .completed && Calendar.current.compare($0.dueDate, to: Date(), toGranularity: .day) == .orderedAscending }.isEmpty) ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            Text("\(assignedTasks.filter { $0.status != .completed && Calendar.current.compare($0.dueDate, to: Date(), toGranularity: .day) == .orderedAscending }.count)")
                                .font(.caption2)
                                .foregroundColor((assignedTasks.filter { $0.status != .completed && Calendar.current.compare($0.dueDate, to: Date(), toGranularity: .day) == .orderedAscending }.isEmpty) ? .green : .red)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(.background)
                .cornerRadius(15)
                .shadow(color: .gray.opacity(0.2), radius: 5)

                // Recent Tasks (most recently assigned)
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Recent Tasks")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("See All") { onSeeAllTasks?() }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    if recentTasks.isEmpty {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.gray)
                            Text("No recent tasks")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(recentTasks.prefix(4)) { task in
                            DashboardTaskRow(task: task)
                        }
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
        // Removed NavigationLink push; using tab switch via onSeeAllTasks instead
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email)
            firebaseService.deleteTasksByTitles(["M", "Mmm", "F", "Cccccc", "Ccccccc"], forUserUid: uid, userEmail: email, completion: nil)
        }
        .onReceive(firebaseService.$tasks) { newTasks in
            let blocked = Set(["m", "mmm", "f", "cccccc", "ccccccc"])
            self.assignedTasks = newTasks.filter { !blocked.contains($0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        }
    }
}

extension DashboardHomeView {
    private func fetchAssignedTasks() {
        let uid = authService.currentUid
        let email = authService.currentUser?.email
        firebaseService.fetchTasksAssigned(toUserUid: uid, userEmail: email) { tasks in
            DispatchQueue.main.async {
                let blocked = Set(["m", "mmm", "f", "cccccc", "ccccccc"])
                self.assignedTasks = tasks.filter { !blocked.contains($0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
            }
        }
    }
}

// MARK: - Welcome Card
struct WelcomeCard: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var employeeProfile: EmployeeProfile?
    @State private var isLoading = true
    
    private var roleText: String? {
        let role = employeeProfile?.position?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = role, !r.isEmpty, r.lowercased() != "employee" { return r }
        return nil
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cosmos Triology Solution")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                Text("Welcome back,")
                    .font(.title2)
                    .foregroundColor(.gray)

                if isLoading {
                    Text("Loading...")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundColor(.blue)
                } else {
                    Text(employeeProfile?.name ?? "Employee")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundColor(.blue)
                }

                Text("Today: \(Date().formatted(date: .complete, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let resourceRole = roleText {
                    Text(resourceRole)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Spacer()

            // Profile Image
            if let imageURL = employeeProfile?.profileImageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(minHeight: 180)
        .background(.background)
        .cornerRadius(20)
        .shadow(color: .gray.opacity(0.25), radius: 8, x: 0, y: 3)
        .onAppear {
            fetchEmployeeProfile()
        }
    }
    
    private func fetchEmployeeProfile() {
        // Get the actual logged-in user's ID from Firebase Auth
        guard let currentUser = authService.currentUser else {
            print("❌ No authenticated user found")
            isLoading = false
            // Set fallback profile
            employeeProfile = EmployeeProfile(
                id: "unknown",
                name: "Guest User",
                email: "guest@trilogy.com",
                profileImageURL: nil,
                department: "Unknown",
                position: "Guest"
            )
            return
        }
        
        // Use the actual user's email as the document ID in the users collection
        let userEmail = currentUser.email
        print("🔍 Fetching profile for logged-in user: \\(userEmail)")
        
        // Fetch from users collection using email as document ID
        firebaseService.fetchEmployeeProfile(userId: userEmail) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let profile):
                    employeeProfile = profile
                    print("✅ Successfully loaded profile for: \\(profile.name)")
                case .failure(let error):
                    print("Failed to fetch user profile: \\(error.localizedDescription)")
                    // Use the authenticated user's data as fallback
                    employeeProfile = EmployeeProfile(
                        id: userEmail,
                        name: currentUser.name,
                        email: userEmail,
                        profileImageURL: currentUser.profileImage,
                        department: "Software Development",
                        position: "Employee"
                    )
                }
            }
        }
    }
}

// MARK: - Stats Overview
struct StatsOverview: View {
    @Binding var showDailyReportForm: Bool
    let tasksCount: Int
    let completedTasksCount: Int
    let pendingTasksCount: Int
    var onOpenTasks: (() -> Void)? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button(action: {
                    NotificationCenter.default.post(name: Notification.Name("TasksFilter"), object: nil, userInfo: ["dueToday": true, "status": "pending"])
                    onOpenTasks?()
                }) {
                    StatCard(title: "Today's Tasks", value: "\(tasksCount)", color: .green, icon: "checklist")
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: {
                    NotificationCenter.default.post(name: Notification.Name("TasksFilter"), object: nil, userInfo: ["status": "pending"])
                    onOpenTasks?()
                }) {
                    StatCard(title: "Pending", value: "\(pendingTasksCount)", color: .orange, icon: "clock.fill")
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: {
                    NotificationCenter.default.post(name: Notification.Name("TasksFilter"), object: nil, userInfo: ["status": "completed"])
                    onOpenTasks?()
                }) {
                    StatCard(title: "Completed", value: "\(completedTasksCount)", color: .red, icon: "checkmark.circle.fill")
                }
                .buttonStyle(PlainButtonStyle())
                
                // AI Daily Report Card
                Button(action: {
                    showDailyReportForm = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                        
                        Text("AI")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        
                        Text("Report")
                            .font(.system(size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.2), radius: 3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12))
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.background)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 3)
    }
}

// MARK: - Dashboard Task Row
struct DashboardTaskRow: View {
    let task: Task
    
    var priorityDisplay: String {
        switch task.priority {
        case .p1: return "High"
        case .p2: return "Medium"
        case .p3: return "Low"
        }
    }
    
    var statusColor: Color {
        switch task.status {
        case .completed: return .green
        case .inProgress: return .orange
        case .notStarted: return .red
        case .stuck: return .orange
        case .waitingFor: return .purple
        case .onHoldByClient: return .orange
        case .needHelp: return .red
        case .canceled: return .gray
        }
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .p1: return .red
        case .p2: return .yellow
        case .p3: return .blue
        }
    }
    
    var isOverdue: Bool {
        let comparison = Calendar.current.compare(task.dueDate, to: Date(), toGranularity: .day)
        return comparison == .orderedAscending && task.status != .completed
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(task.status.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // Priority indicator with same styling as TasksView
                    Text(priorityDisplay)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.2))
                        .foregroundColor(priorityColor)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if isOverdue {
                    Text("Overdue")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                } else {
                    Text(task.dueDate, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    Text("Due")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Pinned Note Button & Reminders Sheet
struct PinnedNoteButton: View {
    @Binding var isPresented: Bool
    var body: some View {
        Button(action: { isPresented = true }) {
            ZStack {
                // Circular container
                Circle()
                    .fill(.background)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )

                // Sticky note card
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.yellow.opacity(0.9))
                    .frame(width: 18, height: 14)
                    .offset(y: 3)

                // Pin overlay
                Image(systemName: "pin.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .offset(x: 8, y: -8)
            }
            .accessibilityLabel("Reminders")
            .accessibilityHint("Open reminders")
        }
    }
}

struct RemindersQuickView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("No Reminders")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text("Tap + in future updates to add a reminder.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
