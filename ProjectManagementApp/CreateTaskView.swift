import SwiftUI
import Combine
import Speech
import AVFoundation

// MARK: - Speech Recognizer Helper
class SpeechRecognizerHelper: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    @Published var isRecording = false
    
    func toggle(onText: @escaping (String) -> Void) {
        if isRecording {
            stop()
        } else {
            start(onText: onText)
        }
    }
    
    private func start(onText: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                #if os(iOS)
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else { return }
                        self.beginRecognition(onText: onText)
                    }
                }
                #else
                self.beginRecognition(onText: onText)
                #endif
            }
        }
    }
    
    private func beginRecognition(onText: @escaping (String) -> Void) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        recognitionTask?.cancel()
        
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        request = recognitionRequest
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        
        isRecording = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    onText(result.bestTranscription.formattedString)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stop()
            }
        }
    }
    
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
    }
}

// MARK: - New Dynamic Create Task View
struct CreateTaskView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var speechHelper = SpeechRecognizerHelper()
    
    let taskType: TaskType
    let projects: [Project]
    let onSave: (NewTaskData) -> Void
    let isEditing: Bool
    
    // MARK: - Form Fields
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedProject: Project?
    @State private var selectedPriority: Priority = .p2
    @State private var selectedStatus: TaskStatus = .notStarted
    @State private var selectedStatusText: String = "TODO"
    
    // Assignment
    @State private var assignType: AssignType = .resource
    @State private var searchQuery: String = ""
    @State private var selectedAssigneeName: String = "Admin" // Default
    @State private var assignedDate: Date = Date()
    @State private var dueDate: Date = Date()
    
    // Advanced & Subtasks
    @State private var weightage: String = ""
    @State private var isRecurring: Bool = false
    @State private var recurringPattern: RecurringPattern = .weekly
    @State private var subtaskInput: String = ""
    @State private var subtasks: [SelectableSubtask] = []
    
    // Temp Subtask State
    @State private var tempSubtaskDate: Date? = nil
    @State private var tempSubtaskAssignee: String = ""
    @State private var tempSubtaskPriority: Priority = .p2
    
    // Speech State
    @State private var activeSpeechField: SpeechField?
    
    enum TaskType { case selfTask, adminTask }
    enum SpeechField { case title, description, subtask }
    enum AssignType: String, CaseIterable {
        case resource = "Resource"
        case client = "Client"
    }

    struct SubtaskMetadata {
        var dueDate: Date?
        var assignee: String?
        var priority: Priority = .p2
    }

    struct SelectableSubtask: Identifiable {
        let id = UUID()
        var text: String
        var isSelected: Bool
        var metadata: SubtaskMetadata?
    }

    init(
        taskType: TaskType,
        projects: [Project],
        prefilledAssignedDate: Date? = nil,
        prefilledDueDate: Date? = nil,
        initialData: NewTaskData? = nil,
        onSave: @escaping (NewTaskData) -> Void
    ) {
        self.taskType = taskType
        self.projects = projects
        self.onSave = onSave
        self.isEditing = initialData != nil
        
        if let data = initialData {
            _title = State(initialValue: data.title)
            _description = State(initialValue: data.description)
            _selectedProject = State(initialValue: data.project)
            _selectedPriority = State(initialValue: data.priority)
            _selectedStatus = State(initialValue: data.status)
            _selectedStatusText = State(initialValue: data.statusLabel)
            _assignedDate = State(initialValue: data.assignedDate)
            _dueDate = State(initialValue: data.dueDate)
            _weightage = State(initialValue: data.weightage ?? "")
            _isRecurring = State(initialValue: data.isRecurring)
            _recurringPattern = State(initialValue: data.recurringPattern ?? .weekly)
            
            // Handle subtasks: split string and make them selected by default
            if let st = data.subtask, !st.isEmpty {
                let items = st.components(separatedBy: "\n").map { SelectableSubtask(text: $0, isSelected: true) }
                _subtasks = State(initialValue: items)
            }
        } else {
            _assignedDate = State(initialValue: prefilledAssignedDate ?? Date())
            _dueDate = State(initialValue: prefilledDueDate ?? Date())
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Details & Classification
                    dataSection(title: "DETAILS & CLASSIFICATION") {
                        VStack(spacing: 16) {
                            // Title
                            customTextField(
                                title: "Task Title",
                                placeholder: "Enter task title...",
                                text: $title,
                                isSpeechEnabled: true,
                                speechField: .title
                            )
                            
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $description)
                                        .frame(height: 100)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    
                                    speechButton(for: .description)
                                        .padding(8)
                                }
                            }
                            
                            // Project
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Project")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Menu {
                                    ForEach(projects) { project in
                                        Button(project.name) { selectedProject = project }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedProject?.name ?? "Select Project")
                                            .foregroundColor(selectedProject == nil ? .gray : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            
                            // Priority & Status Row
                            HStack(spacing: 12) {
                                // Priority
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Priority")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    HStack {
                                        Picker("Priority", selection: $selectedPriority) {
                                            Text("High").tag(Priority.p1)
                                            Text("Medium").tag(Priority.p2)
                                            Text("Low").tag(Priority.p3)
                                        }
                                        .pickerStyle(.menu)
                                        .accentColor(.primary)
                                        
                                        Spacer()
                                        
                                        // Invisible image just to ensure height consistency if needed, 
                                        // or rely on Picker's native chevron. 
                                        // Native Picker .menu style shows selected value. 
                                        // We just wrap it to look like the input fields.
                                    }
                                    .padding(.vertical, 4) // adjust padding to match others
                                    .padding(.horizontal, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                
                                // Status
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Status")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Menu {
                                        ForEach(firebaseService.taskStatusOptions, id: \.self) { option in
                                            Button(option) {
                                                selectedStatusText = option
                                                selectedStatus = mapStatus(option)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(selectedStatusText)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "chevron.down").font(.caption)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 2. Assignment & Schedule
                    dataSection(title: "ASSIGNMENT & SCHEDULE") {
                        VStack(spacing: 16) {
                            // Resource / Client Toggle
                            Picker("Type", selection: $assignType) {
                                ForEach(AssignType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.bottom, 8)
                            
                            // Searchable List
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Search resources...", text: $searchQuery)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 8) {
                                        if assignType == .resource {
                                            ForEach(filteredEmployees) { emp in
                                                AssigneeRow(name: emp.name, isSelected: selectedAssigneeName == emp.name) {
                                                    if selectedAssigneeName == emp.name {
                                                        selectedAssigneeName = "" // Untick
                                                    } else {
                                                        selectedAssigneeName = emp.name
                                                    }
                                                }
                                            }
                                        } else {
                                            ForEach(filteredClients) { client in
                                                AssigneeRow(name: client.name, isSelected: selectedAssigneeName == client.name) {
                                                    if selectedAssigneeName == client.name {
                                                        selectedAssigneeName = "" // Untick
                                                    } else {
                                                        selectedAssigneeName = client.name
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .frame(height: 150)
                                .background(Color(.systemGray6).opacity(0.3))
                                .cornerRadius(8)
                            }
                            
                            // Dates Row
                            HStack(spacing: 12) {
                                dateField(title: "Assigned Date", date: $assignedDate)
                                dateField(title: "Due Date", date: $dueDate)
                            }
                        }
                    }
                    
                    // 3. Advanced & Subtasks
                    dataSection(title: "ADVANCED & SUBTASKS") {
                        VStack(spacing: 16) {
                            // Weightage
                            customTextField(
                                title: "Weightage (Points)",
                                placeholder: "e.g. 5",
                                text: $weightage,
                                isSpeechEnabled: false,
                                speechField: nil
                            )
                            
                            // Recurring
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.gray)
                                Text("Recurring")
                                    .fontWeight(.medium)
                                Spacer()
                                Toggle("", isOn: $isRecurring)
                                    .labelsHidden()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            // Subtasks
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("SUBTASKS").font(.caption).foregroundColor(.gray)
                                    Spacer()
                                    Text("\(subtasks.count) items").font(.caption).foregroundColor(.gray)
                                }
                                
                                // Subtask Input Area
                                VStack(spacing: 12) {
                                    HStack {
                                        TextField("New subtask...", text: $subtaskInput)
                                            .padding(10)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        
                                        Button("Add") {
                                            if !subtaskInput.isEmpty {
                                                let meta = SubtaskMetadata(
                                                    dueDate: tempSubtaskDate,
                                                    assignee: tempSubtaskAssignee.isEmpty ? nil : tempSubtaskAssignee,
                                                    priority: tempSubtaskPriority
                                                )
                                                
                                                subtasks.append(SelectableSubtask(text: subtaskInput, isSelected: true, metadata: meta))
                                                subtaskInput = ""
                                                // Reset temp fields
                                                tempSubtaskDate = nil
                                                tempSubtaskAssignee = ""
                                                tempSubtaskPriority = .p2
                                            }
                                        }
                                        .disabled(subtaskInput.isEmpty)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(subtaskInput.isEmpty ? Color.gray.opacity(0.3) : Color.black)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    
                                    // Subtask Metadata Controls
                                    HStack(spacing: 12) {
                                        // 1. Due Date
                                        ZStack {
                                            HStack {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(tempSubtaskDate == nil ? .gray : .blue)
                                                if let date = tempSubtaskDate {
                                                    Text(date, style: .date)
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                } else {
                                                    Text("Due Date")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            
                                            // Invisible DatePicker overlay that captures taps
                                            DatePicker("", selection: Binding(
                                                get: { tempSubtaskDate ?? Date() },
                                                set: { tempSubtaskDate = $0 }
                                            ), displayedComponents: .date)
                                            .labelsHidden()
                                            .datePickerStyle(.compact)
                                            .colorMultiply(.clear) // Makes it invisible but keeps interaction
                                            .background(Color.white.opacity(0.001)) // Ensure hit testing works
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .clipped()
                                        }
                                        
                                        // 2. Assignee (User Picker)
                                        Menu {
                                            ForEach(firebaseService.employees) { emp in
                                                Button(emp.name) {
                                                    tempSubtaskAssignee = emp.name
                                                }
                                            }
                                            Button("Clear") { tempSubtaskAssignee = "" }
                                        } label: {
                                            HStack {
                                                Image(systemName: "person")
                                                    .foregroundColor(tempSubtaskAssignee.isEmpty ? .gray : .blue)
                                                Text(tempSubtaskAssignee.isEmpty ? "Assignee" : tempSubtaskAssignee)
                                                    .font(.caption)
                                                    .foregroundColor(tempSubtaskAssignee.isEmpty ? .gray : .blue)
                                                    .lineLimit(1)
                                            }
                                            .padding(8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        }
                                        
                                        // 3. Priority
                                        Menu {
                                            Button("High") { tempSubtaskPriority = .p1 }
                                            Button("Medium") { tempSubtaskPriority = .p2 }
                                            Button("Low") { tempSubtaskPriority = .p3 }
                                        } label: {
                                            HStack {
                                                Image(systemName: "flag")
                                                    .foregroundColor(priorityColor(tempSubtaskPriority))
                                                Text(priorityLabel(tempSubtaskPriority))
                                                    .font(.caption)
                                                    .foregroundColor(priorityColor(tempSubtaskPriority))
                                            }
                                            .padding(8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.03), radius: 2)

                                // Subtasks List
                                ForEach($subtasks) { $item in
                                    HStack(alignment: .top) {
                                        Button(action: { item.isSelected.toggle() }) {
                                            Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                                .foregroundColor(item.isSelected ? .blue : .gray)
                                                .padding(.top, 4)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.text)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                                .strikethrough(!item.isSelected)
                                            
                                            // Metadata Display
                                            if let meta = item.metadata {
                                                HStack(spacing: 8) {
                                                    if let date = meta.dueDate {
                                                        HStack(spacing: 2) {
                                                            Image(systemName: "calendar").font(.caption2)
                                                            Text(date, style: .date).font(.caption2)
                                                        }
                                                        .foregroundColor(.gray)
                                                    }
                                                    
                                                    if let assignee = meta.assignee {
                                                        HStack(spacing: 2) {
                                                            Image(systemName: "person.fill").font(.caption2)
                                                            Text(assignee).font(.caption2)
                                                        }
                                                        .foregroundColor(.blue)
                                                    }
                                                    
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "flag.fill").font(.caption2)
                                                        Text(priorityLabel(meta.priority)).font(.caption2)
                                                    }
                                                    .foregroundColor(priorityColor(meta.priority))
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            if let idx = subtasks.firstIndex(where: { $0.id == item.id }) {
                                                subtasks.remove(at: idx)
                                            }
                                        }) {
                                            Image(systemName: "xmark").foregroundColor(.gray)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(.systemGray6).opacity(0.5))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // Buttons
                    HStack(spacing: 16) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        
                        Button(action: saveAction) {
                            Text(isEditing ? "Save Changes" : "Create Task")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(title.isEmpty)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground)) // Subtle gray background for modal
            .navigationTitle(isEditing ? "Edit Task" : "Create New Task")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                firebaseService.fetchEmployees()
                firebaseService.fetchClients()
            }
        }
    }
    
    // MARK: - Components
    
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
    
    private func dataSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
    }
    
    private func customTextField(title: String, placeholder: String, text: Binding<String>, isSpeechEnabled: Bool, speechField: SpeechField?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            ZStack(alignment: .trailing) {
                TextField(placeholder, text: text)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                if isSpeechEnabled, let field = speechField {
                    speechButton(for: field)
                        .padding(.trailing, 8)
                }
            }
        }
    }
    
    private func dateField(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                DatePicker("", selection: date, displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func speechButton(for field: SpeechField) -> some View {
        Button(action: { toggleSpeech(for: field) }) {
            Image(systemName: speechHelper.isRecording && activeSpeechField == field ? "mic.circle.fill" : "mic.circle")
                .foregroundColor(speechHelper.isRecording && activeSpeechField == field ? .red : .gray)
                .font(.title3)
        }
    }
    
    struct AssigneeRow: View {
        let name: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                    Text(name)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(8)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Helpers
    
    var filteredEmployees: [EmployeeProfile] {
        if searchQuery.isEmpty { return firebaseService.employees }
        return firebaseService.employees.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var filteredClients: [Client] {
        if searchQuery.isEmpty { return firebaseService.clients }
        return firebaseService.clients.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    private func mapStatus(_ label: String) -> TaskStatus {
        let normalized = label.lowercased().trimmingCharacters(in: .whitespaces)
        if normalized.contains("progress") { return .inProgress }
        if normalized.contains("done") || normalized.contains("completed") { return .completed }
        if normalized.contains("stuck") { return .stuck }
        if normalized.contains("waiting") { return .waitingFor }
        if normalized.contains("help") { return .needHelp }
        if normalized.contains("cancel") { return .canceled }
        if normalized.contains("hold") { return .onHoldByClient }
        if normalized.contains("todo") || normalized.contains("to-do") || normalized.contains("not started") { return .notStarted }
        return .notStarted
    }
    
    private func toggleSpeech(for field: SpeechField) {
        if speechHelper.isRecording && activeSpeechField == field {
            speechHelper.stop()
            activeSpeechField = nil
        } else {
            if speechHelper.isRecording { speechHelper.stop() }
            activeSpeechField = field
            
            let baseTitle = title
            let baseDesc = description
            let baseSub = subtaskInput
            
            speechHelper.toggle { text in
                switch activeSpeechField {
                case .title: self.title = (baseTitle.isEmpty ? "" : baseTitle + " ") + text
                case .description: self.description = (baseDesc.isEmpty ? "" : baseDesc + " ") + text
                case .subtask: self.subtaskInput = (baseSub.isEmpty ? "" : baseSub + " ") + text
                case .none: break
                }
            }
        }
    }
    
    private func saveAction() {
        // Only include selected subtasks
        // Serialize metadata into string for compatibility if backend only accepts string
        // Format: "Title [Due: yyyy-MM-dd] [Assignee: Name] [Priority: Low]"
        let selectedSubtasks = subtasks.filter { $0.isSelected }.map { task -> String in
            var str = task.text
            if let meta = task.metadata {
                if let d = meta.dueDate {
                    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                    str += " [Due: \(f.string(from: d))]"
                }
                if let a = meta.assignee { str += " [Assignee: \(a)]" }
                if meta.priority != .p2 { str += " [P: \(priorityLabel(meta.priority))]" }
            }
            return str
        }
        let subtaskString = selectedSubtasks.isEmpty ? nil : selectedSubtasks.joined(separator: "\n")
        
        let data = NewTaskData(
            title: title,
            description: description,
            project: selectedProject,
            assignedDate: assignedDate,
            dueDate: dueDate,
            priority: selectedPriority,
            status: selectedStatus,
            statusLabel: selectedStatusText,
            taskType: taskType,
            isRecurring: isRecurring,
            recurringPattern: isRecurring ? recurringPattern : nil,
            recurringDays: nil, 
            recurringEndDate: nil,
            subtask: subtaskString,
            weightage: weightage,
            assignedTo: selectedAssigneeName,
            subtaskItems: subtasks.filter { $0.isSelected }.map { task in
                SubTaskItem(
                    title: task.text,
                    description: "",
                    isCompleted: false,
                    status: .notStarted,
                    priority: task.metadata?.priority ?? .p2,
                    createdAt: Date(),
                    assignedDate: Date(),
                    dueDate: task.metadata?.dueDate ?? Date().addingTimeInterval(86400 * 7),
                    assignedTo: task.metadata?.assignee
                )
            }
        )
        onSave(data)
        dismiss()
    }
}

// MARK: - Updated Data Struct
struct NewTaskData {
    let title: String
    let description: String
    let project: Project?
    let assignedDate: Date
    let dueDate: Date
    let priority: Priority
    let status: TaskStatus
    let statusLabel: String
    let taskType: CreateTaskView.TaskType
    let isRecurring: Bool
    let recurringPattern: RecurringPattern?
    let recurringDays: Int?
    let recurringEndDate: Date?
    let subtask: String?
    let weightage: String?
    var assignedTo: String? = nil // Added to support dynamic assignment
    var subtaskItems: [SubTaskItem]? = nil // Added for subcollection support
}
