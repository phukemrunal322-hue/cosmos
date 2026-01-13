import SwiftUI
import Speech

struct AddProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var firebaseService: FirebaseService
    @StateObject private var authService = FirebaseAuthService.shared
    let projectToEdit: Project?
    
    // Project fields
    @State private var projectName: String = ""
    @State private var clientName: String = ""
    @State private var selectedManager: String = ""
    @State private var selectedAssignees: Set<String> = []
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(86400 * 30)
    @State private var objectiveTitle: String = ""
    @State private var keyResultText: String = ""
    
    // Speech
    @StateObject private var speechHelper = SpeechRecognizerHelper()
    @State private var activeSpeechField: SpeechField?
    @State private var didLoadInitialData: Bool = false
    
    enum SpeechField {
        case projectName
        case clientName
        case objective
        case keyResult
    }
    
    private var employees: [EmployeeProfile] { firebaseService.employees }
    private var managers: [String] {
        let names = firebaseService.employees.map { $0.name }
        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private var clientOptions: [String] {
        let companies = firebaseService.clients.compactMap { $0.companyName?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(companies)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private var canCreate: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        startDate <= endDate
    }

    private var isEditing: Bool { projectToEdit != nil }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    projectDetailsSection
                    timelineSection
                    okrSection
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Add New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                guard !didLoadInitialData else { return }
                didLoadInitialData = true

                if let project = projectToEdit {
                    // Existing project: prefill all fields
                    projectName = project.name
                    clientName = project.clientName ?? ""
                    selectedManager = project.projectManager
                        .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .flatMap { $0.isEmpty ? nil : $0 } ?? (authService.currentUser?.name ?? "")
                    selectedAssignees = Set(project.assignedEmployees)
                    startDate = project.startDate
                    endDate = project.endDate

                    if let firstObjective = project.objectives.first {
                        objectiveTitle = firstObjective.title
                        keyResultText = firstObjective.keyResults.map { $0.description }.joined(separator: "\n")
                    }
                } else {
                    // New project: default manager to logged-in user if available
                    if selectedManager.isEmpty,
                       let raw = authService.currentUser?.name {
                        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            selectedManager = trimmed
                        }
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Create a new project and assign OKRs")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var projectDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Details")
                .font(.headline)
            Divider()
            
            // Project Name + Mic
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Project Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("*").foregroundColor(.red)
                }
                ZStack(alignment: .trailing) {
                    TextField("e.g. Website Redesign", text: $projectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: { toggleSpeech(for: .projectName) }) {
                        Image(systemName: speechIcon(for: .projectName))
                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .projectName ? .red : .gray)
                            .padding(.trailing, 8)
                    }
                }
            }
            
            // Company / Client Name + Mic
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Company / Client Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("*").foregroundColor(.red)
                }
                Menu {
                    if clientOptions.isEmpty {
                        Text("No clients found")
                    } else {
                        ForEach(clientOptions, id: \.self) { client in
                            Button(client) { clientName = client }
                        }
                    }
                } label: {
                    HStack {
                        Text(clientName.isEmpty ? "Select a company" : clientName)
                            .foregroundColor(clientName.isEmpty ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Project Manager picker
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Project Manager")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("*").foregroundColor(.red)
                }
                Menu {
                    ForEach(managers, id: \.self) { manager in
                        Button(manager) { selectedManager = manager }
                    }
                } label: {
                    HStack {
                        Text(selectedManager.isEmpty ? "Select a project manager" : selectedManager)
                            .foregroundColor(selectedManager.isEmpty ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Assignees list (checkbox style)
            VStack(alignment: .leading, spacing: 8) {
                Text("Assignees")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if employees.isEmpty {
                    Text("No assignees available")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(employees) { employee in
                            Button(action: {
                                if selectedAssignees.contains(employee.name) {
                                    selectedAssignees.remove(employee.name)
                                } else {
                                    selectedAssignees.insert(employee.name)
                                }
                            }) {
                                HStack {
                                    Text(employee.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: selectedAssignees.contains(employee.name) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedAssignees.contains(employee.name) ? .blue : .gray)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(16)
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.headline)
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Start Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("*").foregroundColor(.red)
                    }
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("End Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("*").foregroundColor(.red)
                    }
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(16)
    }
    
    private var okrSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("OKRS")
                    .font(.headline)
                Spacer()
            }
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Objective")
                    .font(.subheadline)
                    .fontWeight(.medium)
                ZStack(alignment: .trailing) {
                    TextField("Objective...", text: $objectiveTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: { toggleSpeech(for: .objective) }) {
                        Image(systemName: speechIcon(for: .objective))
                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .objective ? .red : .gray)
                            .padding(.trailing, 8)
                    }
                }
                
                Text("Key Results (one line per result)")
                    .font(.subheadline)
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $keyResultText)
                        .frame(height: 100)
                        .padding(6)
                        .background(Color.gray.opacity(0.06))
                        .cornerRadius(10)
                    Button(action: { toggleSpeech(for: .keyResult) }) {
                        Image(systemName: speechIcon(for: .keyResult))
                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .keyResult ? .red : .gray)
                            .padding(10)
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(16)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") { dismiss() }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.primary)
                .cornerRadius(12)
            
            Button(isEditing ? "Update Project" : "Create Project") {
                if isEditing {
                    updateProject()
                } else {
                    createProject()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreate ? Color.orange : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!canCreate)
        }
    }
    
    private func toggleSpeech(for field: SpeechField) {
        if speechHelper.isRecording && activeSpeechField == field {
            speechHelper.stop()
            activeSpeechField = nil
            return
        }
        if speechHelper.isRecording {
            speechHelper.stop()
        }
        activeSpeechField = field
        let baseProjectName = projectName
        let baseClientName = clientName
        let baseObjective = objectiveTitle
        let baseKR = keyResultText
        speechHelper.toggle { text in
            switch self.activeSpeechField {
            case .projectName:
                let prefix = baseProjectName.isEmpty ? "" : baseProjectName + " "
                self.projectName = prefix + text
            case .clientName:
                let prefix = baseClientName.isEmpty ? "" : baseClientName + " "
                self.clientName = prefix + text
            case .objective:
                let prefix = baseObjective.isEmpty ? "" : baseObjective + " "
                self.objectiveTitle = prefix + text
            case .keyResult:
                let prefix = baseKR.isEmpty ? "" : baseKR + " "
                self.keyResultText = prefix + text
            case .none:
                break
            }
        }
    }
    
    private func speechIcon(for field: SpeechField) -> String {
        if speechHelper.isRecording && activeSpeechField == field {
            return "mic.circle.fill"
        } else {
            return "mic.circle"
        }
    }
    
    private func buildObjectives(using trimmedName: String) -> [Objective] {
        let lines = keyResultText
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let keyResults = lines.map { KeyResult(description: $0) }
        if !objectiveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !keyResults.isEmpty {
            let obj = Objective(
                title: objectiveTitle.isEmpty ? trimmedName : objectiveTitle,
                keyResults: keyResults
            )
            return [obj]
        }
        return []
    }

    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClient = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedClient.isEmpty else { return }
        
        // ID Lookups
        let clientId = firebaseService.clients.first { $0.companyName?.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedClient }?.documentId
        let managerId = firebaseService.employees.first { $0.name == selectedManager }?.id
        let assigneeIds = selectedAssignees.compactMap { name in
            firebaseService.employees.first { $0.name == name }?.id
        }
        
        let objectives = buildObjectives(using: trimmedName)
        firebaseService.createProject(
            name: trimmedName,
            clientName: trimmedClient,
            clientId: clientId,
            projectManager: selectedManager.isEmpty ? nil : selectedManager,
            projectManagerId: managerId,
            assignedEmployees: Array(selectedAssignees),
            assigneeIds: assigneeIds,
            startDate: startDate,
            endDate: endDate,
            objectives: objectives
        ) { _ in
            dismiss()
        }
    }

    private func updateProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClient = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedClient.isEmpty else { return }
        guard let project = projectToEdit, let documentId = project.documentId else {
            // If we don't have a document ID, fall back to creating a new project
            createProject()
            return
        }
        
        // ID Lookups
        let clientId = firebaseService.clients.first { $0.companyName?.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedClient }?.documentId
        let managerId = firebaseService.employees.first { $0.name == selectedManager }?.id
        let assigneeIds = selectedAssignees.compactMap { name in
            firebaseService.employees.first { $0.name == name }?.id
        }

        let objectives = buildObjectives(using: trimmedName)
        firebaseService.updateProject(
            documentId: documentId,
            name: trimmedName,
            clientName: trimmedClient,
            clientId: clientId,
            projectManager: selectedManager.isEmpty ? nil : selectedManager,
            projectManagerId: managerId,
            assignedEmployees: Array(selectedAssignees),
            assigneeIds: assigneeIds,
            startDate: startDate,
            endDate: endDate,
            objectives: objectives
        ) { _ in
            dismiss()
        }
    }
}
