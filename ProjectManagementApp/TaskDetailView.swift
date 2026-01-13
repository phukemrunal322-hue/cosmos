import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct TaskDetailModalView: View {
    @State var task: Task
    @Binding var isPresented: Bool
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    @State private var commentText: String = ""
    @State private var newSubtaskText: String = ""
    @State private var showingEditTitle = false
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    
    // For feedback
    @State private var showToast = false

    @State private var toastMessage = ""
    @State private var isShowingEditSheet = false
    
    // Activity Support
    @State private var activities: [ActivityItem] = []
    @State private var activityDisplayLimit: Int = 10
    @State private var taskDocumentId: String?
    @State private var activityListener: ListenerRegistration?
    
    var progress: Double {
        if let subtaskStr = task.subtask, !subtaskStr.isEmpty {
            let items = subtaskStr.components(separatedBy: "\n").filter { !$0.isEmpty }
            if items.isEmpty { return 0 }
            return 0
        }
        return 0
    }

    // MARK: - Timer State
    @State private var isTimerRunning = false
    @State private var timerStartTime: Date?
    @State private var timerElapsedTime: TimeInterval = 0
    @State private var timerCurrentTimeDisplay: String = "00:00:00"
    @State private var timerTotalTimeDisplay: String = "00:00:00"
    @State private var timer: Timer?
    @State private var timerId: String = "" // Unique ID for persistence
    @State private var showingHistorySheet = false
    @State private var lastSessionTime: TimeInterval = 0

    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding()
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Timer Section
                        VStack(spacing: 8) {
                            timerSection
                            
                            Button(action: {
                                showingHistorySheet = true
                            }) {
                                Text("History")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, 4)
                            }
                        }
                        .sheet(isPresented: $showingHistorySheet) {
                            if #available(iOS 16.0, *) {
                                VStack(spacing: 20) {
                                    Text("Timer History")
                                        .font(.headline)
                                    
                                    VStack(spacing: 16) {
                                        // Last Session
                                        VStack(spacing: 4) {
                                            Text("Last Session")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(formatTime(lastSessionTime))
                                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                        }
                                        
                                        Divider()
                                        
                                        // Total Logged
                                        VStack(spacing: 4) {
                                            Text("Total Logged Time")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(timerTotalTimeDisplay)
                                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                    
                                    Spacer()
                                }
                                .padding()
                                .presentationDetents([.fraction(0.4)])
                            } else {
                                VStack(spacing: 20) {
                                    Text("Timer History")
                                        .font(.headline)
                                    
                                    VStack(spacing: 16) {
                                        // Last Session
                                        VStack(spacing: 4) {
                                            Text("Last Session")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(formatTime(lastSessionTime))
                                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                        }
                                        
                                        Divider()
                                        
                                        // Total Logged
                                        VStack(spacing: 4) {
                                            Text("Total Logged Time")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(timerTotalTimeDisplay)
                                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                            }
                        }
                        
                        // Main Content
                        titleAndDescriptionSection
                        
                        // Metadata Grid (Status, Priority)
                        HStack(spacing: 16) {
                            statusSection
                                .frame(maxWidth: .infinity)
                            prioritySection
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Assignees & Dates
                        assigneeSection
                        datesSection
                        
                        // Subtasks & Activity
                        subtasksSection
                        timeEstimateSection
                        tagsSection
                        okrSection
                        activitySection
                    }
                    .padding(24)
                    .padding(.bottom, 40)
                }
            }
            
        }
        .onAppear {
            self.editedTitle = task.title
            self.editedDescription = task.description
            
            // Create a stable ID for persistence using project ID + Title
            // Fallback to title if project is nil (e.g. Self Task)
            let proId = task.project?.documentId ?? "self_task"
            // Sanitize title for key
            let safeTitle = task.title.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "task"
            self.timerId = "timer_\(proId)_\(safeTitle)"
            
            self.loadTimerState()
            fetchActivities()
        }
        .onDisappear {
            // If timer is running when closed, stop it to save the session history
            if isTimerRunning {
                stopTimer()
            }
            self.timer?.invalidate()
        }
    .sheet(isPresented: $isShowingEditSheet) {
        CreateTaskView(
            taskType: task.taskType == .selfTask ? .selfTask : .adminTask,
            projects: firebaseService.projects,
            initialData: NewTaskData(
                title: task.title,
                description: task.description,
                project: task.project,
                assignedDate: task.startDate,
                dueDate: task.dueDate,
                priority: task.priority,
                status: task.status,
                statusLabel: task.status.rawValue,
                taskType: task.taskType == .selfTask ? .selfTask : .adminTask,
                isRecurring: task.isRecurring,
                recurringPattern: task.recurringPattern,
                recurringDays: task.recurringDays,
                recurringEndDate: task.recurringEndDate,
                subtask: task.subtask,
                weightage: task.weightage,
                assignedTo: task.assignedTo
            )
        ) { newData in
            // Update Logic
            let updated = Task(
                title: newData.title,
                description: newData.description,
                status: newData.status,
                priority: newData.priority,
                startDate: newData.assignedDate,
                dueDate: newData.dueDate,
                assignedTo: newData.assignedTo ?? task.assignedTo,
                comments: task.comments,
                department: task.department,
                project: newData.project,
                taskType: task.taskType,
                isRecurring: newData.isRecurring,
                recurringPattern: newData.recurringPattern,
                recurringDays: newData.recurringDays,
                recurringEndDate: newData.recurringEndDate,
                subtask: newData.subtask,
                weightage: newData.weightage,
                subtaskStatus: task.subtaskStatus
            )
            
            self.task = updated // Local update
            
            firebaseService.updateTask(
                oldTitle: task.title,
                oldProjectId: task.project?.documentId,
                forUserUid: nil,
                userEmail: nil,
                with: updated,
                statusLabel: newData.statusLabel
            ) { _ in
                // Synced
            }
        }
    }
    }
    
    // MARK: - Sections
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.project?.name ?? "No Project")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("/")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                    Text(task.title)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                Text(task.title)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: { isShowingEditSheet = true }) {
                    Image(systemName: "pencil")
                }
                
                Button(action: {
                    firebaseService.archiveTask(task) { success in
                        if success { isPresented = false }
                    }
                }) {
                    Image(systemName: "archivebox")
                }
                
                Button(action: { 
                     firebaseService.deleteTask(task) { success in
                         if success { isPresented = false }
                     }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                
                Divider()
                    .frame(height: 20)
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .foregroundColor(.gray)
        }
    }
    
    @State private var descriptionUpdateWorkItem: DispatchWorkItem?

    private var titleAndDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DESCRIPTION")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            TextEditor(text: $editedDescription)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.clear, lineWidth: 1)
                )
                .onChange(of: editedDescription) { newValue in
                    // Debounce Logic
                    self.descriptionUpdateWorkItem?.cancel()
                    let item = DispatchWorkItem {
                         self.saveChanges()
                    }
                    self.descriptionUpdateWorkItem = item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
                }
        }
    }
    
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SUBTASKS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                // Simple placeholder progress
                Text("0/0 completed")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Subtasks List
            if let subtasks = task.subtask?.components(separatedBy: "\n").filter({ !$0.isEmpty }), !subtasks.isEmpty {
                ForEach(Array(subtasks.enumerated()), id: \.offset) { index, item in
                    let isCompleted = item.hasPrefix("[x] ")
                    let cleanItem = item.replacingOccurrences(of: "[x] ", with: "")
                    
                    HStack {
                        Button(action: { toggleSubtask(index, current: subtasks) }) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isCompleted ? .green : .gray)
                        }
                        
                        Text(cleanItem)
                            .strikethrough(isCompleted)
                            .foregroundColor(isCompleted ? .gray : .primary)
                        
                        Spacer()
                        
                        Button(action: { deleteSubtask(index, current: subtasks) }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.02), radius: 2)
                }
            } else {
                VStack(spacing: 12) {
                    Text("No subtasks yet")
                        .foregroundColor(.gray)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Add Subtask
            HStack {
                TextField("Add a subtask...", text: $newSubtaskText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                Button("Add") {
                    addSubtask()
                }
                .disabled(newSubtaskText.isEmpty)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2)
        }
    }
    
    private var okrSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("OBJECTIVES & KEY RESULTS", systemImage: "target")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue) // Using blue to match icon in image
            
            Text("No OKR linked to this task.")
                .italic()
                .foregroundColor(.gray.opacity(0.7))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("ACTIVITY")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            // Subcollection Activity List
            VStack(alignment: .leading, spacing: 0) { // Spacing 0 for timeline
                if activities.isEmpty {
                     if !task.comments.isEmpty {
                        // Legacy comments support - show all as it's legacy
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
                    
                    // Controls: Load More & Clear History
                    HStack {
                        if activities.count > activityDisplayLimit {
                            Button(action: { activityDisplayLimit += 10 }) {
                                Text("Load More")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        if !activities.isEmpty {
                            Button(action: {
                                if let docId = taskDocumentId {
                                    firebaseService.clearTaskActivities(taskId: docId) { success in
                                        if success {
                                            self.activities.removeAll()
                                            self.activityDisplayLimit = 10
                                        }
                                    }
                                }
                            }) {
                                Text("Clear History")
                                    .font(.caption)
                                    .foregroundColor(.red)
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
    }
    
    // Helper for Activity Icons
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
                
                // Timeline Line (omitted for last item logically, but simple hack: always show except... just consistent spacing)
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
                        .font(.callout) // Slightly larger for content
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, 24) // Spacing between rows
        }
    }
    
    // MARK: - Sidebar Sections
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATUS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            Menu {
                ForEach(TaskStatus.allStatuses, id: \.self) { status in
                    Button(action: { updateStatus(to: status) }) {
                        Label(statusLabel(status), systemImage: task.status == status ? "checkmark" : "circle")
                    }
                }
            } label: {
                HStack {
                    Text(statusLabel(task.status))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
        }
    }
    
    private func statusLabel(_ status: TaskStatus) -> String {
        switch status {
        case .notStarted: return "TODO"
        case .inProgress: return "In Progress"
        case .completed: return "Done"
        case .stuck: return "Stuck"
        case .waitingFor: return "Waiting For"
        case .onHoldByClient: return "Hold by Client"
        case .needHelp: return "Need Help"
        case .canceled: return "Canceled"
        }
    }
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRIORITY")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            Menu {
                Button("High") { updatePriority(.p1) }
                Button("Medium") { updatePriority(.p2) }
                Button("Low") { updatePriority(.p3) }
            } label: {
                HStack {
                    Text(priorityLabel(task.priority))
                        .foregroundColor(priorityColor(task.priority))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 1))
            }
        }
    }
    
    private var assigneeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASSIGNEES")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    let assignees = task.assignedTo.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && $0 != "Unassigned" }
                    
                    if assignees.isEmpty {
                        Text("Unassigned")
                            .italic()
                            .foregroundColor(.gray)
                    } else {
                        ForEach(assignees, id: \.self) { assignee in
                            let resolvedName = resolveAssigneeName(assignee)
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                    .overlay(Text(String(resolvedName.prefix(1))).fontWeight(.medium).foregroundColor(.blue))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resolvedName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text(task.status.rawValue) // Status applies to task, but shown per user in design
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(24) // Pill shape
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                    }
                    
                    Menu {
                        if !firebaseService.employees.isEmpty {
                            Section("Resources") {
                                ForEach(firebaseService.employees) { employee in
                                    Button(employee.name) {
                                        addAssignee(employee.name)
                                    }
                                }
                            }
                        }
                        
                        if !firebaseService.clients.isEmpty {
                            Section("Clients") {
                                ForEach(firebaseService.clients) { client in
                                    Button(client.name) {
                                        addAssignee(client.name)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.blue.opacity(0.3)) // Matching light style in image
                    }
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
    
    private func addAssignee(_ name: String) {
        var current = task.assignedTo.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "Unassigned" }
        
        if !current.contains(name) {
            current.append(name)
        }
        
        let newString = current.isEmpty ? "Unassigned" : current.joined(separator: ", ")
        updateAssignee(newString) // Reuse existing update call with new string
    }
    // Logic helper wrapper to match previous signature or just call updateAssignee directly
    // But `updateAssignee` itself needs to set the string.
    // I will use `updateAssignee` as the core setter.
    
    private var datesSection: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("START DATE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                HStack {
                    Image(systemName: "calendar")
                    Text(task.startDate.formatted(date: .numeric, time: .omitted))
                }
                .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("DUE DATE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                HStack {
                    Image(systemName: "calendar")
                    Text(task.dueDate.formatted(date: .numeric, time: .omitted))
                }
                .font(.subheadline)
            }
        }
    }
    
    @State private var tempTags: [String] = ["Design", "High Priority"] // Placeholder or mapped from Task
    @State private var isAddingTag = false
    @State private var newTagText = ""

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TAGS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                ForEach(tempTags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption)
                        Button(action: {
                            if let idx = tempTags.firstIndex(of: tag) {
                                tempTags.remove(at: idx)
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                
                if isAddingTag {
                    HStack(spacing: 8) {
                        HStack {
                            TextField("New tag", text: $newTagText, onCommit: {
                                if !newTagText.isEmpty {
                                    tempTags.append(newTagText)
                                    newTagText = ""
                                    isAddingTag = false
                                }
                            })
                            .submitLabel(.done)
                            .autocorrectionDisabled(true)
                            .font(.caption)
                            .frame(width: 80)
                            
                            Button(action: {
                                if newTagText.isEmpty {
                                    isAddingTag = false
                                } else {
                                    newTagText = ""
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue, lineWidth: 1))
                        
                        Button(action: {
                            if !newTagText.isEmpty {
                                tempTags.append(newTagText)
                                newTagText = ""
                                isAddingTag = false
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    Button(action: { isAddingTag = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("Add tag")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                    .foregroundColor(.gray)
                }
                }
            }
        }
    }
    
    @State private var isEditingTime = false
    @State private var timeEstimateValue: String = "Not set"
    @State private var customTimeInput: String = ""

    private var timeEstimateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TIME ESTIMATE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                if isEditingTime {
                    Button("Cancel") {
                        isEditingTime = false
                        customTimeInput = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if isEditingTime {
                VStack(alignment: .leading, spacing: 16) {
                    // Presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["2h", "4h", "1d", "2d", "1w"], id: \.self) { preset in
                                Button(action: {
                                    timeEstimateValue = preset
                                    isEditingTime = false
                                }) {
                                    Text(preset)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(20)
                                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Custom Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom (hours):")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            TextField("e.g., 12", text: $customTimeInput)
                                .keyboardType(.numberPad)
                                .onChange(of: customTimeInput) { newValue in
                                    customTimeInput = newValue.filter { "0123456789".contains($0) }
                                }
                                .padding(10)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            
                            Button(action: {
                                if !customTimeInput.isEmpty {
                                    timeEstimateValue = "\(customTimeInput)h"
                                    isEditingTime = false
                                    customTimeInput = ""
                                }
                            }) {
                                Text("Set")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Clear Estimate
                    Button(action: {
                        timeEstimateValue = "Not set"
                        isEditingTime = false
                    }) {
                        Text("Clear Estimate")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)
            } else {
                HStack {
                    HStack {
                        Image(systemName: "clock")
                        Text(timeEstimateValue)
                            .font(.subheadline)
                    }
                    .foregroundColor(timeEstimateValue == "Not set" ? .gray : .primary)
                    
                    Spacer()
                    
                    if timeEstimateValue != "Not set" {
                        Button("Edit") {
                            isEditingTime = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    } else {
                        // If not set, the whole row is tappable to add
                        Button("Set") {
                            isEditingTime = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .opacity(0) // invisible hit area or just let the user tap the row?
                        // Actually, if "Not set", let's make the whole thing tappable implicitly or show "Add"
                    }
                }
                .contentShape(Rectangle()) // Make full row tappable
                .onTapGesture {
                    isEditingTime = true
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    private func updateStatus(to status: TaskStatus) {
        // Update in Firebase
        firebaseService.updateTaskStatus(
            title: task.title,
            projectId: task.project?.documentId,
            forUserUid: nil,
            userEmail: nil,
            to: status
        ) { _ in
            // Firebase updated
        }
        
        // Update local UI immediately for responsiveness
        let updated = Task(
            title: task.title,
            description: task.description,
            status: status,
            priority: task.priority,
            startDate: task.startDate,
            dueDate: task.dueDate,
            assignedTo: task.assignedTo,
            comments: task.comments,
            department: task.department,
            project: task.project,
            taskType: task.taskType,
            isRecurring: task.isRecurring,
            recurringPattern: task.recurringPattern,
            recurringDays: task.recurringDays,
            recurringEndDate: task.recurringEndDate,
            subtask: task.subtask,
            weightage: task.weightage,
            subtaskStatus: task.subtaskStatus
        )
        self.task = updated
    }
    
    private func updatePriority(_ p: Priority) {
        // Create updated task with new priority
        let updated = Task(
            title: task.title,
            description: task.description,
            status: task.status,
            priority: p,
            startDate: task.startDate,
            dueDate: task.dueDate,
            assignedTo: task.assignedTo,
            comments: task.comments,
            department: task.department,
            project: task.project,
            taskType: task.taskType,
            isRecurring: task.isRecurring,
            recurringPattern: task.recurringPattern,
            recurringDays: task.recurringDays,
            recurringEndDate: task.recurringEndDate,
            subtask: task.subtask,
            weightage: task.weightage,
            subtaskStatus: task.subtaskStatus
        )
        
        // Update in Firebase
        firebaseService.updateTask(
            oldTitle: task.title,
            oldProjectId: task.project?.documentId,
            forUserUid: nil,
            userEmail: nil,
            with: updated,
            statusLabel: statusLabel(task.status)
        ) { _ in
            // Firebase updated
        }
        
        // Update local UI immediately
        self.task = updated
    }
    
    private func saveChanges() {
        // Save description edits
        let updated = Task(
            title: task.title,
            description: editedDescription,
            status: task.status,
            priority: task.priority,
            startDate: task.startDate,
            dueDate: task.dueDate,
            assignedTo: task.assignedTo,
            comments: task.comments,
            department: task.department,
            project: task.project,
            taskType: task.taskType,
            isRecurring: task.isRecurring,
            recurringPattern: task.recurringPattern,
            recurringDays: task.recurringDays,
            recurringEndDate: task.recurringEndDate,
            subtask: task.subtask,
            weightage: task.weightage,
            subtaskStatus: task.subtaskStatus
        )
        
        firebaseService.updateTask(
            oldTitle: task.title,
            oldProjectId: task.project?.documentId,
            forUserUid: nil,
            userEmail: nil,
            with: updated,
            statusLabel: task.status.rawValue
        ) { _ in
            self.task = updated // Sync local
        }
    }
    
    private func addSubtask() {
        guard !newSubtaskText.isEmpty else { return }
        let current = task.subtask ?? ""
        let newItems = current.isEmpty ? newSubtaskText : current + "\n" + newSubtaskText
        
        let updated = Task(
            title: task.title,
            description: task.description,
            status: task.status,
            priority: task.priority,
            startDate: task.startDate,
            dueDate: task.dueDate,
            assignedTo: task.assignedTo,
            comments: task.comments,
            department: task.department,
            project: task.project,
            taskType: task.taskType,
            isRecurring: task.isRecurring,
            recurringPattern: task.recurringPattern,
            recurringDays: task.recurringDays,
            recurringEndDate: task.recurringEndDate,
            subtask: newItems, // Update
            weightage: task.weightage,
            subtaskStatus: task.subtaskStatus
        )
        
        firebaseService.updateTask(
            oldTitle: task.title,
            oldProjectId: task.project?.documentId,
            forUserUid: nil,
            userEmail: nil,
            with: updated,
            statusLabel: task.status.rawValue
        ) { _ in
            self.task = updated
            self.newSubtaskText = ""
        }
    }
    
    private func toggleSubtask(_ index: Int, current: [String]) {
        var items = current
        let item = items[index]
        if item.hasPrefix("[x] ") {
            items[index] = item.replacingOccurrences(of: "[x] ", with: "")
        } else {
            items[index] = "[x] " + item
        }
        updateSubtasks(items)
    }
    
    private func deleteSubtask(_ index: Int, current: [String]) {
        var items = current
        items.remove(at: index)
        updateSubtasks(items)
    }
    
    private func updateSubtasks(_ items: [String]) {
        let newSubtaskString = items.joined(separator: "\n")
        
        let updated = Task(
             title: task.title,
             description: task.description,
             status: task.status,
             priority: task.priority,
             startDate: task.startDate,
             dueDate: task.dueDate,
             assignedTo: task.assignedTo,
             comments: task.comments,
             department: task.department,
             project: task.project,
             taskType: task.taskType,
             isRecurring: task.isRecurring,
             recurringPattern: task.recurringPattern,
             recurringDays: task.recurringDays,
             recurringEndDate: task.recurringEndDate,
             subtask: newSubtaskString,
             weightage: task.weightage,
             subtaskStatus: task.subtaskStatus
         )
         
         firebaseService.updateTask(
             oldTitle: task.title,
             oldProjectId: task.project?.documentId,
             forUserUid: nil,
             userEmail: nil,
             with: updated,
             statusLabel: task.status.rawValue
         ) { _ in
             self.task = updated // Local update
         }
    }

    private func addComment() {
        guard !commentText.isEmpty else { return }
        
        let message = commentText
        self.commentText = "" // Clear input immediately
        
        let user = "Super Admin" // Default to Super Admin for now
        // Actually the screenshot has "Super Admin".
        // I'll use "Super Admin" to match the user's current testing context or "System".
        // The user said "mens db madhe je add ahe msg te fetch pn vayla pahjle", implying integration with existing data.
        
        // If we have a docId, use the new text-based activity system
        if let docId = taskDocumentId {
            let activity = ActivityItem(user: "Super Admin", action: "commented", message: message, type: "comment")
            firebaseService.addTaskActivity(taskId: docId, activity: activity) { error in
                if let error = error {
                    print("Error adding activity: \(error)")
                }
            }
        } else {
            // Fallback to legacy array if docId missing
            firebaseService.addCommentToTask(
                taskTitle: task.title,
                taskProjectId: task.project?.documentId,
                message: message,
                user: "Super Admin"
            ) { _ in }
        }
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
    
    private func updateAssignee(_ newAssignee: String) {
        let updated = Task(
            title: task.title,
            description: task.description,
            status: task.status,
            priority: task.priority,
            startDate: task.startDate,
            dueDate: task.dueDate,
            assignedTo: newAssignee,
            comments: task.comments,
            department: task.department,
            project: task.project,
            taskType: task.taskType,
            isRecurring: task.isRecurring,
            recurringPattern: task.recurringPattern,
            recurringDays: task.recurringDays,
            recurringEndDate: task.recurringEndDate,
            subtask: task.subtask,
            weightage: task.weightage,
            subtaskStatus: task.subtaskStatus
        )
        
        firebaseService.updateTask(
            oldTitle: task.title,
            oldProjectId: task.project?.documentId,
            forUserUid: nil,
            userEmail: nil,
            with: updated,
            statusLabel: task.status.rawValue
        ) { _ in
            self.task = updated
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
        case .p3: return .blue
        }
    }
    // MARK: - Timer Section
    
    private var timerSection: some View {
        HStack(spacing: 16) {
            // Play/Stop Icon Button
            Button(action: {
                if isTimerRunning {
                    stopTimer()
                } else {
                    startTimer()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isTimerRunning ? "square.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isTimerRunning ? .red : .blue)
                        .offset(x: isTimerRunning ? 0 : 2) // Optical centering for play icon
                }
            }
            
            // Time Display Stack
            // Time Display Stack
            VStack(alignment: .leading, spacing: 2) {
                Text(timerTotalTimeDisplay)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text("Total Logged: \(timerTotalTimeDisplay)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Action Text Button
            Button(action: {
                if isTimerRunning {
                    stopTimer()
                } else {
                    startTimer()
                }
            }) {
                Text(isTimerRunning ? "Stop Timer" : "Start Timer")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        // Remove shadow if looking for a flat card style, or keep it subtle
        .padding(.horizontal, 1) // Tiny inset
    }
    
    // MARK: - Timer Logic
    
    private func loadTimerState() {
        // Init with whatever we have locally first to show something
        if let logged = task.totalTimeLogged {
            self.timerElapsedTime = logged
        } else {
            self.timerElapsedTime = UserDefaults.standard.double(forKey: "timer_elapsed_\(timerId)")
        }
        self.timerTotalTimeDisplay = formatTime(self.timerElapsedTime)
        
        let defaults = UserDefaults.standard
        let isActive = defaults.bool(forKey: "timer_isActive_\(timerId)")
        let savedStartTime = defaults.object(forKey: "timer_startTime_\(timerId)") as? Date
        
        // Load Last Session
        self.lastSessionTime = defaults.double(forKey: "timer_lastSession_\(timerId)")
        
        if isActive, let startTime = savedStartTime {
            self.timerStartTime = startTime
            self.isTimerRunning = true
            startUITimer()
        } else {
            self.isTimerRunning = false
            self.timerCurrentTimeDisplay = "00:00:00"
        }
        
        // Asynchronously fetch fresh persistence data
        let userUid = Auth.auth().currentUser?.uid
        let userEmail = Auth.auth().currentUser?.email
        FirebaseService.shared.fetchTaskTotalTime(
            taskType: task.taskType,
            title: task.title,
            projectId: task.project?.documentId,
            forUserUid: userUid,
            userEmail: userEmail
        ) { fetchedTime in
            if let t = fetchedTime {
                // Determine if we should override local state
                // If timer is running, we might be ahead of DB, but usually DB is the base.
                // If timer is running, `timerElapsedTime` currently holds "base from local/task"
                // Ideally `timerElapsedTime` should be the base from DB.
                // But we must be careful not to overwrite if user just stopped it and DB isn't updated?
                // No, loadTimerState only runs on appear.
                
                self.timerElapsedTime = t
                self.task.totalTimeLogged = t // Update local task copy
                
                // If timer is NOT running, just update display
                if !self.isTimerRunning {
                    self.timerTotalTimeDisplay = self.formatTime(t)
                } else {
                    // If timer IS running, updateTimerDisplay loop handles adding current session to `timerElapsedTime`
                    // So updating `timerElapsedTime` here is correct, the next tick will add session to this new base.
                    // Force an update immediately
                    self.updateTimerDisplay()
                }
            }
        }
    }
    
    private func saveTimerState() {
        let defaults = UserDefaults.standard
        defaults.set(isTimerRunning, forKey: "timer_isActive_\(timerId)")
        defaults.set(timerStartTime, forKey: "timer_startTime_\(timerId)")
        defaults.set(timerElapsedTime, forKey: "timer_elapsed_\(timerId)")
    }
    
    private func startTimer() {
        guard !isTimerRunning else { return }
        
        self.timerStartTime = Date()
        self.isTimerRunning = true
        saveTimerState()
        startUITimer()
    }
    
    private func stopTimer() {
        guard isTimerRunning, let startTime = timerStartTime else { return }
        
        let sessionTime = Date().timeIntervalSince(startTime)
        self.timerElapsedTime += sessionTime
        self.lastSessionTime = sessionTime // Update last session
        self.timerTotalTimeDisplay = formatTime(timerElapsedTime)
        
        self.timerStartTime = nil
        self.isTimerRunning = false
        self.timer?.invalidate()
        self.timerCurrentTimeDisplay = "00:00:00"
        
        // Update local task state immediately
        self.task.totalTimeLogged = self.timerElapsedTime
        
        saveTimerState()
        
        // Save Last Session to Defaults
        UserDefaults.standard.set(sessionTime, forKey: "timer_lastSession_\(timerId)")
        
        let userUid = Auth.auth().currentUser?.uid
        let userEmail = Auth.auth().currentUser?.email
        FirebaseService.shared.updateTaskTotalTime(
            taskType: task.taskType,
            title: task.title,
            projectId: task.project?.documentId,
            forUserUid: userUid,
            userEmail: userEmail,
            newTotalTime: self.timerElapsedTime
        ) { _ in
            print("Timer saved to Firestore")
        }
    }
    
    private func startUITimer() {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimerDisplay()
        }
        updateTimerDisplay()
    }
    
    private func updateTimerDisplay() {
        guard let startTime = timerStartTime else { return }
        let currentSessionTime = Date().timeIntervalSince(startTime)
        self.timerCurrentTimeDisplay = formatTime(currentSessionTime)
        self.timerTotalTimeDisplay = formatTime(timerElapsedTime + currentSessionTime)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
             return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
             return String(format: "00:%02d:%02d", minutes, seconds)
        }
    }
}

// Helper for simple flow layout
struct FlexLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
             // Use a real Layout on iOS 16 if possible, but for now simple ScrollView Horizontal 
             // actually  logic above is complex to append via cat.
             // I will use ScrollView(.horizontal) in the code via edit instead of appending complex struct.
             EmptyView()
        } else {
             EmptyView()
        }
    }
}
