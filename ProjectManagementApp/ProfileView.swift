import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var taskProgress: Double = 0.0
    @State private var completedCount: Int = 0
    @State private var inProgressCount: Int = 0
    @State private var pendingCount: Int = 0
    @State private var showReports = false
    @State private var showDocuments = false
    @State private var showExpenses = false
    @State private var showThemeSettings = false
    @State private var showAccountDetails = false
    @State private var showTeamExpenses = false
    
    var availablePanels: [UserRole] = []
    var currentPanel: UserRole? = nil
    var onSwitchPanel: ((UserRole) -> Void)? = nil
    
    @State private var isPanelSwitcherExpanded = false
    
    private var totalTasks: Int {
        completedCount + inProgressCount + pendingCount
    }

struct AccountDetailsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var isLoading = true
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var resource: String = ""
    @State private var userId: String = ""
    @State private var accountCreated: Date? = nil
    @State private var lastSignIn: Date? = nil
    @State private var isEditing = false
    @State private var draftName: String = ""
    @State private var draftEmail: String = ""
    @State private var draftPhone: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var profileImage: String? = nil
    private let defaultCountryCode = "+91"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        loadingView
                    } else {
                        accountHeaderCard
                        accountDetailsCard
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
            }
            .navigationTitle("Account Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            Button(action: saveEdits) {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Save")
                                }
                            }
                            .disabled(isSaving)
                        }
                    }
                }
            }
        }
        .onAppear { loadAccount() }
    }

    private var loadingView: some View {
        HStack { Spacer(); ProgressView(); Spacer() }
    }

    private var accountHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [themeManager.accentColor.opacity(0.25), themeManager.accentColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                    
                    if let profileImage = profileImage, let url = URL(string: profileImage) {
                         AsyncImage(url: url) { phase in
                             switch phase {
                             case .empty:
                                 ProgressView()
                             case .success(let image):
                                 image.resizable()
                                      .aspectRatio(contentMode: .fill)
                                      .frame(width: 64, height: 64)
                                      .clipShape(Circle())
                             case .failure:
                                 Image(systemName: "person.fill")
                                     .foregroundColor(themeManager.accentColor)
                                     .font(.system(size: 28, weight: .semibold))
                             @unknown default:
                                 EmptyView()
                             }
                         }
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(themeManager.accentColor)
                            .font(.system(size: 28, weight: .semibold))
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(name.isEmpty ? "-" : name)
                        .font(.headline)
                    Text(email.isEmpty ? "-" : email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(resource.isEmpty ? "-" : resource)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.accentColor.opacity(0.12))
                        .foregroundColor(themeManager.accentColor)
                        .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.15)))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .overlay(alignment: .topTrailing) {
            if !isLoading && !isEditing {
                Button(action: beginEditing) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                        Text("Edit Profile")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.accentColor.opacity(0.15))
                    .foregroundColor(themeManager.accentColor)
                    .clipShape(Capsule())
                }
                .padding(8)
            }
        }
    }

    private var accountDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Details")
                .font(.headline)
                .fontWeight(.semibold)
            VStack(spacing: 14) {
                ProfileEditableFieldRow(
                    title: "Display Name",
                    systemImageName: "person.fill",
                    value: name,
                    isEditing: isEditing,
                    text: $draftName
                )

                ProfileStaticFieldRow(
                    title: "Email Address",
                    systemImageName: "envelope.fill",
                    value: email
                )

                ProfilePhoneFieldRow(
                    title: "Phone Number",
                    systemImageName: "phone.fill",
                    value: phone,
                    isEditing: isEditing,
                    text: $draftPhone,
                    countryCode: defaultCountryCode
                )

                ProfileStaticFieldRow(
                    title: "Role",
                    systemImageName: "person.text.rectangle",
                    value: resource
                )

                ProfileStaticFieldRow(
                    title: "Account Created",
                    systemImageName: "calendar.badge.plus",
                    value: formatDate(accountCreated)
                )

                ProfileStaticFieldRow(
                    title: "Last Sign In",
                    systemImageName: "clock.fill",
                    value: formatDate(lastSignIn)
                )

                if let error = saveError {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.15)))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func beginEditing() {
        draftName = name
        draftEmail = email
        let rawPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawPhone.hasPrefix(defaultCountryCode) {
            draftPhone = String(rawPhone.dropFirst(defaultCountryCode.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            draftPhone = rawPhone
        }
        saveError = nil
        isEditing = true
    }

    private func cancelEditing() {
        draftName = name
        draftEmail = email
        draftPhone = phone
        saveError = nil
        isEditing = false
    }

    private func saveEdits() {
        isSaving = true
        saveError = nil

        let trimmedPhone = draftPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedPhone: String
        if trimmedPhone.isEmpty {
            formattedPhone = ""
        } else if trimmedPhone.hasPrefix(defaultCountryCode) {
            formattedPhone = trimmedPhone
        } else {
            formattedPhone = defaultCountryCode + trimmedPhone
        }

        authService.updateProfile(name: draftName, email: nil, phone: formattedPhone.isEmpty ? nil : formattedPhone) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success:
                    self.name = self.draftName
                    self.phone = formattedPhone
                    self.isEditing = false
                case .failure(let error):
                    self.saveError = error.localizedDescription
                }
            }
        }
    }

    private func loadAccount() {
        let db = Firestore.firestore()
        let uid = authService.currentUid
        let userEmail = authService.currentUser?.email
        func parse(_ data: [String: Any]) {
            let resolvedName = (
                data["clientName"] as? String ??
                data["cLientName"] as? String ??
                data["ClientName"] as? String ??
                data["companyName"] as? String ??
                data["name"] as? String ??
                data["displayName"] as? String ??
                userEmail ?? ""
            )
            let resolvedEmail = (data["email"] as? String) ?? (userEmail ?? "")
            let resolvedPhone = (
                data["contactNo"] as? String ??
                data["contactno"] as? String ??
                data["contact"] as? String ??
                data["phone"] as? String ??
                data["phoneNumber"] as? String ??
                data["mobile"] as? String ??
                data["mobileNumber"] as? String ??
                ""
            )
            let rawRole = (
                data["resourceRoleType"] as? String ??
                data["resource_role_type"] as? String ??
                data["roleType"] as? String ??
                data["role"] as? String ??
                ""
            )
            let resolvedUid = (
                uid ??
                data["uid"] as? String ??
                data["userUid"] as? String ??
                ""
            )
            let createdDateFromDB: Date? = {
                if let ts = data["createdAt"] as? Timestamp {
                    return ts.dateValue()
                }
                if let ts = data["created_at"] as? Timestamp {
                    return ts.dateValue()
                }
                return nil
            }()
            let createdDate = createdDateFromDB ?? authService.accountCreationDate
            let lastSignInDate = authService.lastSignInDate
            let resolvedImage = data["imageUrl"] as? String ?? data["profileImage"] as? String ?? data["photoURL"] as? String
            DispatchQueue.main.async {
                self.name = resolvedName
                self.email = resolvedEmail
                self.phone = resolvedPhone
                self.resource = rawRole
                self.userId = resolvedUid
                self.accountCreated = createdDate
                self.lastSignIn = lastSignInDate
                self.profileImage = resolvedImage
                self.isLoading = false
            }
        }
        func tryClientsByEmail() {
            guard let e = userEmail, !e.isEmpty else { self.isLoading = false; return }
            db.collection("clients").whereField("email", isEqualTo: e).limit(to: 1).getDocuments { snap, _ in
                if let d = snap?.documents.first?.data() { parse(d) } else { DispatchQueue.main.async { self.isLoading = false } }
            }
        }
        func tryClientsByUidOrEmail() {
            if let id = uid, !id.isEmpty {
                db.collection("clients").document(id).getDocument { doc, _ in
                    if let data = doc?.data() { parse(data) } else { tryClientsByEmail() }
                }
            } else {
                tryUsersByEmail()
            }
        }
        func tryUsersByEmail() {
            guard let e = userEmail, !e.isEmpty else { tryClientsByUidOrEmail(); return }
            db.collection("users").whereField("email", isEqualTo: e).limit(to: 1).getDocuments { snap, _ in
                if let d = snap?.documents.first?.data() { parse(d) } else { tryClientsByUidOrEmail() }
            }
        }
        if let id = uid, !id.isEmpty {
            db.collection("users").document(id).getDocument { doc, _ in
                if let data = doc?.data() { parse(data) } else { tryUsersByEmail() }
            }
        } else {
            tryUsersByEmail()
        }
    }
}
    
    private var pendingFraction: Double {
        totalTasks > 0 ? Double(pendingCount) / Double(totalTasks) : 0.0
    }
    
    private var inProgressFraction: Double {
        totalTasks > 0 ? Double(inProgressCount) / Double(totalTasks) : 0.0
    }
    
    private var completedFraction: Double {
        taskProgress
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                taskProgressSection
                accountActionsSection
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle("Profile")
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email)
        }
        .onReceive(firebaseService.$tasks) { newTasks in
            updateFromTasks(newTasks)
        }
        .sheet(isPresented: $showTeamExpenses) {
            ManagerTeamExpensesView()
        }
        .sheet(isPresented: $showReports) {
            if currentPanel == .manager {
                NavigationView {
                    SuperAdminAdminReportsView(
                        userUid: authService.currentUid,
                        userEmail: authService.currentUser?.email,
                        userName: authService.currentUser?.name
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showReports = false
                            }
                        }
                    }
                }
            } else {
                EmployeeReportsView(
                    firebaseService: firebaseService,
                    authService: authService
                )
            }
        }
        .sheet(isPresented: $showDocuments) {
            EmployeeDocumentsView(isManagerPanel: currentPanel == .manager)
        }
        .sheet(isPresented: $showExpenses) {
            ExpensesView()
        }
        .sheet(isPresented: $showThemeSettings) {
            ThemeSettingsView().environmentObject(themeManager)
        }
        .sheet(isPresented: $showAccountDetails) {
            AccountDetailsSheet().environmentObject(themeManager)
        }
    }
    
    private func getProgressColor() -> Color {
        switch taskProgress {
        case 0.0..<0.3: return .red
        case 0.3..<0.7: return .orange
        case 0.7...1.0: return .green
        default: return .blue
        }
    }
    
    private func updateFromTasks(_ tasks: [Task]) {
        let blocked = Set(["m", "mmm", "f", "cccccc", "ccccccc"])
        let filtered = tasks.filter { !blocked.contains($0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        let completed = filtered.filter { $0.status == .completed }.count
        let inProg = filtered.filter { $0.status == .inProgress }.count
        let pending = filtered.filter { $0.status == .notStarted }.count
        let total = completed + inProg + pending
        completedCount = completed
        inProgressCount = inProg
        pendingCount = pending
        withAnimation(.easeInOut(duration: 0.25)) {
            taskProgress = total > 0 ? Double(completed) / Double(total) : 0.0
        }
    }

    private func getPanelName(for role: UserRole) -> String {
        switch role {
        case .superAdmin: return "Super Admin Panel"
        case .admin: return "Admin Panel"
        case .manager: return "Manager Panel"
        case .employee: return "Employee Panel"
        case .client: return "Client Panel"
        }
    }
    
    private func getPanelIcon(for role: UserRole) -> String {
        switch role {
        case .superAdmin: return "shield.fill"
        case .admin: return "person.badge.key.fill"
        case .manager: return "briefcase.fill"
        case .employee: return "person.fill"
        case .client: return "person.crop.circle"
        }
    }
    private var taskProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // Progress Wheel
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 80, height: 80)
                    
                    // Pending segment
                    Circle()
                        .trim(from: 0.0, to: pendingFraction)
                        .stroke(
                            Color.red,
                            style: StrokeStyle(
                                lineWidth: 12,
                                lineCap: .round
                            )
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: -90))
                    
                    // In-Progress segment
                    Circle()
                        .trim(from: pendingFraction, to: min(pendingFraction + inProgressFraction, 1.0))
                        .stroke(
                            Color.orange,
                            style: StrokeStyle(
                                lineWidth: 12,
                                lineCap: .round
                            )
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: -90))
                    
                    // Completed segment
                    Circle()
                        .trim(from: min(pendingFraction + inProgressFraction, 1.0),
                              to: min(pendingFraction + inProgressFraction + completedFraction, 1.0))
                        .stroke(
                            Color.green,
                            style: StrokeStyle(
                                lineWidth: 12,
                                lineCap: .round
                            )
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: -90))
                    
                    VStack(spacing: 2) {
                        Text("\(Int(taskProgress * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(getProgressColor())
                        
                        Text("Done")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ProgressStat(title: "Completed", value: String(completedCount), color: .green, icon: "checkmark.circle.fill")
                    ProgressStat(title: "In Progress", value: String(inProgressCount), color: .orange, icon: "clock.fill")
                    ProgressStat(title: "Pending", value: String(pendingCount), color: .red, icon: "exclamationmark.circle.fill")
                }
                
                Spacer()
            }
            
            // Progress description
            Text("You're doing great! Keep up the good work.")
                .font(.caption)
                .foregroundColor(.gray)
                .italic()
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var accountActionsSection: some View {
        VStack(spacing: 12) {
            Text("Account Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let onSwitchPanel = onSwitchPanel, !availablePanels.isEmpty {
                Button(action: {
                    withAnimation(.spring()) {
                        isPanelSwitcherExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.purple)
                        }

                        Text(currentPanel.flatMap { getPanelName(for: $0) } ?? "Switch Panel")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                                .rotationEffect(.degrees(isPanelSwitcherExpanded ? 180 : 0))
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.15))
                    )
                }
                
                if isPanelSwitcherExpanded {
                    VStack(spacing: 8) {
                        ForEach(availablePanels, id: \.self) { panel in
                            Button(action: {
                                onSwitchPanel(panel)
                                withAnimation {
                                    isPanelSwitcherExpanded = false
                                }
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(currentPanel == panel ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: getPanelIcon(for: panel))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(currentPanel == panel ? .purple : .gray)
                                    }
                                    
                                    Text(getPanelName(for: panel))
                                        .font(.subheadline)
                                        .fontWeight(currentPanel == panel ? .semibold : .regular)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if currentPanel == panel {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.05))
                                )
                            }
                        }
                    }
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            if !isPanelSwitcherExpanded {
                Group {
                    Button(action: { showAccountDetails = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.green)
                            }

                            Text("Account")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15))
                        )
                    }
                    
                    Button(action: { showThemeSettings = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.orange)
                            }

                            Text("Themes")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15))
                        )
                    }
                    
                    Button(action: {
                        showReports = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }

                            Text("Reports")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15))
                        )
                    }
                    
                    Button(action: {
                        showDocuments = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.12))
                                .frame(width: 32, height: 32)
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.purple)
                            }

                            Text("Knowledge")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15))
                        )
                    }

                    if currentPanel == .manager {
                        Button(action: {
                            showTeamExpenses = true
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.indigo.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "banknote.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.indigo)
                                }

                                Text("Team Expenses")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.background)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.15))
                            )
                        }
                    }

                    if currentPanel != .manager {
                        Button(action: {
                            showExpenses = true
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.orange)
                                }

                                Text("Expenses")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.background)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.15))
                            )
                        }
                    }
                }
                .transition(.opacity)
            }
            
            Button(action: {
                // Logout action
                appState.logout()
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                    }

                    Text("Logout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.15))
                )
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

struct ProgressStat: View {
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

struct LeaveHistoryRow: View {
    let date: String
    let type: String
    let status: String
    
    var statusColor: Color {
        switch status {
        case "Approved": return .green
        case "Pending": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
        }
    }
}

struct ProfileEditableFieldRow: View {
    let title: String
    let systemImageName: String
    let value: String
    let isEditing: Bool
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: systemImageName)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                if isEditing {
                    TextField(title, text: $text)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                } else {
                    Text(value.isEmpty ? "-" : value)
                        .foregroundColor(.primary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

struct ProfileStaticFieldRow: View {
    let title: String
    let systemImageName: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: systemImageName)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Text(value.isEmpty ? "-" : value)
                    .foregroundColor(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

struct ProfilePhoneFieldRow: View {
    let title: String
    let systemImageName: String
    let value: String
    let isEditing: Bool
    @Binding var text: String
    let countryCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: systemImageName)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                if isEditing {
                    HStack(spacing: 8) {
                        Text(countryCode)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1, height: 22)

                        TextField("Phone Number", text: $text)
                            .keyboardType(.phonePad)
                    }
                } else {
                    Text(value.isEmpty ? "-" : value)
                        .foregroundColor(.primary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6))
            )
        }
    }
}
