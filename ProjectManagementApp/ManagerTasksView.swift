import SwiftUI

struct ManagerTasksView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var authService = FirebaseAuthService.shared
    
    // Search & Filter State
    @State private var searchText = ""
    @State private var selectedStatus = "All Statuses"
    @State private var selectedProject = "All Projects"
    @State private var selectedAssignee = "All Assignees"
    @State private var selectedPriority = "All Priorities"
    @State private var showArchived = false
    
    // Action State
    @State private var showingCreateTask = false
    @State private var selectedTasks = Set<UUID>()
    @State private var isSelectionMode = false
    @State private var editingTask: Task? = nil // Added for edit mode
    
    // Completion Modal State
    @State private var showingCompletionModal = false
    @State private var taskToComplete: Task? = nil
    @State private var completionComment = ""
    
    // Task Detail Modal State
    @State private var selectedTaskForDetail: Task? = nil
    
    // New UI State from Image
    enum TaskSourceFilter: String, CaseIterable {
        case all = "All"
        case resources = "Resources"
        case clients = "Clients"
    }
    
    enum ViewLayoutMode {
        case list
        case grid
    }
    
    @State private var selectedSourceFilter: TaskSourceFilter = .all
    @State private var viewLayoutMode: ViewLayoutMode = .list
    
    // Computed Properties
    var projects: [String] {
        ["All Projects"] + firebaseService.projects.map { $0.name }
    }
    
    var assignees: [String] {
        let employees = firebaseService.employees.map { $0.name }
        let clients = firebaseService.clients.map { $0.name }
        return ["All Assignees"] + employees + clients
    }
    
    var priorities: [String] {
        let options = firebaseService.taskPriorityOptions
        var mapped = options.map { label -> String in
            let upper = label.uppercased()
            if upper.contains("P1") { return "High" }
            if upper.contains("P2") { return "Medium" }
            if upper.contains("P3") { return "Low" }
            return label
        }
        // Deduplicate
        mapped = Array(Set(mapped))
        // Sort: All Priorities first, then High, Medium, Low
        mapped.sort { a, b in
            let order = ["All Priorities": -1, "High": 0, "Medium": 1, "Low": 2]
            let idxA = order[a] ?? 100
            let idxB = order[b] ?? 100
            if idxA != idxB { return idxA < idxB }
            return a < b
        }
        return mapped
    }
    
    var statuses: [String] {
        ["All Statuses", "TODO", "In Progress", "Done", "Stuck", "Overdue", "Canceled"]
    }
    
    var filteredTasks: [Task] {
        var tasks = showArchived ? firebaseService.archivedTasks : firebaseService.tasks
        
        // MANAGER SCOPE: Only show tasks for projects I manage
        if let currentName = authService.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            tasks = tasks.filter { task in
                guard let pmName = task.project?.projectManager else { return false }
                return pmName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == currentName
            }
        } else {
            return []
        }
        // If archived, we might need to fetch them if the array is empty, but usually it's reactive.
        // Assuming firebaseService.archivedTasks exists and is populated.
        
        // 1. Search
        if !searchText.isEmpty {
            tasks = tasks.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 2. Status Filter
        if selectedStatus != "All Statuses" {
            if selectedStatus == "Overdue" {
                tasks = tasks.filter { $0.dueDate < Date() && $0.status != .completed }
            } else {
                tasks = tasks.filter { task in
                    task.status.rawValue.caseInsensitiveCompare(selectedStatus) == .orderedSame
                }
            }
        }
        
        // 3. Project Filter
        if selectedProject != "All Projects" {
            if let project = firebaseService.projects.first(where: { $0.name == selectedProject }) {
                tasks = tasks.filter { 
                    $0.project?.documentId == project.documentId || 
                    $0.project?.name == project.name
                }
            }
        }
        
        // 4. Assignee Filter
        if selectedAssignee != "All Assignees" {
            tasks = tasks.filter { $0.assignedTo.lowercased() == selectedAssignee.lowercased() }
        }
        
        // 5. Priority Filter
        if selectedPriority != "All Priorities" {
            tasks = tasks.filter { task in
                let taskPriorityLabel: String = {
                    switch task.priority {
                    case .p1: return "P1"
                    case .p2: return "P2"
                    case .p3: return "P3"
                    }
                }()
                
                let taskPriorityFriendly: String = {
                    switch task.priority {
                    case .p1: return "High"
                    case .p2: return "Medium"
                    case .p3: return "Low"
                    }
                }()
                
                // Try matching the raw value (P1, P2, P3) or the dynamic label from Firebase
                return task.priority.rawValue.caseInsensitiveCompare(selectedPriority) == .orderedSame ||
                       taskPriorityLabel.caseInsensitiveCompare(selectedPriority) == .orderedSame ||
                       taskPriorityFriendly.caseInsensitiveCompare(selectedPriority) == .orderedSame
            }
        }
        
        // 6. Source Filter (All / Resources / Clients)
        switch selectedSourceFilter {
        case .resources:
            tasks = tasks.filter { $0.taskType == .selfTask || $0.taskType == .adminTask }
        case .clients:
            tasks = tasks.filter { $0.taskType == .clientAssigned }
        case .all:
            break
        }
        
        return tasks
    }
    
    var progress: Double {
        let total = filteredTasks.count
        if total == 0 { return 0 }
        let completed = filteredTasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(total)
    }
    
    var statCounts: (todo: Int, inProgress: Int, completed: Int, overdue: Int) {
        let tasks = filteredTasks
        let todo = tasks.filter { $0.status == .notStarted || $0.status == .waitingFor }.count
        let inProgress = tasks.filter { $0.status == .inProgress }.count
        let completed = tasks.filter { $0.status == .completed }.count
        let overdue = tasks.filter { $0.dueDate < Date() && $0.status != .completed }.count
        return (todo, inProgress, completed, overdue)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 20) {
                        statsGrid
                        progressSection
                        filtersSection
                        actionsSection
                        taskListSection
                    }
                    .padding(.vertical)
                }
            }
            .blur(radius: (showingCompletionModal || selectedTaskForDetail != nil) ? 3 : 0)
            .disabled(showingCompletionModal || selectedTaskForDetail != nil)
            
            // Task Detail View Overlay
            if let detailTask = selectedTaskForDetail {
                TaskDetailModalView(
                    task: detailTask,
                    isPresented: Binding(
                        get: { selectedTaskForDetail != nil },
                        set: { if !$0 { selectedTaskForDetail = nil } }
                    )
                )
                .zIndex(2)
                .transition(.move(edge: .bottom))
            }
            
            // Completion Modal Overlay
            if showingCompletionModal {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation { showingCompletionModal = false }
                    }
                
                VStack(spacing: 20) {
                    Text("Add Completion Comment")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("You can add a brief comment about the completion.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    TextEditor(text: $completionComment)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    HStack {
                        Text(completionComment.count < 5 ? "Minimum 5 characters" : "")
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(completionComment.count)/300")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 16) {
                        Button {
                            withAnimation { showingCompletionModal = false }
                        } label: {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        Button {
                            if let task = taskToComplete {
                                firebaseService.updateTaskStatus(
                                    title: task.title,
                                    projectId: task.project?.documentId,
                                    forUserUid: nil,
                                    userEmail: nil,
                                    to: .completed,
                                    comment: completionComment.isEmpty ? nil : completionComment
                                ) { _ in
                                    // Refresh or handle completion
                                }
                            }
                            withAnimation { showingCompletionModal = false }
                        } label: {
                            Text("Save")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(completionComment.count >= 5 ? Color.blue : Color.gray)
                                .cornerRadius(8)
                        }
                        .disabled(completionComment.count < 5)
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 20)
                .padding(32)
                .transition(.scale)
            }
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            let name = authService.currentUser?.name
            
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email, userName: name)
            firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email, userName: name)
            firebaseService.fetchEmployees()
            firebaseService.fetchClients()
            firebaseService.listenTaskPriorityOptions()
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskView(
                taskType: .adminTask,
                projects: firebaseService.projects,
                initialData: editingTask != nil ? convertTaskToNewTaskData(editingTask!) : nil // Pass data if editing
            ) { taskData in
                if let editingTask = editingTask {
                    // Update Existing Task
                    let updated = Task(
                        title: taskData.title,
                        description: taskData.description,
                        status: taskData.status,
                        priority: taskData.priority,
                        startDate: taskData.assignedDate,
                        dueDate: taskData.dueDate,
                        assignedTo: taskData.assignedTo ?? editingTask.assignedTo,
                        comments: editingTask.comments,
                        department: editingTask.department,
                        project: taskData.project,
                        taskType: editingTask.taskType, // Preserve type
                        isRecurring: taskData.isRecurring,
                        recurringPattern: taskData.recurringPattern,
                        recurringDays: taskData.recurringDays,
                        recurringEndDate: taskData.recurringEndDate,
                        subtask: taskData.subtask,
                        weightage: taskData.weightage,
                        subtaskStatus: editingTask.subtaskStatus
                    )
                    
                    firebaseService.updateTask(
                        oldTitle: editingTask.title,
                        oldProjectId: editingTask.project?.documentId,
                        forUserUid: nil,
                        userEmail: nil,
                        with: updated,
                        statusLabel: taskData.statusLabel
                    ) { _ in
                        // Handled
                    }
                    
                    // Reset editing state after save (although view dismisses)
                    self.editingTask = nil
                } else {
                    // Create New Task
                    let newTask = Task(
                        title: taskData.title,
                        description: taskData.description,
                        status: taskData.status,
                        priority: taskData.priority,
                        startDate: taskData.assignedDate,
                        dueDate: taskData.dueDate,
                        assignedTo: taskData.assignedTo ?? "Admin",
                        comments: [],
                        department: nil,
                        project: taskData.project,
                        taskType: .adminTask,
                        isRecurring: taskData.isRecurring,
                        recurringPattern: taskData.recurringPattern,
                        recurringDays: taskData.recurringDays,
                        recurringEndDate: taskData.recurringEndDate,
                        subtask: taskData.subtask,
                        weightage: taskData.weightage,
                        subtaskStatus: nil
                    )
                    firebaseService.createTask(newTask) { ok in
                        if ok {
                            let pid = taskData.project?.documentId
                            firebaseService.updateTaskStatusLabel(title: taskData.title, projectId: pid, forUserUid: nil, userEmail: nil, toLabel: taskData.statusLabel, completion: nil)
                        }
                    }
                }
            }
        }
        .onChange(of: showingCreateTask) { isShowing in
            // Reset editing state when sheet closes
            if !isShowing {
                editingTask = nil
            }
        }
    }
    
    // Helper to Convert
    private func convertTaskToNewTaskData(_ task: Task) -> NewTaskData {
        // Map User.TaskType to CreateTaskView.TaskType
        let mappedType: CreateTaskView.TaskType = (task.taskType == .adminTask) ? .adminTask : .selfTask
        
        return NewTaskData(
            title: task.title,
            description: task.description,
            project: task.project,
            assignedDate: task.startDate,
            dueDate: task.dueDate,
            priority: task.priority,
            status: task.status,
            statusLabel: task.status.rawValue, 
            taskType: mappedType,
            isRecurring: task.isRecurring,
            recurringPattern: task.recurringPattern,
            recurringDays: task.recurringDays,
            recurringEndDate: task.recurringEndDate,
            subtask: task.subtask,
            weightage: task.weightage,
            assignedTo: task.assignedTo
        )
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Manage and track team tasks")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    editingTask = nil  // Clear editing state for new task
                    showingCreateTask = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Task")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)
    }
    
    private var statsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TaskStatCard(title: "To-Do", count: statCounts.todo, icon: "list.bullet", color: .blue)
                TaskStatCard(title: "In Progress", count: statCounts.inProgress, icon: "clock.fill", color: .blue)
            }
            HStack(spacing: 12) {
                TaskStatCard(title: "Completed", count: statCounts.completed, icon: "checkmark.circle.fill", color: .green)
                TaskStatCard(title: "Overdue", count: statCounts.overdue, icon: "exclamationmark.triangle.fill", color: .red)
            }
        }
        .padding(.horizontal)
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overall Progress")
                    .font(.headline)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geometry.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)
            
            Text("\(filteredTasks.filter { $0.status == .completed }.count) of \(filteredTasks.count) tasks completed")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
        .padding(.horizontal)
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 16)
                    .cornerRadius(2)
                Text("FILTERS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search tasks...", text: $searchText)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Dropdowns Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Menu {
                    ForEach(projects, id: \.self) { project in
                        Button(project) { selectedProject = project }
                    }
                } label: {
                    FilterDropdownButton(title: selectedProject)
                }
                
                Menu {
                    Button("All Assignees") { selectedAssignee = "All Assignees" }
                    
                    if !firebaseService.employees.isEmpty {
                        Section(header: Text("Resources")) {
                            ForEach(firebaseService.employees, id: \.id) { employee in
                                Button(employee.name) { selectedAssignee = employee.name }
                            }
                        }
                    }
                    
                    if !firebaseService.clients.isEmpty {
                        Section(header: Text("Clients")) {
                            ForEach(firebaseService.clients, id: \.documentId) { client in
                                Button(client.name) { selectedAssignee = client.name }
                            }
                        }
                    }
                } label: {
                    FilterDropdownButton(title: selectedAssignee)
                }
                
                Menu {
                    ForEach(statuses, id: \.self) { status in
                        Button(status) { selectedStatus = status }
                    }
                } label: {
                    FilterDropdownButton(title: selectedStatus)
                }
                
                 Menu {
                    ForEach(priorities, id: \.self) { priority in
                        Button(priority) { selectedPriority = priority }
                    }
                } label: {
                    FilterDropdownButton(title: selectedPriority)
                }
            }
            
            HStack {
                Toggle("Show Archived", isOn: $showArchived)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if selectedStatus != "All Statuses" || selectedProject != "All Projects" || selectedAssignee != "All Assignees" || selectedPriority != "All Priorities" || !searchText.isEmpty {
                    Button("Clear Filters") {
                        withAnimation {
                            searchText = ""
                            selectedStatus = "All Statuses"
                            selectedProject = "All Projects"
                            selectedAssignee = "All Assignees"
                            selectedPriority = "All Priorities"
                            showArchived = false
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.red)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
        .padding(.horizontal)
    }
    
    private var actionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Import/Export
                HStack(spacing: 12) {
                    ActionButton(title: "Import", icon: "square.and.arrow.down", color: Color(red: 0.3, green: 0.2, blue: 0.8))
                    ActionButton(title: "Export", icon: "square.and.arrow.up", color: .primary)
                }
                
                Divider()
                    .frame(height: 24)
                    .background(Color.gray.opacity(0.3))
                
                // Segmented Control (All / Resources / Clients)
                HStack(spacing: 0) {
                    ForEach(TaskSourceFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedSourceFilter = filter
                            }
                        }) {
                            Text(filter.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedSourceFilter == filter ? Color.orange : Color.clear)
                                .foregroundColor(selectedSourceFilter == filter ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(4)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
                
                Divider()
                    .frame(height: 24)
                    .background(Color.gray.opacity(0.3))
                
                // View Mode Toggle
                HStack(spacing: 4) {
                    Button(action: { 
                        withAnimation { viewLayoutMode = .list }
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14))
                            .padding(8)
                            .background(viewLayoutMode == .list ? Color(.systemBackground) : Color.clear)
                            .foregroundColor(viewLayoutMode == .list ? .orange : .gray)
                            .cornerRadius(8)
                            .shadow(color: viewLayoutMode == .list ? .black.opacity(0.1) : .clear, radius: 2)
                    }
                    
                    Button(action: {
                        withAnimation { viewLayoutMode = .grid }
                    }) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 14))
                            .padding(8)
                            .background(viewLayoutMode == .grid ? Color(.systemBackground) : Color.clear)
                            .foregroundColor(viewLayoutMode == .grid ? .orange : .gray)
                            .cornerRadius(8)
                            .shadow(color: viewLayoutMode == .grid ? .black.opacity(0.1) : .clear, radius: 2)
                    }
                }
                .padding(4)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var taskListSection: some View {
        if filteredTasks.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.3))
                Text("No tasks found")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .frame(height: 200)
        } else {
            if viewLayoutMode == .list {
                // Selection Bar
                if !selectedTasks.isEmpty {
                    selectionActionsBar
                }
                
                // Status-Grouped Task Sections
                statusGroupedTaskList
                    .padding(.horizontal)
            } else {
                kanbanBoardView
            }
        }
    }
    
    // MARK: - Status Grouped Task List
    
    private var statusGroupedTaskList: some View {
        VStack(spacing: 16) {
            // Todays Tasks Section
            let todaysTasks = filteredTasks.filter { Calendar.current.isDateInToday($0.dueDate) }
            if !todaysTasks.isEmpty {
                TaskStatusSection(
                    title: "TODAYS TASK",
                    color: .purple,
                    tasks: todaysTasks,
                    selectedTasks: $selectedTasks,
                    resolveAssigneeName: resolveAssigneeName,
                    onTaskTap: { task in selectedTaskForDetail = task },
                    onComplete: { task in
                        taskToComplete = task
                        completionComment = ""
                        withAnimation { showingCompletionModal = true }
                    },
                    onEdit: { task in
                        editingTask = task
                        showingCreateTask = true
                    },
                    onDelete: { task in
                        firebaseService.deleteTask(task) { _ in }
                    }
                )
            }
            
            // Status-based sections
            ForEach(TaskStatus.allStatuses, id: \.self) { status in
                let tasksForStatus = filteredTasks.filter { $0.status == status }
                if !tasksForStatus.isEmpty {
                    TaskStatusSection(
                        title: status.rawValue.uppercased(),
                        color: statusColor(for: status),
                        tasks: tasksForStatus,
                        selectedTasks: $selectedTasks,
                        resolveAssigneeName: resolveAssigneeName,
                        onTaskTap: { task in selectedTaskForDetail = task },
                        onComplete: { task in
                            taskToComplete = task
                            completionComment = ""
                            withAnimation { showingCompletionModal = true }
                        },
                        onEdit: { task in
                            editingTask = task
                            showingCreateTask = true
                        },
                        onDelete: { task in
                            firebaseService.deleteTask(task) { _ in }
                        }
                    )
                }
            }
        }
    }
    
    private func resolveAssigneeName(_ id: String) -> String {
        // Look up by ID or Email in Employees
        if let employee = firebaseService.employees.first(where: { $0.id == id || $0.email == id }) {
            return employee.name
        }
        // Look up by Document ID or Email in Clients
        if let client = firebaseService.clients.first(where: { $0.documentId == id || $0.email == id }) {
            return client.name
        }
        // Return original ID if not resolving (likely already a name or not found)
        return id
    }
    
    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .completed: return .green
        case .inProgress: return .blue
        case .notStarted: return .gray
        case .stuck: return .red
        case .waitingFor: return .orange
        case .onHoldByClient: return .purple
        case .needHelp: return .pink
        case .canceled: return .gray
        }
    }
    
    private var selectionActionsBar: some View {
        VStack(spacing: 12) {
            // Selection Count
            HStack {
                Image(systemName: "checkmark.square.fill")
                    .foregroundColor(.blue)
                Text("\(selectedTasks.count) selected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    selectedTasks.removeAll()
                }) {
                    Text("Clear")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            // Action Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Archive Selected
                    Button(action: archiveSelectedTasks) {
                        Text("Archive Selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Unarchive Selected
                    Button(action: unarchiveSelectedTasks) {
                        Text("Unarchive Selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Delete Selected
                    Button(action: deleteSelectedTasks) {
                        Text("Delete Selected")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Selection Actions
    
    private func archiveSelectedTasks() {
        let tasksToArchive = filteredTasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToArchive {
            firebaseService.archiveTask(task) { _ in }
        }
        selectedTasks.removeAll()
    }
    
    private func unarchiveSelectedTasks() {
        let tasksToUnarchive = filteredTasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToUnarchive {
            firebaseService.unarchiveTask(task) { _ in }
        }
        selectedTasks.removeAll()
    }
    
    private func deleteSelectedTasks() {
        let tasksToDelete = filteredTasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToDelete {
            firebaseService.deleteTask(task) { _ in }
        }
        selectedTasks.removeAll()
    }
    

    private var kanbanBoardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(TaskStatus.allStatuses, id: \.self) { status in
                    TaskKanbanColumn(
                        status: status,
                        tasks: filteredTasks.filter { $0.status == status },
                        onDropTask: { task, newStatus in
                            updateTaskStatus(task, to: newStatus)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // Logic for Drag-and-Drop Status Update
    private func updateTaskStatus(_ task: Task, to newStatus: TaskStatus) {
        // Skip if status is same
        guard task.status != newStatus else { return }
        
        firebaseService.updateTaskStatus(
            title: task.title,
            projectId: task.project?.documentId,
            forUserUid: nil,
            userEmail: nil,
            to: newStatus,
            comment: "Moved to \(newStatus.rawValue.uppercased()) via Kanban Board"
        ) { count in
            if count > 0 {
                print("Kanban Manager: Updated task \(task.title) to \(newStatus)")
            }
        }
    }
}

