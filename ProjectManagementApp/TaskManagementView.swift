import SwiftUI
import UniformTypeIdentifiers

struct TaskManagementView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    
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
            firebaseService.fetchTasks(forUserUid: nil, userEmail: nil)
            firebaseService.fetchProjects()
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
        // Optimistically update UI (optional if Firestore listener is fast, but better to wait for callback usually)
        // With current setup, we wait for Firebase.
        
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
                print("Kanban: Updated task \(task.title) to \(newStatus)")
            }
        }
    }
}

// MARK: - Kanban Components

struct TaskKanbanColumn: View {
    let status: TaskStatus
    let tasks: [Task]
    let onDropTask: (Task, TaskStatus) -> Void
    
    @State private var isTargeted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(status.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                if tasks.isEmpty {
                    // Empty state card
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                        .frame(height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isTargeted ? Color.blue : Color(uiColor: .darkGray), lineWidth: isTargeted ? 2 : 3)
                        )
                } else {
                    ForEach(tasks) { task in
                        TaskKanbanCard(task: task)
                    }
                }
            }
            .padding(.bottom, 20)
            .background(isTargeted ? Color.blue.opacity(0.05) : Color.clear)
            .cornerRadius(12)
        }
        .frame(width: 280)
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            
            provider.loadObject(ofClass: NSString.self) { (object, error) in
                if let idString = object as? String, let uuid = UUID(uuidString: idString) {
                    DispatchQueue.main.async {
                        // Find the task from the service
                        if let task = FirebaseService.shared.tasks.first(where: { $0.id == uuid }) {
                             onDropTask(task, status)
                        }
                    }
                }
            }
            return true
        }
    }
}

struct TaskKanbanCard: View {
    let task: Task
    
    var priorityColor: Color {
        switch task.priority {
        case .p1: return .red
        case .p2: return .orange
        case .p3: return .blue
        }
    }
    
    var priorityLabel: String {
        switch task.priority {
        case .p1: return "High"
        case .p2: return "Medium"
        case .p3: return "Low"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Priority
            HStack(alignment: .top) {
                Text(task.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                    Text(priorityLabel)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(priorityColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(priorityColor.opacity(0.1))
                .cornerRadius(4)
            }
            
            // Description
            Text(task.description)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .lineLimit(3)
            
            // Project and Metadata Tags
            HStack(spacing: 6) {
                Text(task.project?.name ?? "COSMOS")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.gray)
                    .cornerRadius(4)
                
                Text("\(task.assignedTo) (admin)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            // Dates Row
            VStack(alignment: .leading, spacing: 6) {
                // Due Date
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("Due: \(task.dueDate.formatted(date: .numeric, time: .omitted))")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                
                // Assigned Date
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("Assigned: \(task.startDate.formatted(date: .numeric, time: .omitted))")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Assignee Dropdown Selector
            Menu {
                // Section: Resources (Employees)
                if !FirebaseService.shared.employees.isEmpty {
                    Section(header: Text("Resources")) {
                        ForEach(FirebaseService.shared.employees, id: \.id) { employee in
                            Button(action: {
                                updateAssignee(name: employee.name, email: employee.email)
                            }) {
                                Text(employee.name)
                                if task.assignedTo == employee.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                // Section: Clients
                if !FirebaseService.shared.clients.isEmpty {
                    Section(header: Text("Clients")) {
                        ForEach(FirebaseService.shared.clients, id: \.documentId) { client in
                            Button(action: {
                                updateAssignee(name: client.name, email: client.email ?? "")
                            }) {
                                Text(client.name)
                                if task.assignedTo == client.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(task.assignedTo)
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.7))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .darkGray), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onDrag {
            NSItemProvider(object: task.id.uuidString as NSString)
        }
    }
    
    private func updateAssignee(name: String, email: String) {
        let pid = task.project?.documentId
        FirebaseService.shared.updateTaskAssignee(
            title: task.title,
            projectId: pid,
            forUserUid: nil,
            userEmail: nil,
            toNewAssigneeEmail: email,
            newAssigneeName: name
        ) { _ in
            print("Updated assignee to \(name)")
        }
    }
}

// MARK: - Status Section Component

struct TaskStatusSection: View {
    let title: String
    let color: Color
    let tasks: [Task]
    @Binding var selectedTasks: Set<UUID>
    let resolveAssigneeName: (String) -> String
    let onTaskTap: (Task) -> Void
    let onComplete: (Task) -> Void
    let onEdit: (Task) -> Void
    let onDelete: (Task) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    
                    // Status Badge
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(color)
                        .cornerRadius(4)
                    
                    // Count
                    Text("\(tasks.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Add Task Button
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                // Table with Header + Rows
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Column Headers
                        HStack(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 10))
                                Text("TASK NAME")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.gray)
                            .frame(width: 200, alignment: .leading)
                            .padding(.leading, 16)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10))
                                Text("ASSIGNEES")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.gray)
                            .frame(width: 120)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text("ASSIGNED")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.gray)
                            .frame(width: 100)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text("DUE DATE")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.gray)
                            .frame(width: 100)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 10))
                                Text("PRIORITY")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.gray)
                            .frame(width: 90)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                Text("STATUS")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.gray)
                            .frame(width: 100)
                            
                            Text("ACTIONS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .frame(width: 80)
                        }
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6).opacity(0.3))
                        
                        // Task Rows
                        ForEach(tasks) { task in
                            TaskStatusRowCard(
                                task: task,
                                isSelected: selectedTasks.contains(task.id),
                                resolveAssigneeName: resolveAssigneeName,
                                onSelect: {
                                    if selectedTasks.contains(task.id) {
                                        selectedTasks.remove(task.id)
                                    } else {
                                        selectedTasks.insert(task.id)
                                    }
                                },
                                onComplete: { onComplete(task) },
                                onEdit: { onEdit(task) },
                                onDelete: { onDelete(task) }
                            )
                            .onTapGesture { onTaskTap(task) }
                        }
                        
                        // Add New Task Row
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text("New Task")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                    }
                    .frame(minWidth: 790)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Task Row for Status Section

struct TaskStatusRowCard: View {
    let task: Task
    let isSelected: Bool
    let resolveAssigneeName: (String) -> String
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var statusColor: Color {
        switch task.status {
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
    
    var statusLabel: String {
        switch task.status {
        case .completed: return "DONE"
        case .inProgress: return "IN PROGRESS"
        case .notStarted: return "TODO"
        case .stuck: return "STUCK"
        case .waitingFor: return "WAITING"
        case .onHoldByClient: return "ON HOLD"
        case .needHelp: return "NEED HELP"
        case .canceled: return "CANCELED"
        }
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .p1: return .red
        case .p2: return .orange
        case .p3: return .blue
        }
    }
    
    var priorityLabel: String {
        switch task.priority {
        case .p1: return "HIGH"
        case .p2: return "MEDIUM"
        case .p3: return "LOW"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Checkbox + Task Name
            HStack(spacing: 10) {
                Button(action: onSelect) {
                    Circle()
                        .strokeBorder(isSelected ? Color.blue : Color.gray.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .fill(isSelected ? Color.blue : Color.clear)
                                .frame(width: 10, height: 10)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)
            .padding(.leading, 16)
            
            // Assignees (Avatar + Name)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    )
                
                Text(resolveAssigneeName(task.assignedTo))
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
            
            // Assigned Date
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text(task.startDate.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .frame(width: 100)
            
            // Due Date
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.red.opacity(0.8))
                Text(task.dueDate.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
            }
            .frame(width: 100)
            
            // Priority Badge
            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 8))
                Text(priorityLabel)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor)
            .cornerRadius(4)
            .frame(width: 90)
            
            // Status Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusLabel)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.1))
            .cornerRadius(4)
            .frame(width: 100)
            
            // Actions
            HStack(spacing: 8) {
                if task.status != .completed {
                    Button(action: onComplete) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 80)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Helper Components

struct TaskStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }
            
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

struct FilterDropdownButton: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    var color: Color = .primary
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
}

struct AdminTaskCard: View {
    let task: Task
    let isSelected: Bool
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var statusColor: Color {
        switch task.status {
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
    
    var statusLabel: String {
        switch task.status {
        case .completed: return "DONE"
        case .inProgress: return "IN PROGRESS"
        case .notStarted: return "TODO"
        case .stuck: return "STUCK"
        case .waitingFor: return "WAITING"
        case .onHoldByClient: return "ON HOLD"
        case .needHelp: return "NEED HELP"
        case .canceled: return "CANCELED"
        }
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .p1: return .red
        case .p2: return .orange
        case .p3: return .blue
        }
    }
    
    var priorityLabel: String {
        switch task.priority {
        case .p1: return "HIGH"
        case .p2: return "MEDIUM"
        case .p3: return "LOW"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Checkbox + Task Name Column
            HStack(spacing: 12) {
                Button(action: onSelect) {
                    Circle()
                        .strokeBorder(isSelected ? Color.blue : Color.gray.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .fill(isSelected ? Color.blue : Color.clear)
                                .frame(width: 12, height: 12)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)
            .padding(.leading, 16)
            
            // Assignees Column (Avatar)
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                )
                .frame(width: 100)
            
            // Assigned Date Column
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text(task.startDate.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .frame(width: 110)
            
            // Due Date Column
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text(task.dueDate.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .frame(width: 110)
            
            // Priority Badge Column
            Text(priorityLabel)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(priorityColor)
                .cornerRadius(4)
                .frame(width: 90)
            
            // Status Badge Column
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.1))
            .cornerRadius(4)
            .frame(width: 100)
            
            // Actions Menu
            Menu {
                if task.status != .completed {
                    Button(action: onComplete) {
                        Label("Complete", systemImage: "checkmark")
                    }
                }
                
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(.gray)
                    .frame(width: 30)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Extensions

extension TaskStatus {
    static var allStatuses: [TaskStatus] {
        return [.onHoldByClient, .completed, .notStarted, .inProgress, .needHelp, .stuck, .waitingFor, .canceled]
    }
}
