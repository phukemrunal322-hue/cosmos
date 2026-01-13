import SwiftUI
import Foundation
import Combine
import FirebaseFirestore

struct TasksView: View {
    @State private var selectedStatus: TaskStatus? = nil
    @State private var selectedStatusLabel: String = "All"
    @State private var selectedProjectFilter: Project? = nil
    @State private var showingCreateTask = false
    @State private var selectedTaskType: CreateTaskView.TaskType = .selfTask
    @State private var selectedTaskTypeFilter: TaskType = .adminTask
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var onlyDueToday: Bool = false
    @State private var selfTasksExternal: [Task] = []
    @State private var assignedTasksFromQuery: [Task] = []
    @State private var showRecurringOnly: Bool = false
    @State private var showTaskCountInfo: Bool = false
    
    // Projects from Firestore - filtered to those assigned to the logged-in employee
    var projects: [Project] {
        var projects = firebaseService.projects

        let currentEmail = authService.currentUser.map { user in
            user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } ?? ""
        let tasks = firebaseService.tasks

        var allowedDocumentIds = Set<String>()
        var allowedNames = Set<String>()
        for task in tasks {
            if let pid = task.project?.documentId, !pid.isEmpty {
                allowedDocumentIds.insert(pid)
            }
            let name = task.project?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if !name.isEmpty {
                allowedNames.insert(name)
            }
        }

        projects = projects.filter { project in
            var isAllowed = false
            if !currentEmail.isEmpty {
                if project.assignedEmployees.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == currentEmail }) {
                    isAllowed = true
                }
            }
            if let docId = project.documentId, allowedDocumentIds.contains(docId) {
                isAllowed = true
            }
            let projectNameLower = project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if allowedNames.contains(projectNameLower) {
                isAllowed = true
            }
            return isAllowed
        }

        return projects
    }
    
    var tasks: [Task] {
        var combined = firebaseService.tasks
        if combined.isEmpty {
            combined.append(contentsOf: assignedTasksFromQuery)
        }
        var seen = Set<String>()
        let calendar = Calendar.current
        return combined.filter { t in
            let day = calendar.startOfDay(for: t.dueDate)
            let key = t.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + "|" + String(Int(day.timeIntervalSince1970))
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func refreshAssignedTasks() {
        let uid = authService.currentUid
        let email = authService.currentUser?.email
        firebaseService.fetchTasksAssigned(toUserUid: uid, userEmail: email) { tasks in
            DispatchQueue.main.async {
                let blocked = Set(["m", "mmm", "f", "cccccc", "ccccccc"])
                self.assignedTasksFromQuery = tasks.filter { !blocked.contains($0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
            }
        }
    }
    
    private func applyStatusFilter(_ label: String) {
        selectedStatusLabel = label
        switch label {
        case "All":
            selectedStatus = nil
            showRecurringOnly = false
            onlyDueToday = false
        case "Today's Task":
            selectedStatus = nil
            showRecurringOnly = false
            onlyDueToday = true
        case "Recurring Task":
            selectedStatus = nil
            showRecurringOnly = true
            onlyDueToday = false
        default:
            let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let status: TaskStatus?
            switch normalized {
            case "todo", "to do", "to-do":
                status = .notStarted
            case "in progress", "in-progress", "inprogress":
                status = .inProgress
            case "stuck":
                status = .stuck
            case "waiting for", "waiting for client", "waiting":
                status = .waitingFor
            case "hold by client", "on hold by client", "hold", "hold client":
                status = .onHoldByClient
            case "need help":
                status = .needHelp
            case "done", "completed", "complete":
                status = .completed
            case "canceled", "cancelled":
                status = .canceled
            default:
                status = TaskStatus(rawValue: label)
            }
            selectedStatus = status
            showRecurringOnly = false
            onlyDueToday = false
        }
    }
    
    var filteredTasks: [Task] {
        // Start with tasks source depending on Admin / Self toggle
        let aggregated: [Task]
        if selectedTaskTypeFilter == .selfTask {
            // Self toggle ON: only show tasks loaded from '/selfTasks'
            aggregated = selfTasksExternal
        } else {
            // Admin toggle ON: show tasks assigned via '/tasks'
            aggregated = tasks
        }
        // Deduplicate by title + due date seconds (no doc IDs available here)
        var seen = Set<String>()
        let calendar = Calendar.current
        var filtered = aggregated.filter { t in
            let day = calendar.startOfDay(for: t.dueDate)
            let key = t.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + "|" + String(Int(day.timeIntervalSince1970))
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        let blocked = Set(["m", "mmm", "f", "cccccc", "ccccccc"]) // titles to hide

        // Apply explicit status filter from dropdown (TODO / In Progress / Done)
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        } else {
            let trimmed = selectedStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let wanted = trimmed.lowercased()
            if !trimmed.isEmpty,
               wanted != "all",
               wanted != "recurring task",
               wanted != "today's task",
               wanted != "todays task",
               wanted != "today" {
                let cal = Calendar.current
                filtered = filtered.filter { task in
                    let titleKey = task.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let day = cal.startOfDay(for: task.dueDate)
                    let key = titleKey + "|" + String(Int(day.timeIntervalSince1970))
                    let raw = firebaseService.taskRawStatusByKey[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return raw == wanted
                }
            }
        }
        
        if let project = selectedProjectFilter {
            filtered = filtered.filter { $0.project?.id == project.id }
        }
        
        // Filter by task type (extra safety)
        filtered = filtered.filter { task in
            if selectedTaskTypeFilter == .selfTask {
                // In Self mode, keep only tasks explicitly marked as self tasks
                return task.taskType == .selfTask
            } else {
                // In Admin mode, show all tasks assigned to the user (admin, client, self)
                return true
            }
        }
        // Hide unwanted titles
        filtered = filtered.filter { !blocked.contains($0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        
        // Recurring tasks visibility: hide only those whose recurring window has fully ended
        let now = Date()
        filtered = filtered.filter { task in
            guard task.isRecurring else { return true }
            if let end = task.recurringEndDate {
                // Keep visible while we are on or before the recurring end date
                return now <= Calendar.current.startOfDay(for: end)
            } else {
                // No explicit end date: always visible
                return true
            }
        }

        if showRecurringOnly {
            filtered = filtered.filter { $0.isRecurring }
        }
        
        // Completion visibility controlled by eye toggle; rely on status and project filters otherwise
        // Optional: Due Today filter injected from Dashboard
        if onlyDueToday {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            filtered = filtered.filter { task in
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
            }
        }
        
        return filtered
    }
    
    private var projectFilterMenu: some View {
        Menu {
            Button("All Projects") {
                selectedProjectFilter = nil
            }
            
            Divider()
            
            ForEach(projects, id: \.id) { project in
                Button(action: {
                    selectedProjectFilter = project
                }) {
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(Double(project.progress)))
                            .frame(width: 10, height: 10)
                        Text(project.name)
                        Text("(\(Int(project.progress * 100))%)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedProjectFilter?.name ?? "All Projects")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var statusFilterMenu: some View {
        Menu {
            ForEach(firebaseService.taskStatusOptions, id: \.self) { label in
                Button(label) {
                    applyStatusFilter(label)
                }
            }
        } label: {
            HStack {
                Text(selectedStatusLabel)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var topFilterBar: some View {
        HStack {
            projectFilterMenu
            
            statusFilterMenu
            
            // Removed completion visibility toggle button
            
            Spacer()
            
            // Plus Button - Opens Self Task Form
            Button(action: {
                selectedTaskType = .selfTask
                showingCreateTask = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Self Task")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.leading, 8)
            
            if selectedProjectFilter != nil {
                Button(action: {
                    selectedProjectFilter = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.background)
        .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)
    }
    
    private var toggleSection: some View {
        HStack {
            Spacer()
            
            // Admin/Employee Toggle Switch
            HStack(spacing: 12) {
                Text("Admin")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(selectedTaskTypeFilter == .adminTask ? .primary : .gray)
                
                Toggle("", isOn: Binding(
                    get: { selectedTaskTypeFilter == .selfTask },
                    set: { isOn in
                        selectedTaskTypeFilter = isOn ? .selfTask : .adminTask
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Text("Self")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(selectedTaskTypeFilter == .selfTask ? .primary : .gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.background)
        .shadow(color: .gray.opacity(0.05), radius: 1, y: 1)
    }

    private var emptyStateTitle: String {
        if showRecurringOnly {
            return "No Recurring Tasks"
        }
        if let status = selectedStatus {
            return "No \(status.rawValue) Tasks"
        }
        if onlyDueToday {
            return "No Tasks Due Today"
        }
        return "No Tasks Found"
    }

    private var emptyStateSubtitle: String {
        if showRecurringOnly {
            return "There are no recurring tasks for the selected filters."
        }
        if let status = selectedStatus {
            return "There are no tasks marked as \(status.rawValue)."
        }
        if onlyDueToday {
            return "There are no tasks due today with the selected filters."
        }
        if selectedProjectFilter != nil {
            return "There are no tasks in this project for the selected filters."
        }
        return "Try changing your filters or creating a new task."
    }

    private var tasksList: some View {
        ScrollView {
            if filteredTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checklist")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text(emptyStateTitle)
                        .font(.headline)
                    Text(emptyStateSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTasks) { task in
                        TaskCard(task: task)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topFilterBar
            toggleSection
            tasksList
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle(selectedProjectFilter != nil ? "\(selectedProjectFilter!.name) Tasks" : "My Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        selectedTaskType = .selfTask
                        showingCreateTask = true
                    }) {
                        Label("Self Task", systemImage: "person.fill")
                    }
                    
                    Button(action: {
                        selectedTaskType = .adminTask
                        showingCreateTask = true
                    }) {
                        Label("Admin Task", systemImage: "person.2.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            let name = authService.currentUser?.name
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email, userName: name)
            refreshAssignedTasks()
            // Load only the projects that belong to the logged-in employee,
            // so the Project dropdown matches the Projects tab.
            firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email, userName: name)
            firebaseService.listenTaskStatusOptions()
            // Start listening to '/selfTasks' for the current user as well
            firebaseService.fetchSelfTasks(forUserUid: uid, userEmail: email) { tasks in
                DispatchQueue.main.async {
                    self.selfTasksExternal = tasks
                }
            }
            // Cleanup unwanted test tasks from both collections for this user
            firebaseService.deleteTasksByTitles(["M", "Mmm", "F", "Cccccc", "Ccccccc"], forUserUid: uid, userEmail: email, completion: nil)
        }
        .onReceive(firebaseService.$tasks) { _ in
            refreshAssignedTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TasksFilter"))) { notification in
            if let info = notification.userInfo {
                if let due = info["dueToday"] as? Bool {
                    onlyDueToday = due
                } else {
                    onlyDueToday = false
                }
                if let statusStr = info["status"] as? String {
                    switch statusStr {
                    case "completed":
                        selectedStatus = .completed
                    case "inProgress":
                        selectedStatus = .inProgress
                    case "notStarted":
                        selectedStatus = .notStarted
                    case "pending":
                        // pending = all non-completed (default behavior)
                        selectedStatus = nil
                    case "all":
                        selectedStatus = nil
                    default:
                        selectedStatus = nil
                    }
                } else {
                    selectedStatus = nil
                }
            } else {
                // Reset to defaults
                onlyDueToday = false
                selectedStatus = nil
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskView(
                taskType: selectedTaskType,
                projects: projects
            ) { taskData in
                let newTask = Task(
                    title: taskData.title,
                    description: taskData.description,
                    status: taskData.status,
                    priority: taskData.priority,
                    startDate: taskData.assignedDate,
                    dueDate: taskData.dueDate,
                    assignedTo: authService.currentUser?.email ?? "Current User",
                    comments: [],
                    department: nil,
                    project: taskData.project,
                    taskType: taskData.taskType == .selfTask ? .selfTask : .adminTask,
                    isRecurring: taskData.isRecurring,
                    recurringPattern: taskData.recurringPattern,
                    recurringDays: taskData.recurringDays,
                    recurringEndDate: taskData.recurringEndDate,
                    subtask: taskData.subtask,
                    weightage: taskData.weightage,
                    subtaskStatus: nil
                )
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                if taskData.taskType == .selfTask {
                    // Self tasks go only to '/selfTasks'
                    firebaseService.saveSelfTask(task: newTask, createdByUid: uid, createdByEmail: email) { ok in
                        // Preserve exact label after create
                        if ok {
                            let pid = taskData.project?.documentId
                            firebaseService.updateSelfTaskStatusLabel(title: taskData.title, projectId: pid, forUserUid: uid, userEmail: email, toLabel: taskData.statusLabel, completion: nil)
                        }
                    }
                } else {
                    // Admin / regular tasks go to '/tasks'
                    firebaseService.createTask(newTask, assignedUid: uid, assignedEmail: email, subtaskItems: taskData.subtaskItems) { ok in
                        // Preserve exact label after create
                        if ok {
                            let pid = taskData.project?.documentId
                            firebaseService.updateTaskStatusLabel(title: taskData.title, projectId: pid, forUserUid: uid, userEmail: email, toLabel: taskData.statusLabel, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    // Removed: fetchAdminTasksFromDatabase and fetchSelfTasksFromDatabase
}

struct TaskCard: View {
    let task: Task
    @State private var progressInput: String = "0"
    @State private var selectedStatus: TaskStatus
    @State private var selectedStatusText: String = ""
    @State private var selectedSubtaskStatus: TaskStatus = .notStarted
    @State private var selectedSubtaskStatusText: String = TaskStatus.notStarted.rawValue
    @State private var showingSubtaskSheet: Bool = false
    @State private var isExpanded: Bool = false
    @State private var showingDetail: Bool = false
    @State private var showCompletionSheet: Bool = false
    @State private var completionComment: String = ""
    @State private var showingEditSheet: Bool = false
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    init(task: Task) {
        self.task = task
        _selectedStatus = State(initialValue: task.status)
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: task.dueDate)
        let keyTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = keyTitle + "|" + String(Int(day.timeIntervalSince1970))
        let raw = FirebaseService.shared.taskRawStatusByKey[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseText: String
        if let label = raw, !label.isEmpty {
            baseText = label
        } else {
            baseText = task.status.rawValue
        }
        // Prefer the exact label from Firestore settings when it normalizes to the same value
        let options = FirebaseService.shared.taskStatusOptions
        func canon(_ s: String) -> String {
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
        }
        if let match = options.first(where: { canon($0) == canon(baseText) }) {
            _selectedStatusText = State(initialValue: match)
        } else {
            _selectedStatusText = State(initialValue: baseText)
        }

        if let subStatus = task.subtaskStatus {
            _selectedSubtaskStatus = State(initialValue: subStatus)
            _selectedSubtaskStatusText = State(initialValue: subStatus.rawValue)
        } else {
            _selectedSubtaskStatus = State(initialValue: .notStarted)
            _selectedSubtaskStatusText = State(initialValue: TaskStatus.notStarted.rawValue)
        }
    }
    
    var priorityDisplay: String {
        switch task.priority {
        case .p1: return "Low"
        case .p2: return "Medium"
        case .p3: return "High"
        }
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .p1: return .green
        case .p2: return .yellow
        case .p3: return .red
        }
    }
    
    var statusColor: Color {
        switch selectedStatus {
        case .completed: return .green
        case .inProgress: return .blue
        case .notStarted: return .gray
        case .stuck: return .orange
        case .waitingFor: return .purple
        case .onHoldByClient: return .orange
        case .needHelp: return .red
        case .canceled: return .gray
        }
    }
    
    var isOverdue: Bool {
        let comparison = Calendar.current.compare(task.dueDate, to: Date(), toGranularity: .day)
        return comparison == .orderedAscending && selectedStatus != .completed
    }
    
    var isDueToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard selectedStatus != .completed else { return false }

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
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            // Expandable Section: Progress, Input, Buttons
            if isExpanded {
                expandedSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.background)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.15), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Group {
                if isOverdue {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
                } else if isDueToday {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(8)
        }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task, taskStatus: $selectedStatus)
        }
        .sheet(isPresented: $showCompletionSheet) {
            CompletionCommentSheet(
                completionComment: $completionComment,
                onMarkDone: {
                    selectedStatus = .completed
                    completionComment = ""
                    showCompletionSheet = false
                },
                onCancel: {
                    completionComment = ""
                    showCompletionSheet = false
                }
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            editSheetContent
        }
        .sheet(isPresented: $showingSubtaskSheet) {
            SubtaskDetailView(
                task: task,
                subtaskStatus: $selectedSubtaskStatus,
                subtaskStatusText: $selectedSubtaskStatusText
            )
        }
        .onChange(of: selectedStatus) { newValue in
            // Prevent echo/loop updates if state matches DB
            guard newValue != task.status else { return }
            
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            let pid = task.project?.documentId
            firebaseService.updateTaskStatus(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, to: newValue, completion: nil)
            if task.taskType == .selfTask {
                firebaseService.updateSelfTaskStatus(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, to: newValue, completion: nil)
            }
        }
        .onChange(of: task.status) { newStatus in
            self.selectedStatus = newStatus
            self.selectedStatusText = newStatus.rawValue // Sync text
        }
        .onChange(of: task.subtaskStatus) { newSub in
            if let s = newSub {
                self.selectedSubtaskStatus = s
                self.selectedSubtaskStatusText = s.rawValue
            }
        }
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            let pid = task.project?.documentId
            let handler: (Int) -> Void = { latest in
                let clamped = max(0, min(100, latest))
                progressInput = String(clamped)
            }
            if task.taskType == .selfTask {
                firebaseService.observeSelfTaskProgress(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, onChange: handler)
            } else {
                firebaseService.observeTaskProgress(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, onChange: handler)
            }
        }
    }
}

extension TaskCard {
    @ViewBuilder
    private var headerSection: some View {
        // Always Visible: Title, Status, Priority, Dates
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                // Title and Description
                Button(action: {
                    showingDetail = true
                }) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(task.description)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                // Badges Row
                HStack(spacing: 8) {
                    // Priority Badge
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10))
                        Text(priorityDisplay)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.15))
                    .foregroundColor(priorityColor)
                    .cornerRadius(4)
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Image(systemName: selectedStatus == .completed ? "checkmark.circle.fill" : selectedStatus == .inProgress ? "arrow.clockwise.circle.fill" : "circle")
                            .font(.system(size: 10))
                        Text(selectedStatusText)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
                    
                    // Recurring Badge
                    if task.isRecurring {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.system(size: 10))
                            if let days = task.recurringDays {
                                Text("\(days)d")
                                    .font(.system(size: 11, weight: .medium))
                            } else if let pattern = task.recurringPattern {
                                Text(pattern.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                    }
                    
                    if isOverdue {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Overdue")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                    } else if isDueToday {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 10))
                            Text("Due Today")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                    }
                }
                
                // Dates Row
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(isOverdue ? .red : (task.isRecurring ? Color.orange : Color.red))
                        if isOverdue {
                            Text("Overdue")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        } else {
                            Text("Due: \(task.dueDate.formatted(date: .numeric, time: .omitted))")
                                .font(.system(size: 12))
                                .foregroundColor(task.isRecurring ? Color.orange : .gray)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11))
                            .foregroundColor(task.isRecurring ? Color.orange : .purple)
                        Text("Assigned: \(task.startDate.formatted(date: .numeric, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundColor(task.isRecurring ? Color.orange : .gray)
                    }
                }

                // Recurring summary row
                if task.isRecurring, let endDate = task.recurringEndDate {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                        Text("Recurring Task")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.purple)
                        Text("• End: \(endDate.formatted(date: .numeric, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                    }
                }
            }
            
            Spacer()
            
            // Chevron Button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 30, height: 30)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 12) {
                // Progress Bar (only show for In Progress tasks)
                if selectedStatus == .inProgress {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geometry in
                            let progressValue = Double(progressInput) ?? 0
                            let clampedProgress = max(0, min(100, progressValue))
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(statusColor)
                                    .frame(width: geometry.size.width * clampedProgress / 100, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                        
                        let displayValue = Int(max(0, min(100, Double(progressInput) ?? 0)))
                        Text("\(displayValue)%")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                
                // Input and Buttons Row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Show progress input and Update button only for In Progress tasks
                        if selectedStatus == .inProgress {
                            TextField("0", text: $progressInput)
                                .keyboardType(.numberPad)
                                .font(.system(size: 13))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(width: 60)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .onChange(of: progressInput) { newValue in
                                    if newValue.isEmpty { return }
                                    let digitsOnly = newValue.filter { $0.isNumber }
                                    if digitsOnly != newValue {
                                        progressInput = digitsOnly
                                        return
                                    }
                                    if let intVal = Int(digitsOnly) {
                                        let clamped = max(0, min(100, intVal))
                                        if clamped != intVal {
                                            progressInput = String(clamped)
                                        }
                                    }
                                }
                            
                            Button(action: {
                                let uid = authService.currentUid
                                let email = authService.currentUser?.email
                                let pid = task.project?.documentId
                                let raw = Int(progressInput) ?? 0
                                let val = max(0, min(100, raw))
                                progressInput = String(val)
                                firebaseService.updateTaskProgress(
                                    title: task.title,
                                    projectId: pid,
                                    forUserUid: uid,
                                    userEmail: email,
                                    to: val,
                                    completion: nil
                                )
                                if task.taskType == .selfTask {
                                    firebaseService.updateSelfTaskProgress(
                                        title: task.title,
                                        projectId: pid,
                                        forUserUid: uid,
                                        userEmail: email,
                                        to: val,
                                        completion: nil
                                    )
                                }
                            }) {
                                Text("Update")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            }
                        }

                        Button(action: {
                            showingEditSheet = true
                        }) {
                            Text("Edit")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        // Delete button only for self tasks
                        if task.taskType == .selfTask {
                            Button(action: {
                                let uid = authService.currentUid
                                let email = authService.currentUser?.email
                                let title = task.title
                                firebaseService.deleteTasksByTitles([title], forUserUid: uid, userEmail: email, completion: nil)
                            }) {
                                Text("Delete")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }

                        if let sub = task.subtask?.trimmingCharacters(in: .whitespacesAndNewlines), !sub.isEmpty {
                            Button(action: {
                                showingSubtaskSheet = true
                            }) {
                                Text("Subtask")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }

                        // Status Dropdown (dynamic from Firestore settings)
                        Menu {
                            ForEach(firebaseService.taskStatusOptions.filter {
                                let v = $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                return v != "all" && v != "done" && v != "completed" && v != "complete" && v != "today's task" && v != "todays task" && v != "today"
                            }, id: \.self) { label in
                                Button(label) {
                                    let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    let mapped: TaskStatus?
                                    switch normalized {
                                    case "todo", "to-do", "to do":
                                        mapped = .notStarted
                                    case "in progress", "inprogress":
                                        mapped = .inProgress
                                    case "stuck":
                                        mapped = .stuck
                                    case "waiting for", "waiting for client", "waiting":
                                        mapped = .waitingFor
                                    case "hold by client", "on hold by client", "hold":
                                        mapped = .onHoldByClient
                                    case "need help":
                                        mapped = .needHelp
                                    case "done", "completed":
                                        mapped = .completed
                                    case "canceled", "cancelled":
                                        mapped = .canceled
                                    default:
                                        mapped = nil
                                    }
                                    if let m = mapped {
                                        selectedStatus = m
                                        selectedStatusText = label
                                    } else {
                                        selectedStatusText = label
                                        let uid = authService.currentUid
                                        let email = authService.currentUser?.email
                                        let pid = task.project?.documentId
                                        if task.taskType == .selfTask {
                                            firebaseService.updateSelfTaskStatusLabel(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, toLabel: label, completion: nil)
                                        } else {
                                            firebaseService.updateTaskStatusLabel(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, toLabel: label, completion: nil)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedStatusText)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }

                        // Separate Done button (same behavior as previous Done menu option)
                        Button(action: {
                            showCompletionSheet = true
                        }) {
                            Text("Done")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var editSheetContent: some View {
        let initialTaskType: CreateTaskView.TaskType = (task.taskType == .selfTask ? .selfTask : .adminTask)
        // Use the same employee-scoped project list logic as TasksView.projects,
        // so the dropdown only shows projects actually available to the logged-in employee.
        let currentEmail = authService.currentUser?.email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        var filteredProjects = firebaseService.projects
        let tasksAll = firebaseService.tasks
        var allowedDocumentIds = Set<String>()
        var allowedNames = Set<String>()
        for t in tasksAll {
            if let pid = t.project?.documentId, !pid.isEmpty {
                allowedDocumentIds.insert(pid)
            }
            let name = t.project?.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            if !name.isEmpty {
                allowedNames.insert(name)
            }
        }
        filteredProjects = filteredProjects.filter { project in
            var isAllowed = false
            if !currentEmail.isEmpty {
                if project.assignedEmployees.contains(where: {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == currentEmail
                }) {
                    isAllowed = true
                }
            }
            if let docId = project.documentId, allowedDocumentIds.contains(docId) {
                isAllowed = true
            }
            let projectNameLower = project.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if allowedNames.contains(projectNameLower) {
                isAllowed = true
            }
            return isAllowed
        }
        let allowedProjects = filteredProjects

        // Only preselect the task's project if it is in the allowed list; otherwise clear it
        // so the dropdown shows "Select Project" when the employee has no matching project.
        let initialProject: Project?
        if let taskProject = task.project,
           allowedProjects.contains(where: { $0.id == taskProject.id }) {
            initialProject = taskProject
        } else {
            initialProject = nil
        }

        let initialData = NewTaskData(
            title: task.title,
            description: task.description,
            project: initialProject,
            assignedDate: task.startDate,
            dueDate: task.dueDate,
            priority: task.priority,
            status: task.status,
            statusLabel: task.status.rawValue,
            taskType: initialTaskType,
            isRecurring: task.isRecurring,
            recurringPattern: task.recurringPattern,
            recurringDays: task.recurringDays,
            recurringEndDate: task.recurringEndDate,
            subtask: task.subtask,
            weightage: task.weightage
        )
        return CreateTaskView(
            taskType: initialTaskType,
            projects: allowedProjects,
            initialData: initialData
        ) { taskData in
            let updatedTask = Task(
                title: taskData.title,
                description: taskData.description,
                status: taskData.status,
                priority: taskData.priority,
                startDate: taskData.assignedDate,
                dueDate: taskData.dueDate,
                assignedTo: authService.currentUser?.email ?? task.assignedTo,
                comments: task.comments,
                department: task.department,
                project: taskData.project,
                taskType: (taskData.taskType == .selfTask ? .selfTask : .adminTask),
                isRecurring: taskData.isRecurring,
                recurringPattern: taskData.recurringPattern,
                recurringDays: taskData.recurringDays,
                recurringEndDate: taskData.recurringEndDate,
                subtask: taskData.subtask,
                weightage: taskData.weightage,
                subtaskStatus: task.subtaskStatus
            )
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            if taskData.taskType == .selfTask {
                firebaseService.deleteTasksByTitles([task.title], forUserUid: uid, userEmail: email) { _ in
                    firebaseService.saveSelfTask(task: updatedTask, createdByUid: uid, createdByEmail: email) { _ in }
                }
            } else {
                let oldProjectId = task.project?.documentId
                firebaseService.updateTask(oldTitle: task.title, oldProjectId: oldProjectId, forUserUid: uid, userEmail: email, with: updatedTask, statusLabel: taskData.statusLabel, completion: nil)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct TaskDetailView: View {
    let task: Task
    @Environment(\.dismiss) var dismiss
    @State private var selectedStatus: TaskStatus
    @State private var showCompletionSheet = false
    @State private var completionComment = ""
    @Binding var taskStatus: TaskStatus
    @State private var subtaskStatus: TaskStatus
    @State private var subtaskStatusText: String = TaskStatus.notStarted.rawValue
    @State private var showSubtaskDetailView: Bool = false
    @State private var fetchedProjectName: String? = nil
    
    // Activity Support
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var activities: [ActivityItem] = []
    @State private var commentText: String = ""
    @State private var taskDocumentId: String?
    @State private var activityListener: ListenerRegistration?
    @State private var activityDisplayLimit: Int = 10
    
    init(task: Task, taskStatus: Binding<TaskStatus>) {
        self.task = task
        _selectedStatus = State(initialValue: task.status)
        _taskStatus = taskStatus
        let initialSubtaskStatus = task.subtaskStatus ?? .notStarted
        _subtaskStatus = State(initialValue: initialSubtaskStatus)
        _subtaskStatusText = State(initialValue: initialSubtaskStatus.rawValue)
    }
    
    var priorityDisplay: String {
        switch task.priority {
        case .p1: return "Low"
        case .p2: return "Medium"
        case .p3: return "High"
        }
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .p1: return .green
        case .p2: return .yellow
        case .p3: return .red
        }
    }
    
    var statusColor: Color {
        switch selectedStatus {
        case .completed: return .green
        case .inProgress: return .blue
        case .notStarted: return .gray
        case .stuck: return .orange
        case .waitingFor: return .purple
        case .onHoldByClient: return .orange
        case .needHelp: return .red
        case .canceled: return .gray
        }
    }
    
    @ViewBuilder
    private var projectSection: some View {
        if let project = task.project {
            VStack(alignment: .leading, spacing: 4) {
                Text("Project")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Text(fetchedProjectName ?? project.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Task Title")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Text(task.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Text(task.description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statusPrioritySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(selectedStatus.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(statusColor)
                }
            }
            
            Spacer()
            
            // Priority
            VStack(alignment: .trailing, spacing: 4) {
                Text("Priority")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                    Text(priorityDisplay)
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(priorityColor)
            }
        }
    }
    
    private var datesSection: some View {
        VStack(spacing: 12) {
            // Assigned Date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assigned Date")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                        Text(task.startDate.formatted(date: .long, time: .omitted))
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
            }
            
            // Due Date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Due Date")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        Text(task.dueDate.formatted(date: .long, time: .omitted))
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
            }
            
            // Recurring Information
            if task.isRecurring {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                        Text("Recurring Task")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                    
                    if let days = task.recurringDays {
                        HStack(spacing: 6) {
                            Text("Repeats every")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            Text("\(days) day\(days == 1 ? "" : "s")")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    }
                    
                    if let pattern = task.recurringPattern {
                        HStack(spacing: 6) {
                            Text("Pattern:")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            Text(pattern.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    }
                    
                    if let endDate = task.recurringEndDate {
                        HStack(spacing: 6) {
                            Text("Ends on:")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            Text(endDate.formatted(date: .long, time: .omitted))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    } else {
                        Text("No end date")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private var statusUpdateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update Status")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                statusButton(status: .notStarted, icon: "circle", label: "TODO", color: .gray)
                statusButton(status: .inProgress, icon: "arrow.clockwise.circle.fill", label: "In Progress", color: .blue)
                doneButton
            }
        }
    }
    
    private func statusButton(status: TaskStatus, icon: String, label: String, color: Color) -> some View {
        Button(action: {
            selectedStatus = status
            taskStatus = status
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedStatus == status ? color.opacity(0.2) : color.opacity(0.05))
            .foregroundColor(selectedStatus == status ? color : color.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedStatus == status ? color : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private var doneButton: some View {
        Button(action: {
            showCompletionSheet = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                Text("Done")
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedStatus == .completed ? Color.green.opacity(0.2) : Color.green.opacity(0.05))
            .foregroundColor(selectedStatus == .completed ? .green : .green.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedStatus == .completed ? Color.green : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private var taskDetailsBox: some View {
        VStack(alignment: .leading, spacing: 16) {
            projectSection
            taskInfoSection
            Divider()
            statusPrioritySection
            Divider()
            datesSection
            Divider()
            statusUpdateSection
        }
        .padding(20)
        .background(.background)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    taskDetailsBox
                    Button(action: {
                        showSubtaskDetailView = true
                    }) {
                        HStack {
                            Text("Subtask")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "eye")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .sheet(isPresented: $showSubtaskDetailView) {
                        SubtaskDetailView(task: task, subtaskStatus: $subtaskStatus, subtaskStatusText: $subtaskStatusText)
                    }
                    
                    activitySection
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        taskStatus = selectedStatus
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showCompletionSheet) {
                CompletionCommentSheet(
                    completionComment: $completionComment,
                    onMarkDone: {
                        selectedStatus = .completed
                        taskStatus = .completed
                        showCompletionSheet = false
                        dismiss()
                    },
                    onCancel: {
                        completionComment = ""
                        showCompletionSheet = false
                    }
                )
            }
            .onAppear {
                if let pid = task.project?.documentId, !pid.isEmpty {
                    FirebaseService.shared.fetchProjectName(projectId: pid) { name in
                        if let name = name {
                            self.fetchedProjectName = name
                        }
                    }
                }
                fetchActivities()
            }
            .onChange(of: task.status) { newStatus in
                self.selectedStatus = newStatus
                self.taskStatus = newStatus
            }
            .onDisappear {
                if let listener = activityListener {
                    listener.remove()
                }
            }
        }
    }
    
    // MARK: - Activity Logic
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("ACTIVITY")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            // Subcollection Activity List
            VStack(alignment: .leading, spacing: 0) {
                if activities.isEmpty {
                     if !task.comments.isEmpty {
                        // Legacy comments support
                         ForEach(task.comments) { comment in
                             timelineRow(
                                user: comment.user,
                                action: "commented",
                                message: comment.message,
                                timestamp: comment.timestamp,
                                iconName: "bubble.left.fill",
                                iconColor: .blue
                             )
                        }
                    } else {
                        Text("No activity yet")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    }
                } else {
                    let displayed = activities.prefix(activityDisplayLimit)
                    ForEach(displayed) { activity in
                         let (icon, color) = iconForAction(activity.action)
                         timelineRow(
                             user: activity.user,
                             action: activity.action,
                             message: activity.message,
                             timestamp: activity.timestamp,
                             iconName: icon,
                             iconColor: color
                         )
                    }
                    
                    // Controls
                    HStack {
                        if activities.count > activityDisplayLimit {
                            Button(action: { activityDisplayLimit += 10 }) {
                                Text("Load More")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
            }
            
            // Add Comment
            HStack(alignment: .top, spacing: 12) {
                TextEditor(text: $commentText)
                    .frame(height: 60)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                
                Button(action: addComment) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func fetchActivities() {
        firebaseService.findTaskDocumentId(title: task.title, projectId: task.project?.documentId) { docId in
            guard let docId = docId else { return }
            self.taskDocumentId = docId
            
            if let listener = activityListener { listener.remove() }
            self.activityListener = firebaseService.listenToTaskActivities(taskId: docId) { items in
                self.activities = items
            }
        }
    }
    
    private func addComment() {
        guard !commentText.isEmpty else { return }
        
        let message = commentText
        self.commentText = "" // Clear input
        
        // Use current user name
        let user = authService.currentUser?.name ?? "Employee"
        
        if let docId = taskDocumentId {
            let activity = ActivityItem(user: user, action: "commented", message: message, type: "comment")
            firebaseService.addTaskActivity(taskId: docId, activity: activity) { error in
                if let error = error {
                    print("Error adding activity: \(error)")
                }
            }
        } else {
            // Fallback
            firebaseService.addCommentToTask(
                taskTitle: task.title,
                taskProjectId: task.project?.documentId,
                message: message,
                user: user
            ) { _ in }
        }
    }
    
    private func iconForAction(_ action: String) -> (String, Color) {
        if action.contains("status") { return ("arrow.triangle.2.circlepath", .orange) }
        if action.contains("priority") { return ("flag.fill", .red) }
        if action.contains("description") { return ("text.alignleft", .purple) }
        if action.contains("renamed") { return ("pencil", .blue) }
        if action.contains("assign") { return ("person.fill.badge.plus", .green) }
        if action.contains("subtask") { return ("checklist", .pink) }
        return ("bubble.left.fill", .gray)
    }
    
    private func timelineRow(user: String, action: String, message: String?, timestamp: Date, iconName: String, iconColor: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon Column
            VStack(spacing: 0) {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 14))
                            .foregroundColor(iconColor)
                    )
                
                // Timeline Line
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 4)
            }
            .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(user)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(action)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(timestamp.formatted(date: .numeric, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.8))
                }
                
                if let msg = message, !msg.isEmpty {
                    Text(msg)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, 24)
        }
    }
}

struct SubtaskDetailView: View {
    let task: Task
    @Binding var subtaskStatus: TaskStatus
    @Binding var subtaskStatusText: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    @State private var fetchedSubtasks: [SubTaskItem] = []
    @State private var isLoading: Bool = true
    @State private var dbSubtaskIDs: Set<String> = []
        
        var body: some View {
            NavigationView {
                ZStack {
                    Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // SUBTASKS LIST
                            VStack(alignment: .leading, spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else if fetchedSubtasks.isEmpty {
                                    emptyStateView
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(fetchedSubtasks) { item in
                                            subtaskCard(item)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .navigationTitle("Subtask Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { dismiss() }) {
                            Text("Close")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .onAppear {
                    fetchSubtasks()
                }
            }
        }
        
        private func fetchSubtasks() {
            let pid = task.project?.documentId
            // 1. Fetch from DB Sub-collection
            firebaseService.fetchSubtasks(taskTitle: task.title, taskProjectId: pid) { items in
                
                // 2. Fetch parent task to get string subtasks
                firebaseService.fetchTaskLegacySubtaskString(title: task.title, projectId: pid) { subString in
                    var combined = items
                    // Store DB IDs to distinguish for deletion
                    self.dbSubtaskIDs = Set(items.map { $0.id })
                    
                    if let s = subString, !s.isEmpty {
                        let parsed = parseLegacySubtasks(from: s)
                        combined.append(contentsOf: parsed)
                    }
                    
                    self.fetchedSubtasks = combined
                    self.isLoading = false
                }
            }
        }
        
        private func parseLegacySubtasks(from string: String) -> [SubTaskItem] {
            var items: [SubTaskItem] = []
            let lines = string.components(separatedBy: "\n")
            
            for line in lines {
                var title = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if title.isEmpty { continue }
                
                var dueDate = Date().addingTimeInterval(86400 * 7)
                var assignee: String? = nil
                var priority: Priority = .p2
                
                // [Due: yyyy-MM-dd]
                if let dueRange = title.range(of: "\\[Due: (.*?)\\]", options: .regularExpression) {
                    let dateStr = String(title[dueRange].dropFirst(6).dropLast(1))
                    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                    if let d = f.date(from: dateStr) { dueDate = d }
                    title.removeSubrange(dueRange)
                }
                
                // [Assignee: ...]
                if let assignRange = title.range(of: "\\[Assignee: (.*?)\\]", options: .regularExpression) {
                    assignee = String(title[assignRange].dropFirst(11).dropLast(1))
                    title.removeSubrange(assignRange)
                }
                
                // [P: ...]
                if let pRange = title.range(of: "\\[P: (.*?)\\]", options: .regularExpression) {
                    let pLabel = String(title[pRange].dropFirst(4).dropLast(1))
                    switch pLabel.lowercased() {
                    case "high", "p1": priority = .p1
                    case "medium", "p2": priority = .p2
                    case "low", "p3": priority = .p3
                    default: priority = .p2
                    }
                    title.removeSubrange(pRange)
                }
                
                title = title.trimmingCharacters(in: .whitespaces)
                
                items.append(SubTaskItem(
                    id: UUID().uuidString,
                    title: title,
                    status: .notStarted,
                    priority: priority,
                    dueDate: dueDate,
                    assignedTo: assignee
                ))
            }
            return items
        }
        

        
        private var emptyStateView: some View {
            VStack(spacing: 16) {
                Image(systemName: "checklist")
                    .font(.largeTitle)
                    .foregroundColor(.gray.opacity(0.5))
                Text("No subtasks available")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        
        private func subtaskCard(_ item: SubTaskItem) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Title and Priority
                HStack(alignment: .top) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold)) // Bold Title
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    Text(priorityLabel(item.priority))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor(item.priority).opacity(0.15))
                        .foregroundColor(priorityColor(item.priority))
                        .cornerRadius(6)
                }
                
                Divider()
                
                // Footer: Metadata (Assignee, Date)
                HStack(spacing: 16) {
                    // Assignee
                    if let assignee = item.assignedTo {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(assignee)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Unassigned")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Due Date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(item.dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            // Add Context Menu actions to update status
            .contextMenu {
                Button {
                    updateIndividualSubtaskStatus(item: item, to: .completed)
                } label: {
                    Label("Mark as Done", systemImage: "checkmark.circle")
                }
                
                Button {
                    updateIndividualSubtaskStatus(item: item, to: .inProgress)
                } label: {
                    Label("Mark in Progress", systemImage: "arrow.right.circle")
                }
                
                Button {
                    updateIndividualSubtaskStatus(item: item, to: .notStarted)
                } label: {
                    Label("Mark as TODO", systemImage: "circle")
                }
                
                Divider()
                
                Text("Current Status: \(item.status.rawValue)")
            
            Button(role: .destructive) {
                deleteSubtask(item)
            } label: {
                Label("Delete Subtask", systemImage: "trash")
            }
        }
    }
        
        // MARK: - Helpers
        

        
    private func deleteSubtask(_ item: SubTaskItem) {
        if dbSubtaskIDs.contains(item.id) {
            // Delete from DB
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            let pid = task.project?.documentId
            
            if task.taskType == .selfTask {
                firebaseService.deleteSelfSubtask(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, subtaskId: item.id) { success in
                    if success { fetchSubtasks() }
                }
            } else {
                firebaseService.deleteSubtask(taskTitle: task.title, taskProjectId: pid, subtaskId: item.id) { success in
                    if success { fetchSubtasks() }
                }
            }
        } else {
            // Delete from Legacy String
            deleteLegacySubtask(item)
        }
    }
    
    private func deleteLegacySubtask(_ item: SubTaskItem) {
        let pid = task.project?.documentId
        firebaseService.fetchTaskLegacySubtaskString(title: task.title, projectId: pid) { currentString in
             guard let currentString = currentString else { return }
             var lines = currentString.components(separatedBy: "\n")
             // Find line similar to item title
             if let index = lines.firstIndex(where: { $0.contains(item.title) }) {
                 lines.remove(at: index)
                 let newString = lines.joined(separator: "\n")
                 firebaseService.updateTaskLegacySubtaskString(title: task.title, projectId: pid, subtaskString: newString) { success in
                     if success { fetchSubtasks() }
                 }
             }
        }
    }
    
    private func updateIndividualSubtaskStatus(item: SubTaskItem, to status: TaskStatus) {
        let uid = authService.currentUid
        let email = authService.currentUser?.email
        let pid = task.project?.documentId
        
        if task.taskType == .selfTask {
            firebaseService.updateSelfSubtaskStatus(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, subtaskId: item.id, to: status) { success in
                if success { fetchSubtasks() }
            }
        } else {
            firebaseService.updateSubtaskStatus(taskTitle: task.title, taskProjectId: pid, subtaskId: item.id, status: status) { success in
                if success { fetchSubtasks() }
            }
        }
    }
        
        private func statusColor(_ status: TaskStatus) -> Color {
            switch status {
            case .completed: return .green
            case .inProgress: return .blue
            case .stuck: return .red
            default: return .primary
            }
        }
        
        private func priorityLabel(_ p: Priority) -> String {
            switch p {
            case .p1: return "High"
            case .p2: return "Medium"
            case .p3: return "Low"
            }
        }
        
        private func priorityColor(_ p: Priority) -> Color {
            switch p {
            case .p1: return .red
            case .p2: return .orange
            case .p3: return .green
            }
        }
    }
    
    struct CompletionCommentSheet: View {
        @Binding var completionComment: String
        let onMarkDone: () -> Void
        let onCancel: () -> Void
        
        private var isCommentValid: Bool {
            !completionComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        var body: some View {
            NavigationView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mark Task as Done")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("You can add a brief comment about the completion.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $completionComment)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if completionComment.isEmpty {
                                        Text("Add a completion comment (optional)...")
                                            .foregroundColor(.gray.opacity(0.6))
                                            .padding(.leading, 12)
                                            .padding(.top, 16)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                        
                        HStack {
                            Spacer()
                            Text("\(completionComment.count)/300")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Button(action: onMarkDone) {
                            Text("Mark Done")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isCommentValid ? Color.blue : Color.gray.opacity(0.5))
                                .cornerRadius(12)
                        }
                        .disabled(!isCommentValid)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(.background)
            }
        }
    }
    

