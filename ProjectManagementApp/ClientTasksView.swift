import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct ClientTasksView: View {
    @State private var selectedStatus: TaskStatus? = nil
    @State private var selectedStatusLabel: String = "All"
    @State private var showDoneOnly: Bool = false
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var authService = FirebaseAuthService.shared
    @State private var tasks: [Task] = []
    
    var filteredTasks: [Task] {
        var filtered = tasks
        if showDoneOnly {
            filtered = filtered.filter { $0.status == .completed }
        } else {
            filtered = filtered.filter { $0.status != .completed }
            if let status = selectedStatus {
                filtered = filtered.filter { $0.status == status }
            } else if selectedStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "all" {
                let wanted = selectedStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if wanted == "today's task" || wanted == "todays task" || wanted == "today" {
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
                } else {
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
        }
        return filtered
    }
    
    private var statusFilterMenu: some View {
        Menu {
            ForEach(firebaseService.taskStatusOptions, id: \.self) { label in
                Button(label) {
                    if label == "All" {
                        selectedStatus = nil
                        selectedStatusLabel = "All"
                    } else if label == "Today's Task" {
                        selectedStatus = nil
                        selectedStatusLabel = label
                    } else {
                        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let mapped: TaskStatus?
                        switch normalized {
                        case "todo", "to do", "to-do": mapped = .notStarted
                        case "in progress", "in-progress", "inprogress": mapped = .inProgress
                        case "stuck": mapped = .stuck
                        case "waiting for", "waiting for client", "waiting": mapped = .waitingFor
                        case "hold by client", "on hold by client", "hold", "hold client": mapped = .onHoldByClient
                        case "need help": mapped = .needHelp
                        case "done", "completed", "complete": mapped = .completed
                        case "canceled", "cancelled": mapped = .canceled
                        default: mapped = TaskStatus(rawValue: label)
                        }
                        selectedStatus = mapped
                        selectedStatusLabel = label
                    }
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
    
    private var eyeToggle: some View {
        Button(action: {
            withAnimation(.easeInOut) { showDoneOnly.toggle() }
        }) {
            HStack(spacing: 6) {
                Text(showDoneOnly ? "View" : "Hide")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Image(systemName: showDoneOnly ? "eye.fill" : "eye.slash.fill")
                    .font(.subheadline)
                    .foregroundColor(showDoneOnly ? .blue : .gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var topFilterBar: some View {
        HStack {
            eyeToggle
            statusFilterMenu
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.background)
        .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)
    }

    private var emptyStateTitle: String {
        if showDoneOnly {
            return "No Done Tasks"
        }
        if let status = selectedStatus {
            return "No \(status.rawValue) Tasks"
        }
        let trimmed = selectedStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let wanted = trimmed.lowercased()
        if wanted == "today's task" || wanted == "todays task" || wanted == "today" {
            return "No Tasks Due Today"
        }
        if !trimmed.isEmpty && wanted != "all" {
            return "No \(trimmed) Tasks"
        }
        return "No Tasks Found"
    }

    private var emptyStateSubtitle: String {
        if showDoneOnly {
            return "There are no tasks marked as Done."
        }
        if let status = selectedStatus {
            return "There are no tasks marked as \(status.rawValue)."
        }
        let trimmed = selectedStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let wanted = trimmed.lowercased()
        if wanted == "today's task" || wanted == "todays task" || wanted == "today" {
            return "There are no tasks due today with the selected filters."
        }
        if !trimmed.isEmpty && wanted != "all" {
            return "There are no tasks marked as \(trimmed)."
        }
        return "Try changing your filters."
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
                        ClientTaskCard(task: task)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topFilterBar
            tasksList
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle("My Tasks")
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email)
            firebaseService.listenTaskStatusOptions()
        }
        .onReceive(firebaseService.$tasks) { newTasks in
            // Use tasks already filtered by current user's uid/email
            self.tasks = newTasks
        }
    }
}

struct ClientTaskCard: View {
    let task: Task
    @State private var progressInput: String = "0"
    @State private var selectedStatus: TaskStatus
    @State private var selectedStatusText: String = ""
    @State private var isExpanded: Bool = false
    @State private var showingDetail: Bool = false
    @State private var showCompletionSheet: Bool = false
    @State private var completionComment: String = ""
    @State private var showingUploadDocuments = false
    @State private var isHoveringUpload = false
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
        // Prefer exact label from Firestore settings when it normalizes the same
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
    }
    
    var shortTitle: String {
        let s = task.title
        return s.count > 25
        ? String(s.prefix(6)) + "..." : s
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
        return task.dueDate < Date() && selectedStatus != .completed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Always Visible: Title, Status, Priority, Dates
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    // Title and Description
                    Button(action: {
                        showingDetail = true
                    }) {
                        Text(shortTitle)
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
                        
                        // Task Type Badge (for client-assigned tasks)
                        if task.taskType == .clientAssigned {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.shield.checkmark.fill")
                                    .font(.system(size: 10))
                                Text("Admin Assigned")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                        }
                        
                        if isOverdue {
                            Text("Overdue")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Dates Row
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                            Text("Due: \(task.dueDate.formatted(date: .numeric, time: .omitted))")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 11))
                                .foregroundColor(.purple)
                            Text("Assigned: \(task.startDate.formatted(date: .numeric, time: .omitted))")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Upload Documents Button (Small)
                    if false {
                        Button(action: { showingUploadDocuments = true }) { EmptyView() }
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
            
            // Expandable Section: Progress, Input, Buttons
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Progress Bar
                        HStack(alignment: .center, spacing: 6) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 6)
                                        .cornerRadius(4)
                                    Rectangle()
                                        .fill(statusColor)
                                        .frame(width: geometry.size.width * (Double(progressInput) ?? 0) / 100, height: 6)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(width: 320, height: 6)
                            Text("\(progressInput)%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                                .fixedSize()
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        
                        // Input and Buttons Row
                        HStack(spacing: 6) {
                            TextField("0", text: $progressInput)
                                .keyboardType(.numberPad)
                                .font(.system(size: 13))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(width: 60)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            
                            HStack(spacing: 4) {
                                Button(action: {
                                    let uid = authService.currentUid
                                    let email = authService.currentUser?.email
                                    let pid = task.project?.documentId
                                    let val = Int(progressInput) ?? 0
                                    firebaseService.updateTaskProgress(
                                        title: task.title,
                                        projectId: pid,
                                        forUserUid: uid,
                                        userEmail: email,
                                        to: val,
                                        completion: nil
                                    )
                                }) {
                                    Text("Update")
                                        .lineLimit(1)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                                
                                // Status Dropdown (TODO / In Progress / Stuck / Waiting For / Hold by Client / Need Help)
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
                                            case "in progress", "in-progress", "inprogress":
                                                mapped = .inProgress
                                            case "stuck":
                                                mapped = .stuck
                                            case "waiting for", "waiting for client", "waiting":
                                                mapped = .waitingFor
                                            case "hold by client", "on hold by client", "hold", "hold client":
                                                mapped = .onHoldByClient
                                            case "need help":
                                                mapped = .needHelp
                                            case "done", "completed", "complete":
                                                mapped = .completed
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
                                                firebaseService.updateTaskStatusLabel(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, toLabel: label, completion: nil)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(selectedStatusText)
                                            .lineLimit(1)
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
                                        .lineLimit(1)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }.background(.background)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.15), radius: 4, x: 0, y: 2)
        .overlay(alignment: .topTrailing) {
                    HStack(spacing: 6) {
                        if isHoveringUpload {
                            Text("Upload Documents")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        Button(action: {
                            showingUploadDocuments = true
                        }) {
                            Image(systemName: "tray.and.arrow.up.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle().fill(Color.blue.opacity(0.15))
                                )
                        }
                        .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                            isHoveringUpload = pressing
                        }, perform: {})
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
                .sheet(isPresented: $showingUploadDocuments) {
                    UploadDocumentsView(taskName: task.title)
                }
                .onChange(of: selectedStatus) { newValue in
                    let uid = authService.currentUid
                    let email = authService.currentUser?.email
                    let pid = task.project?.documentId
                    firebaseService.updateTaskStatus(title: task.title, projectId: pid, forUserUid: uid, userEmail: email, to: newValue, completion: nil)
                }
        }
        
        // Note: FilterChip, TaskDetailView, and CompletionCommentSheet are defined in TasksView.swift
        // and are shared across the app
}

struct UploadDocumentsView: View {
    @Environment(\.dismiss) var dismiss
    let taskName: String
    @State private var documentTitle: String = ""
    @State private var documentDescription: String = ""
    @State private var showingFilePicker = false
    @State private var selectedFiles: [String] = []

    // Break up complex type-checking expression
    private var allowedContentTypes: [UTType] {
        let docType = UTType(filenameExtension: "doc") ?? .data
        let docxType = UTType(filenameExtension: "docx") ?? .data
        let xlsType = UTType(filenameExtension: "xls") ?? .data
        let xlsxType = UTType(filenameExtension: "xlsx") ?? .data
        let pptType = UTType(filenameExtension: "ppt") ?? .data
        let pptxType = UTType(filenameExtension: "pptx") ?? .data

        return [
            .pdf,
            .png,
            .jpeg,
            .heic,
            .text,
            .plainText,
            .rtf,
            .spreadsheet,
            .presentation,
            .zip,
            .data,
            docType,
            docxType,
            xlsType,
            xlsxType,
            pptType,
            pptxType
        ]
    }

    private var documentTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Type")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)

            Text(taskName)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private var documentTitleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)

            TextField("Enter document title", text: $documentTitle)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description (Optional)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)

            TextEditor(text: $documentDescription)
                .frame(height: 100)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private var fileUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Files")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)

            Button(action: {
                showingFilePicker = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Add Files")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            if !selectedFiles.isEmpty {
                selectedFilesList
            }
        }
    }

    private var selectedFilesList: some View {
        VStack(spacing: 8) {
            ForEach(selectedFiles, id: \.self) { file in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.blue)
                    Text(file)
                        .font(.system(size: 14))
                    Spacer()
                    Button(action: {
                        selectedFiles.removeAll { $0 == file }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    documentTypeSection
                    documentTitleSection
                    descriptionSection
                    fileUploadSection
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Upload Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Upload") {
                        // Handle upload action
                        dismiss()
                    }
                    .disabled(documentTitle.isEmpty || selectedFiles.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: allowedContentTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        let fileName = url.lastPathComponent
                        if !selectedFiles.contains(fileName) {
                            selectedFiles.append(fileName)
                        }
                    }
                case .failure(let error):
                    print("Error selecting files: \(error.localizedDescription)")
                }
            }
        }
    }
}
