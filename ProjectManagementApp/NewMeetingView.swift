import SwiftUI
import Combine

struct NewMeetingView: View {
    let prefilledDate: Date?
    var onSave: ((Meeting) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var authService = FirebaseAuthService.shared
    @State private var title = ""
    @State private var agenda = ""
    @State private var selectedDate = Date()
    @State private var duration = 30
    @State private var selectedType = MeetingType.teamSync
    @State private var selectedProject = ""
    @State private var selectedClient = ""
    @State private var selectedEmployeeId: String = ""
    @State private var location = ""
    
    init(prefilledDate: Date? = nil, onSave: ((Meeting) -> Void)? = nil) {
        self.prefilledDate = prefilledDate
        self.onSave = onSave
        _selectedDate = State(initialValue: prefilledDate ?? Date())
    }
    
    let durations = [15, 30, 45, 60, 90, 120]
    
    // Employees filtered for the currently selected project
    private var filteredEmployees: [EmployeeProfile] {
        guard let project = firebaseService.projects.first(where: { $0.name == selectedProject }) else {
            return firebaseService.employees
        }
        let allowedEmails = Set(project.assignedEmployees.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        if allowedEmails.isEmpty { return firebaseService.employees }
        return firebaseService.employees.filter { employee in
            let email = employee.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return allowedEmails.contains(email)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meeting Details")) {
                    TextField("Meeting Title", text: $title)
                    if #available(iOS 16.0, *) {
                        TextField("Agenda", text: $agenda, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        // Fallback for iOS 15.6 and earlier: simple single-line TextField
                        TextField("Agenda", text: $agenda)
                    }
                    
                    
                    Picker("Project", selection: $selectedProject) {
                        ForEach(firebaseService.projects.map { $0.name }, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    
                    Picker("Employee", selection: $selectedEmployeeId) {
                        ForEach(filteredEmployees, id: \.id) { employee in
                            Text(employee.name).tag(employee.id)
                        }
                    }
                    
                    // Employee-only: Client dropdown
                    if authService.currentUser?.role == .employee {
                        Picker("Client", selection: $selectedClient) {
                            ForEach(firebaseService.clients.map { $0.name }, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                    
                    TextField("Location", text: $location)
                }
                
                Section(header: Text("Schedule")) {
                    DatePicker("Date & Time", selection: $selectedDate, in: Date()...)
                    Picker("Duration", selection: $duration) {
                        ForEach(durations, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                }
                
                Section {
                    Button("Schedule Meeting") {
                        let selectedEmployeeEmail = firebaseService.employees.first { $0.id == selectedEmployeeId }?.email
                        let participants: [String] = [
                            authService.currentUser?.email,
                            selectedEmployeeEmail
                        ].compactMap { $0 }
                        
                        let newMeeting = Meeting(
                            title: title,
                            date: selectedDate,
                            duration: duration,
                            participants: participants,
                            agenda: agenda,
                            meetingType: selectedType,
                            project: selectedProject,
                            status: .scheduled,
                            mom: nil,
                            location: location.isEmpty ? nil : location,
                            createdByUid: authService.currentUid,
                            createdByEmail: authService.currentUser?.email
                        )
                        FirebaseService.shared.createEvent(
                            newMeeting,
                            createdByUid: FirebaseAuthService.shared.currentUid,
                            createdByEmail: FirebaseAuthService.shared.currentUser?.email,
                            clientName: (authService.currentUser?.role == .employee ? selectedClient : nil)
                        ) { _ in }
                        onSave?(newMeeting)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.isEmpty || agenda.isEmpty)
                }
            }
            .navigationTitle("Schedule Meeting")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                if firebaseService.projects.isEmpty {
                    firebaseService.fetchProjects()
                }
                if selectedProject.isEmpty, let first = firebaseService.projects.first?.name {
                    selectedProject = first
                }
                if firebaseService.employees.isEmpty {
                    firebaseService.fetchEmployees()
                }
                if selectedEmployeeId.isEmpty, let first = firebaseService.employees.first?.id {
                    selectedEmployeeId = first
                }
                if authService.currentUser?.role == .employee {
                    if firebaseService.clients.isEmpty {
                        firebaseService.fetchClients()
                    }
                    if selectedClient.isEmpty, let first = firebaseService.clients.first?.name {
                        selectedClient = first
                    }
                }
            }
            .onReceive(firebaseService.$projects) { _ in
                if selectedProject.isEmpty, let first = firebaseService.projects.first?.name {
                    selectedProject = first
                }
            }
            .onReceive(firebaseService.$employees) { _ in
                if selectedEmployeeId.isEmpty, let first = firebaseService.employees.first?.id {
                    selectedEmployeeId = first
                }
            }
            .onChange(of: selectedProject) { _ in
                if let first = filteredEmployees.first?.id {
                    selectedEmployeeId = first
                } else {
                    selectedEmployeeId = ""
                }
            }
            .onReceive(firebaseService.$clients) { _ in
                if authService.currentUser?.role == .employee,
                   selectedClient.isEmpty,
                   let first = firebaseService.clients.first?.name {
                    selectedClient = first
                }
            }
        }
    }
}
