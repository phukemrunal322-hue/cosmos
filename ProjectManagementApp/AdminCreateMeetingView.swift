import SwiftUI

struct AdminCreateMeetingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    var meetingToEdit: Meeting?
    
    // Form States
    @State private var title: String = ""
    @State private var selectedClient: String = "Select Client"
    @State private var duration: Int = 60
    @State private var selectedDate: Date = Date()
    @State private var description: String = ""
    @State private var selectedAttendeeIds: Set<String> = []
    
    // Duration Options
    let durationOptions = [15, 30, 45, 60, 90, 120]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { dismiss() }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(meetingToEdit != nil ? "Edit Event" : "Create Event")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Title Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            TextField("Project sync with client", text: $title)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Client and Duration Row
                        HStack(spacing: 16) {
                            // Client
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Client")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Menu {
                                    ForEach(firebaseService.clients) { client in
                                        Button(client.name) {
                                            selectedClient = client.name
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedClient)
                                            .foregroundColor(selectedClient == "Select Client" ? .secondary : .primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                            
                            // Duration
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Duration (min)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Menu {
                                    ForEach(durationOptions, id: \.self) { mins in
                                        Button("\(mins) minutes") {
                                            duration = mins
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("\(duration)")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                            .frame(width: 120)
                        }
                        
                        // Date and Time Row
                        HStack(spacing: 16) {
                            // Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Time
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Time")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Agenda or key talking points")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $description)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .frame(height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                        
                        // Attendees
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attendees (Select Resources)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(firebaseService.employees) { employee in
                                        let isSelected = selectedAttendeeIds.contains(employee.id)
                                        
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                if isSelected {
                                                    selectedAttendeeIds.remove(employee.id)
                                                } else {
                                                    selectedAttendeeIds.insert(employee.id)
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 12) {
                                                // Checkbox Icon
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 24)) // Slightly larger for easier tapping
                                                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.6))
                                                
                                                // Name & Email Stack
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(employee.name)
                                                        .font(.body)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.primary)
                                                    
                                                    Text(employee.email)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 16)
                                            .background(
                                                isSelected
                                                ? Color.blue.opacity(0.15)
                                                : Color.clear
                                            )
                                            .contentShape(Rectangle()) // Ensures the whole row is tappable
                                        }
                                        .buttonStyle(PlainButtonStyle()) // Prevents gray highlight flicker on tap
                                        
                                        Divider()
                                            .padding(.leading, 56)
                                            .opacity(0.6)
                                    }
                                }
                            }
                            .frame(height: 250)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Footer
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    
                    Button(action: createEvent) {
                        Text(meetingToEdit != nil ? "Save Changes" : "Create Event")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(title.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(title.isEmpty)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(20)
            .frame(maxWidth: 600)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            if firebaseService.employees.isEmpty {
                firebaseService.fetchEmployees()
            }
            if firebaseService.clients.isEmpty {
                firebaseService.fetchClients()
            }
            
            if let m = meetingToEdit {
                title = m.title
                selectedClient = m.project ?? "Select Client"
                duration = m.duration
                selectedDate = m.date
                description = m.agenda
                
                let matched = firebaseService.employees.filter { m.participants.contains($0.email) }
                selectedAttendeeIds = Set(matched.map { $0.id })
            }
        }
    }
    
    private func createEvent() {
        // Gather participants emails
        let selectedEmployees = firebaseService.employees.filter { selectedAttendeeIds.contains($0.id) }
        let participantEmails = selectedEmployees.map { $0.email }
        
        if let existingMeeting = meetingToEdit, let docId = existingMeeting.documentId {
             let clientToSave = (selectedClient == "Select Client") ? nil : selectedClient
             
             let updatedMeeting = Meeting(
                documentId: docId,
                title: title,
                date: selectedDate,
                duration: duration,
                participants: participantEmails,
                agenda: description,
                meetingType: existingMeeting.meetingType,
                project: clientToSave,
                status: existingMeeting.status,
                mom: existingMeeting.mom,
                location: existingMeeting.location,
                createdByUid: existingMeeting.createdByUid,
                createdByEmail: existingMeeting.createdByEmail
            )
            
            firebaseService.updateEvent(documentId: docId, meeting: updatedMeeting) { success in
                if success {
                    dismiss()
                }
            }
        } else {
            let newMeeting = Meeting(
                title: title,
                date: selectedDate,
                duration: duration,
                participants: participantEmails,
                agenda: description,
                meetingType: .general,
                project: nil,
                status: .scheduled,
                mom: nil,
                location: nil,
                createdByUid: authService.currentUid,
                createdByEmail: authService.currentUser?.email
            )
            
            firebaseService.createEvent(
                newMeeting,
                createdByUid: authService.currentUid,
                createdByEmail: authService.currentUser?.email,
                clientName: selectedClient == "Select Client" ? nil : selectedClient
            ) { success in
                if success {
                    dismiss()
                }
            }
        }
    }
}
