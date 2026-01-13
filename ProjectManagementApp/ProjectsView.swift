import SwiftUI

struct ProjectsView: View {
    @State private var searchText: String = ""
    @State private var showCompletedProjects = false
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    var filteredProjects: [Project] {
        var projects = firebaseService.projects
        
        // Hide sample/test projects
        projects = projects.filter { !isSampleProject($0) }
        
        // Filter by completion status
        if showCompletedProjects {
            // Show only 100% completed projects
            projects = projects.filter { normalizedProgressPercentage($0.progress) >= 100 }
        } else {
            // Show only incomplete projects (less than 100%)
            projects = projects.filter { normalizedProgressPercentage($0.progress) < 100 }
        }
        
        // Filter by search text
        if searchText.isEmpty {
            return projects
        }
        return projects.filter { project in
            project.name.localizedCaseInsensitiveContains(searchText) ||
            project.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Helper function to normalize progress values
    private func normalizedProgressPercentage(_ progress: Double) -> Int {
        // If progress is > 1, assume it's already in percentage format
        if progress > 1 {
            return Int(progress)
        }
        // Otherwise convert from decimal to percentage
        return Int(progress * 100)
    }

    private func isSampleProject(_ project: Project) -> Bool {
        let trimmedName = project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedName == "testorject" || trimmedName == "hi" || trimmedName == "testproject" || trimmedName == "cosmos" {
            return true
        }
        if trimmedName.contains("test") {
            return true
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Header + Filter in one row
                HStack {
                    Text("Project List")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        withAnimation { showCompletedProjects.toggle() }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showCompletedProjects ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 14))
                                .foregroundColor(showCompletedProjects ? .green : .gray)
                            Text(showCompletedProjects ? "Completed (100%)" : "In Progress")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(showCompletedProjects ? .green : .gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(showCompletedProjects ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 10)

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search projects...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .background(.background)
            .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)

            // Content
            if firebaseService.isLoading && firebaseService.projects.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading projects...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = firebaseService.errorMessage, firebaseService.projects.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        firebaseService.fetchProjects()
                    }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredProjects.isEmpty {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Project List")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        Spacer().frame(height: 12)
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.system(size: 44))
                                .foregroundColor(.gray)
                            Text("No Projects Found")
                                .font(.headline)
                            Text("No projects match the selected filters. Adjust your search or try resetting filters.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .padding(.vertical, 12)
                    }
                    .background(.background)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 2)
                    )
                    .shadow(color: .gray.opacity(0.08), radius: 6, y: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredProjects) { project in
                            ProjectCard(project: project)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .background(Color.gray.opacity(0.05))
            }
        }
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email)
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email)
        }
        .onReceive(authService.$currentUser) { _ in
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email)
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email)
        }
    }
    
}

struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let manager = project.projectManager, !manager.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Project Manager: \(manager)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(10)
            .background(headerColor)
            .cornerRadius(8)
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(normalizedProgressPercentage(project.progress))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(normalizedProgress(project.progress) > 0.7 ? .green : normalizedProgress(project.progress) > 0.3 ? .orange : .red)
                }
                
                ProgressView(value: min(max(normalizedProgress(project.progress), 0), 1)) // Ensure progress is between 0 and 1
                    .progressViewStyle(LinearProgressViewStyle(tint: normalizedProgress(project.progress) > 0.7 ? .green : normalizedProgress(project.progress) > 0.3 ? .orange : .red))
            }
            
            // Action Buttons
            HStack(spacing: 8) {
                NavigationLink(destination: ProjectDetailsView(project: project)) {
                    Text("View Details")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                
                NavigationLink(destination: ProjectTasksView(project: project)) {
                    Text("Related Tasks")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(6)
                }
                
                Spacer()
            }
            
            // Project Details
            HStack {
                Label(
                    "Start: " + project.startDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.caption2)
                .foregroundColor(.gray)
                
                Spacer()
                
                Label(
                    "Due: " + project.endDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar.badge.clock"
                )
                .font(.caption2)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(.background)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(headerColor.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var headerColor: Color {
        let palette: [Color] = [
            Color.blue.opacity(0.16),
            Color.green.opacity(0.16),
            Color.purple.opacity(0.16),
            Color.orange.opacity(0.16),
            Color.pink.opacity(0.16),
            Color.teal.opacity(0.16),
            Color.indigo.opacity(0.16),
            Color.cyan.opacity(0.16)
        ]
        let hash = abs(project.name.hashValue)
        let index = hash % palette.count
        return palette[index]
    }

    // Helper functions to normalize progress values
    private func normalizedProgress(_ progress: Double) -> Double {
        // If progress is > 1, assume it's already in percentage format (e.g., 29, 75)
        // Convert to decimal (0.29, 0.75)
        if progress > 1 {
            return progress / 100.0
        }
        return progress
    }
    
    private func normalizedProgressPercentage(_ progress: Double) -> Int {
        // If progress is > 1, assume it's already in percentage format
        if progress > 1 {
            return Int(progress)
        }
        // Otherwise convert from decimal to percentage
        return Int(progress * 100)
    }
}

// Project Details View
struct ProjectDetailsView: View {
    let project: Project
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Project Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let manager = project.projectManager, !manager.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Project Manager: \(manager)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(.background)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.7), lineWidth: 2)
                )
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Progress Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("Completion")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(normalizedProgressPercentage(project.progress))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: normalizedProgress(project.progress))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
                .padding()
                .background(.background)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.7), lineWidth: 2)
                )
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Timeline Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Start Date", systemImage: "calendar.badge.plus")
                                .font(.subheadline)
                            Text(project.startDate.formatted(date: .complete, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Label("Due Date", systemImage: "calendar.badge.clock")
                                .font(.subheadline)
                            Text(project.endDate.formatted(date: .complete, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Days remaining
                    HStack {
                        Text("Days Remaining:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(daysRemaining()) days")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(daysRemaining() < 7 ? .red : .primary)
                    }
                }
                .padding()
                .background(.background)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.7), lineWidth: 2)
                )
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Objectives & Key Results Section
                if !project.objectives.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("OKRs (Objectives & Key Results)")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        ForEach(Array(project.objectives.enumerated()), id: \.element.id) { index, objective in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(index + 1). \(objective.title)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(objective.keyResults) { keyResult in
                                        BulletPointText(text: keyResult.description)
                                    }
                                }
                                .padding(.leading, 20)
                            }
                        }
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.7), lineWidth: 2)
                    )
                    .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OKRs (Objectives & Key Results)")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("No objectives defined for this project yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.7), lineWidth: 2)
                    )
                    .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle("Project Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func daysRemaining() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: project.endDate)
        return max(components.day ?? 0, 0)
    }
    
    // Helper functions to normalize progress values
    private func normalizedProgress(_ progress: Double) -> Double {
        // If progress is > 1, assume it's already in percentage format (e.g., 29, 75)
        // Convert to decimal (0.29, 0.75)
        if progress > 1 {
            return progress / 100.0
        }
        return progress
    }
    
    private func normalizedProgressPercentage(_ progress: Double) -> Int {
        // If progress is > 1, assume it's already in percentage format
        if progress > 1 {
            return Int(progress)
        }
        // Otherwise convert from decimal to percentage
        return Int(progress * 100)
    }
}

// Project Tasks View
struct ProjectTasksView: View {
    let project: Project
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var selectedStatus: TaskStatus? = nil
    @State private var showRecurringOnly: Bool = false
    private let summaryColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    
    var tasks: [Task] {
        firebaseService.tasks
    }
    
    var filteredTasks: [Task] {
        var result = tasks
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        if showRecurringOnly {
            result = result.filter { $0.isRecurring }
        }
        return result
    }
    
    
    
    private func toggleStatus(_ status: TaskStatus) {
        // Selecting a status turns off the Recurring-only filter
        showRecurringOnly = false
        if selectedStatus == status { selectedStatus = nil } else { selectedStatus = status }
    }

    private func toggleRecurring() {
        // Selecting Recurring shows only recurring tasks and clears status filter
        if showRecurringOnly {
            showRecurringOnly = false
        } else {
            selectedStatus = nil
            showRecurringOnly = true
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Task Summary Grid (4 x 2)
                LazyVGrid(columns: summaryColumns, spacing: 12) {
                    Button(action: { toggleStatus(.completed) }) {
                        TaskSummaryCard(count: completedTasksCount, title: "Done", color: .green, isSelected: selectedStatus == .completed)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { toggleStatus(.inProgress) }) {
                        TaskSummaryCard(count: inProgressTasksCount, title: "In Progress", color: .orange, isSelected: selectedStatus == .inProgress)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { toggleStatus(.notStarted) }) {
                        TaskSummaryCard(count: notStartedTasksCount, title: "TODO", color: .red, isSelected: selectedStatus == .notStarted)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { toggleStatus(.stuck) }) {
                        TaskSummaryCard(count: stuckTasksCount, title: "Stuck", color: .orange, isSelected: selectedStatus == .stuck)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { toggleStatus(.waitingFor) }) {
                        TaskSummaryCard(count: waitingForTasksCount, title: "Waiting For", color: .purple, isSelected: selectedStatus == .waitingFor)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { toggleStatus(.onHoldByClient) }) {
                        TaskSummaryCard(count: onHoldByClientTasksCount, title: "Hold by Client", color: .orange, isSelected: selectedStatus == .onHoldByClient)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { toggleStatus(.needHelp) }) {
                        TaskSummaryCard(count: needHelpTasksCount, title: "Need Help", color: .red, isSelected: selectedStatus == .needHelp)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { toggleRecurring() }) {
                        TaskSummaryCard(count: recurringTasksCount, title: "Recurring Task", color: .purple, isSelected: showRecurringOnly)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                
                
                // Tasks List
                if filteredTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No tasks found")
                            .font(.headline)
                        Text("Tasks for this project will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTasks) { task in
                            ProjectTaskCard(task: task)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle("Project Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let projectId = project.documentId {
                firebaseService.fetchTasks(forProjectId: projectId)
            }
        }
    }
    
    private var completedTasksCount: Int {
        tasks.filter { $0.status == TaskStatus.completed }.count
    }
    
    private var inProgressTasksCount: Int {
        tasks.filter { $0.status == TaskStatus.inProgress }.count
    }
    
    private var notStartedTasksCount: Int {
        tasks.filter { $0.status == TaskStatus.notStarted }.count
    }
    
    private var stuckTasksCount: Int {
        tasks.filter { $0.status == TaskStatus.stuck }.count
    }
    
    private var waitingForTasksCount: Int {
        tasks.filter { $0.status == TaskStatus.waitingFor }.count
    }
    
    private var onHoldByClientTasksCount: Int {
        tasks.filter { $0.status == TaskStatus.onHoldByClient }.count
    }
    
    private var needHelpTasksCount: Int {
        tasks.filter { $0.status == TaskStatus.needHelp }.count
    }
    
    private var recurringTasksCount: Int {
        tasks.filter { $0.isRecurring }.count
    }
}

// Task Summary Card
struct TaskSummaryCard: View {
    let count: Int
    let title: String
    let color: Color
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.9),
                            Color.gray.opacity(0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
}

// Project Task Card using your existing Task model - RENAMED to avoid conflict
struct ProjectTaskCard: View {
    let task: Task
    
    var priorityDisplay: String {
        switch task.priority {
        case .p1: return "High"
        case .p2: return "Medium"
        case .p3: return "Low"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status and Priority Badges
                VStack(alignment: .trailing, spacing: 4) {
                    // Status Badge
                    Text(task.status.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor)
                        .cornerRadius(6)
                    
                    // Priority Badge
                    Text(priorityDisplay)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor)
                        .cornerRadius(6)
                }
            }
            
            // Due Date and Assigned To
            HStack {
                Label(
                    task.dueDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.caption2)
                .foregroundColor(.gray)
                
                Spacer()
                
                Label(
                    task.assignedTo,
                    systemImage: "person"
                )
                .font(.caption2)
                .foregroundColor(.gray)
                
                // Days remaining badge
                Text("\(daysRemaining()) days left")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(daysRemainingColor())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(daysRemainingColor().opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(.background)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.9),
                            Color.gray.opacity(0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch task.status {
        case .notStarted: return .red
        case .inProgress: return .orange
        case .stuck: return .orange
        case .waitingFor: return .purple
        case .onHoldByClient: return .orange
        case .needHelp: return .red
        case .completed: return .green
        case .canceled: return .gray
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .p1: return .red
        case .p2: return .orange
        case .p3: return .blue
        }
    }
    
    private func daysRemaining() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: task.dueDate)
        return max(components.day ?? 0, 0)
    }
    
    private func daysRemainingColor() -> Color {
        let days = daysRemaining()
        if days == 0 {
            return .red
        } else if days <= 3 {
            return .orange
        } else {
            return .green
        }
    }
}

// Issue Model and related views (kept from original code)
struct Issue: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let status: IssueStatus
    let reportedDate: Date
    let projectId: UUID
}

enum IssueStatus: String, CaseIterable {
    case pending = "Pending"
    case ongoing = "Ongoing"
    case completed = "Completed"
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .ongoing: return .blue
        case .completed: return .green
        }
    }
}

// Issues View (kept from original code with minor adjustments)
struct IssuesView: View {
    let project: Project
    @State private var issues: [Issue] = [
        Issue(title: "UI not responsive on older devices", description: "The user interface is lagging on devices with iOS 13 and below", status: .pending, reportedDate: Date(), projectId: UUID()),
        Issue(title: "API timeout issues", description: "API calls are timing out after 30 seconds", status: .ongoing, reportedDate: Date().addingTimeInterval(-86400), projectId: UUID()),
        Issue(title: "Memory leak in image loading", description: "Memory usage increases when loading multiple images", status: .completed, reportedDate: Date().addingTimeInterval(-172800), projectId: UUID())
    ]
    
    @State private var showAddIssueForm = false
    @State private var newIssueTitle = ""
    @State private var newIssueDescription = ""
    @State private var selectedStatus: IssueStatus = .pending
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Issues List
                if issues.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No issues reported yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Tap the + button to add your first issue")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else {
                    List {
                        ForEach(issues) { issue in
                            IssueRow(issue: issue)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteIssue)
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Project Issues")
            .navigationBarTitleDisplayMode(.inline)
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showAddIssueForm = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.9))
                                .frame(width: 50, height: 50)
                                .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 2)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .sheet(isPresented: $showAddIssueForm) {
            AddIssueForm(
                isPresented: $showAddIssueForm,
                title: $newIssueTitle,
                description: $newIssueDescription,
                status: $selectedStatus
            ) {
                addNewIssue()
            }
        }
    }
    
    private func addNewIssue() {
        let newIssue = Issue(
            title: newIssueTitle,
            description: newIssueDescription,
            status: selectedStatus,
            reportedDate: Date(),
            projectId: project.id
        )
        issues.append(newIssue)
        
        // Reset form fields
        newIssueTitle = ""
        newIssueDescription = ""
        selectedStatus = .pending
    }
    
    private func deleteIssue(at offsets: IndexSet) {
        issues.remove(atOffsets: offsets)
    }
}

struct IssueRow: View {
    let issue: Issue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(issue.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status Badge
                Text(issue.status.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(issue.status.color)
                    .cornerRadius(6)
            }
            
            // Issue Metadata
            HStack {
                Label(
                    issue.reportedDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.caption2)
                .foregroundColor(.gray)
                
                Spacer()
                
                Label(
                    "Reported",
                    systemImage: "person"
                )
                .font(.caption2)
                .foregroundColor(.gray)
            }
        }
        .padding(10)
        .background(.background)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

struct AddIssueForm: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var description: String
    @Binding var status: IssueStatus
    
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Issue Details")) {
                    TextField("Issue Title", text: $title)
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Issue Description")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                    }
                }
                
                Section(header: Text("Status")) {
                    Picker("Status", selection: $status) {
                        ForEach(IssueStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Report New Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        isPresented = false
                    }
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
}

// Bullet Point Text Component
struct BulletPointText: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Preview
struct ProjectsView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectsView()
    }
}
