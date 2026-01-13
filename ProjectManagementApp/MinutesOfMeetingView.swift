import SwiftUI
import Combine
import Speech
import AVFoundation
import UIKit

struct MinutesOfMeetingView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared

    @State private var formID = UUID()
    @State private var selectedMeeting: Meeting?
    @State private var showSavedMOMs = false
    

    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Minutes of Meeting")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("AI-powered MOM generation with professional structured format")
                        .font(.caption)
                        .foregroundColor(.gray)
                    

                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Saved MOMs Button
                Button(action: { showSavedMOMs = true }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Saved MOMs")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                

                }
                .padding(.horizontal)
                
                // Embedded Creation Form
                CreateMeetingMOMView()
                    .id(formID)
            }
            .background(Color.gray.opacity(0.05))
            .sheet(isPresented: $showSavedMOMs) {
                SavedMOMsView()
            }

        .sheet(item: $selectedMeeting) { meeting in
            MeetingMOMDetailView(meeting: meeting)
        }
    }
}

struct MeetingMOMCard: View {
    let meeting: Meeting
    let action: () -> Void
    
    var statusColor: Color {
        switch meeting.status {
        case .scheduled: return .yellow
        case .completed: return .green
        case .cancelled: return .red
        case .inProgress: return .orange
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meeting.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                        }
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(meeting.status.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(meeting.duration) min")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(meeting.participants.count) participants")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    
                    Spacer()
                    
                    if meeting.mom != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption2)
                            Text("MOM")
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
struct ActionItem: Identifiable, Codable {
    var id = UUID()
    var task: String
    var person: String
    var deadline: Date
}

struct DiscussionPoint: Identifiable, Codable {
    var id = UUID()
    var topic: String
    var notes: String
}

struct DiscussionAnalysis: Codable {
    let summary: String
    let keyPoints: [String]
    let decisions: [String]
    let nextSteps: [String]
    
    // Default empty for fallback
    static var empty: DiscussionAnalysis {
        DiscussionAnalysis(summary: "", keyPoints: [], decisions: [], nextSteps: [])
    }
}


struct CreateMeetingMOMView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    private let geminiService = GeminiAPIService()
    
    @State private var projectName = ""
    @State private var meetingDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var venue = ""
    @State private var internalAttendees: [String] = []
    @State private var externalAttendees = ""
    @State private var momPreparedBy = ""
    @State private var agendaItems: [String] = [""]


    @State private var discussionPoints: [DiscussionPoint] = []
    @State private var newDiscussionTopic: String = ""
    @State private var newDiscussionNotes: String = ""
    
    @State private var discussionTopics = "" // Keeping for backward compatibility or computed property later
    @State private var actionItems: [ActionItem] = []
    @State private var newActionTask = ""
    @State private var newActionPerson = ""
    @State private var newActionDeadline = Date()
    
    @State private var generatedMOM = ""
    @State private var isGenerating = false
    @State private var showPreview = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    @State private var showInternalAttendeePicker = false
    @State private var selectedInternalAttendees: Set<String> = []
    
    @State private var generatedAnalysis: DiscussionAnalysis?
    
    // Action States
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var currentMOMID = ""
    

    
    // Strict validation
    var canGenerate: Bool {
        let hasValidDiscussion = !discussionPoints.isEmpty
        
        return !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !internalAttendees.isEmpty &&
        !agendaItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.isEmpty &&
        hasValidDiscussion &&
        !actionItems.isEmpty &&
        !momPreparedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func validateFields() -> Bool {
        if projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if internalAttendees.isEmpty { return false }
        if agendaItems.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).isEmpty { return false }
        
        let hasValidDiscussion = !discussionPoints.isEmpty || (!newDiscussionTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !newDiscussionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if !hasValidDiscussion { return false }
        
        if actionItems.isEmpty { return false }
        if momPreparedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }
    
    @State private var isEditing = true // Track if we are editing or viewing preview
    @State private var isSaving = false

    var body: some View {

            ScrollView {
                VStack(spacing: 20) {
                    if isEditing {
                        // Section 1: Meeting Details
                        meetingDetailsSection
                        
                        // Section 2: Attendees
                        attendeesSection
                        
                        // Section 3: Agenda
                        agendaSection
                        
                        // Section 4: Discussion & Action Items
                        discussionSection
                        
                        actionItemsSection
                    }
                    
                    // Button Section
                    HStack(spacing: 12) {
                        if !isEditing {
                            // In PREVIEW Mode:
                            // 0. Back/Reset Button
                            Button(action: {
                                withAnimation {
                                    resetForm()
                                    isEditing = true
                                    showPreview = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("New")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                            }

                            // 1. Edit Details Button (Flexible)
                            Button(action: {
                                withAnimation {
                                    isEditing = true
                                    showPreview = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("Edit")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                            }
                            
                            Menu {
                                
                                Button(action: saveMOM) {
                                    Label("Save MOM", systemImage: "square.and.arrow.down.fill")
                                }
                                
                                Button(action: { generateAndShare() }) {
                                    Label("Export PDF", systemImage: "doc.text.fill")
                                }
                                
                                Button(action: { generateAndShare() }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                
                                Button(action: { generateAndPrint() }) {
                                    Label("Print", systemImage: "printer")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .rotationEffect(.degrees(90))
                                    Text("Actions")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                        } else {
                            // In FORM Mode: Show "Generate MOM"
                            Button(action: generateMOM) {
                                HStack {
                                    if isGenerating {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("Generate MOM")
                                    }
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canGenerate ? Color.purple : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!canGenerate || isGenerating)
                        }
                    }
                    .padding(.vertical)
                    
                    if showPreview && !isEditing {
                        previewSection
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))

            .sheet(isPresented: $showInternalAttendeePicker) {
                InternalAttendeePickerView(
                    selectedAttendees: $selectedInternalAttendees,
                    onDone: {
                        internalAttendees = Array(selectedInternalAttendees)
                        showInternalAttendeePicker = false
                    }
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {
                    
                }
            } message: {
                Text("Minutes of Meeting saved successfully!")
            }
            .onAppear {
                firebaseService.fetchProjects()
                firebaseService.fetchEmployees()
                firebaseService.fetchNextMOMID { id in
                    self.currentMOMID = id
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    MOMShareSheet(items: [url])
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4)
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("Saving MOM...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color.gray.opacity(0.9))
                        .cornerRadius(16)
                    }
                    .ignoresSafeArea()
                }
            }


    }
    
    private var meetingDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            projectPicker
            datePicker
            timePickers
            venueField
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
    
    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project *")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            Menu {
                ForEach(firebaseService.projects, id: \.id) { project in
                    Button(project.name) {
                        projectName = project.name
                    }
                }
            } label: {
                HStack {
                    Text(projectName.isEmpty ? "Select Project" : projectName)
                        .foregroundColor(projectName.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date *")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            DatePicker("", selection: $meetingDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
    }
    
    private var timePickers: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("End Time")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    private var venueField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Venue")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            MicTextField(title: "e.g. Office Big Softwave, Sangli", text: $venue)
        }
    }
    
    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attendees")
                .font(.headline)
                .fontWeight(.semibold)
            
            internalAttendeesField
            externalAttendeesField
            preparedByField
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
    
    private var internalAttendeesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Internal Attendees * (Select multiple)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            Button(action: { showInternalAttendeePicker = true }) {
                HStack {
                    if selectedInternalAttendees.isEmpty {
                        Text("Select internal attendees")
                            .foregroundColor(.gray)
                    } else {
                        Text("\(selectedInternalAttendees.count) selected")
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            if !selectedInternalAttendees.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedInternalAttendees), id: \.self) { name in
                            attendeeChip(name: name)
                        }
                    }
                }
            }
        }
    }
    
    private func attendeeChip(name: String) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption)
            Button(action: {
                selectedInternalAttendees.remove(name)
                internalAttendees.removeAll { $0 == name }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.1))
        .foregroundColor(.purple)
        .cornerRadius(12)
    }
    
    private var externalAttendeesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("External Attendees (comma separated)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            MicTextField(title: "e.g. John Doe (client), Jane Doe (vendor), etc.", text: $externalAttendees)
        }
    }
    
    private var preparedByField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MOM Prepared by *")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            MicTextField(title: "Your name", text: $momPreparedBy)
        }
    }
    
    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Agenda & Discussion")
                .font(.headline)
                .fontWeight(.semibold)
            
            agendaItemsField
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
    
    private var agendaItemsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agenda Items (one per line)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            ForEach(0..<agendaItems.count, id: \.self) { index in
                HStack(spacing: 8) {
                    MicTextField(title: "Discussion topic required...", text: $agendaItems[index])
                    
                    if agendaItems.count > 1 {
                        Button(action: {
                            agendaItems.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Button(action: {
                agendaItems.append("")
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Topic")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
        }
    }
    
    private var discussionSection: some View {
        VStack(spacing: 12) {
            Text("Discussion")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // List of Added Discussion Points
            if !discussionPoints.isEmpty {
                VStack(spacing: 12) {
                    ForEach(discussionPoints) { point in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(point.topic)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Spacer()
                                Button(action: {
                                    if let index = discussionPoints.firstIndex(where: { $0.id == point.id }) {
                                        discussionPoints.remove(at: index)
                                        updateDiscussionString()
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                            
                            Text(point.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            
            // Input Fields
            VStack(spacing: 12) {
                // Topic Input
                MicTextField(title: "Discussion topic (required)...", text: $newDiscussionTopic)
                
                // Notes Input
                MicTextField(title: "Notes (required). One point per line...", text: $newDiscussionNotes, axis: .vertical)
                
                // Add Button
                Button(action: addDiscussionPoint) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Topic")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.purple.opacity(0.2)) // Slightly richer purple bg
                    .foregroundColor(.purple)
                    .cornerRadius(8)
                }
                .disabled(newDiscussionTopic.isEmpty || newDiscussionNotes.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
    
    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Next Action Plan (Drag to Reorder)*")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("An action items ordered list")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Display added action items
            if !actionItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(actionItems) { item in
                        addedActionItemRow(item: item)
                    }
                }
            }
            
            // Input fields for new action item
            VStack(spacing: 12) {
                // Row 1: Task Description (Full Width)
                MicTextField(title: "Task description...", text: $newActionTask)
                
                // Row 2: Person, Date, Add Button
                HStack(spacing: 8) {
                    MicTextField(title: "Person...", text: $newActionPerson)
                    
                    DatePicker("", selection: $newActionDeadline, displayedComponents: .date)
                        .labelsHidden()
                        .fixedSize() // Prevent squashing
                    
                    Button(action: addActionItem) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.purple)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
    
    private func addedActionItemRow(item: ActionItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Task:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text(item.task)
                        .font(.subheadline)
                }
                
                HStack {
                    Text("Person:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text(item.person)
                        .font(.subheadline)
                }
                
                HStack {
                    Text("Deadline:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text(item.deadline.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                }
            }
            
            Spacer()
            
            Button(action: {
                if let index = actionItems.firstIndex(where: { $0.id == item.id }) {
                    actionItems.remove(at: index)
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func addDiscussionPoint() {
        guard !newDiscussionTopic.isEmpty, !newDiscussionNotes.isEmpty else { return }
        
        let point = DiscussionPoint(topic: newDiscussionTopic, notes: newDiscussionNotes)
        discussionPoints.append(point)
        
        // Update the legacy string for generation compatibility
        updateDiscussionString()
        
        newDiscussionTopic = ""
        newDiscussionNotes = ""
    }
    
    private func updateDiscussionString() {
        discussionTopics = discussionPoints.map { "Topic: \($0.topic)\nNotes: \($0.notes)" }.joined(separator: "\n\n")
    }

    private func addActionItem() {
        guard !newActionTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newItem = ActionItem(
            task: newActionTask,
            person: newActionPerson,
            deadline: newActionDeadline
        )
        actionItems.append(newItem)
        
        // Clear input fields
        newActionTask = ""
        newActionPerson = ""
        newActionDeadline = Date()
    }
    
    private var previewSection: some View {
        VStack(spacing: 0) {
            Text("MINUTES OF MEETING")
                .font(.title2)
                .bold() // stronger bold
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            Text("ID: \(currentMOMID)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            
            // Table 1: Details
            VStack(spacing: 0) {
                // Header Row
                Group {
                    detailRow(label: "Project Name", value: projectName)
                    Divider().background(Color.primary)
                    detailRow(label: "Meeting Date & Time", value: "\(meetingDate.formatted(date: .long, time: .omitted)) \(startTime.formatted(date: .omitted, time: .shortened)) To \(endTime.formatted(date: .omitted, time: .shortened))")
                    Divider().background(Color.primary)
                    detailRow(label: "Meeting Venue", value: venue)
                    Divider().background(Color.primary)
                    detailRow(label: "Internal Attendees", value: Array(selectedInternalAttendees).joined(separator: ", "))
                    Divider().background(Color.primary)
                    detailRow(label: "External Attendees", value: externalAttendees)
                    Divider().background(Color.primary)
                    detailRow(label: "MOM Prepared by", value: momPreparedBy)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .stroke(Color.primary, lineWidth: 1.5) // Thicker border
            )
            .padding(.bottom, 20)
            
            // Table 2: Agenda
            VStack(alignment: .leading, spacing: 0) {
                Text("Meeting Agenda:")
                    .font(.caption)
                    .bold()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.1)) // Adaptive gray
                    .border(Color.primary, width: 1.5)
                
                ForEach(Array(agendaItems.enumerated()), id: \.offset) { index, item in
                    if !item.isEmpty {
                        Text("\(index + 1). \(item)")
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .border(Color.primary, width: 1)
                            .offset(y: -1)
                    }
                }
            }
            .padding(.bottom, 20)
            
            // Table 3: Discussion
            Text("Discussion:")
                .font(.caption)
                .bold()
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .top, spacing: 0) {
                // Left Column: Raw Discussion
                VStack(alignment: .leading, spacing: 0) {
                    Text("Discussion")
                        .font(.caption)
                        .bold()
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.1))
                        .border(Color.primary, width: 1.5)
                    
                    Text(discussionTopics)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 200, alignment: .topLeading)
                        .border(Color.primary, width: 1)
                        .offset(y: -1)
                }
                .frame(width: 150)
                
                // Right Column: Analysis
                VStack(alignment: .leading, spacing: 0) {
                    Text("Remark/Comments/Notes")
                        .font(.caption)
                        .bold()
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.1))
                        .border(Color.primary, width: 1.5)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if let analysis = generatedAnalysis {
                            if !analysis.summary.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Summary:").font(.caption).bold().underline()
                                    Text(analysis.summary).font(.caption)
                                }
                            }
                            
                            if !analysis.keyPoints.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Key Points:").font(.caption).bold().underline()
                                    ForEach(analysis.keyPoints, id: \.self) { point in
                                        Text("• \(point)").font(.caption)
                                    }
                                }
                            }
                            
                            if !analysis.decisions.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Decisions Taken:").font(.caption).bold().underline()
                                    ForEach(analysis.decisions, id: \.self) { item in
                                        Text("• \(item)").font(.caption)
                                    }
                                }
                            }
                            
                            if !analysis.nextSteps.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Next Steps:").font(.caption).bold().underline()
                                    ForEach(analysis.nextSteps, id: \.self) { item in
                                        Text("• \(item)").font(.caption)
                                    }
                                }
                            }
                        } else {
                            if errorMessage.isEmpty {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text("Failed to load analysis").font(.caption).foregroundColor(.red)
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(minHeight: 200)
                    .border(Color.primary, width: 1)
                    .offset(y: -1)
                }
            }
            .padding(.bottom, 20)
            
            // Table 4: Action Plan
            Text("Next Action Plan:")
                .font(.caption)
                .bold()
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("Task").font(.caption).bold().padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    Divider().frame(width: 1.5).background(Color.primary)
                    Text("Responsible Person").font(.caption).bold().padding(8).frame(width: 120, alignment: .leading)
                    Divider().frame(width: 1.5).background(Color.primary)
                    Text("Deadline").font(.caption).bold().padding(8).frame(width: 80, alignment: .leading)
                }
                .background(Color.primary.opacity(0.1))
                .border(Color.primary, width: 1.5)
                
                // Rows
                ForEach(actionItems) { item in
                    HStack(spacing: 0) {
                        Text(item.task).font(.caption).padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        Divider().frame(width: 1).background(Color.primary)
                        Text(item.person).font(.caption).padding(8).frame(width: 120, alignment: .leading)
                        Divider().frame(width: 1).background(Color.primary)
                        Text(item.deadline.formatted(date: .numeric, time: .omitted)).font(.caption).padding(8).frame(width: 80, alignment: .leading)
                    }
                    .border(Color.primary, width: 1)
                    .offset(y: -1)
                }
            }
            .padding(.bottom, 20)
            
            // Footer
            HStack {
                Text("Generated on \(Date().formatted(date: .numeric, time: .omitted))")
                Spacer()
                Text("Page 1 of 1")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            

            
        }
        .padding()
        .background(Color(.systemBackground)) // Adapts to Dark/Light mode!
        .cornerRadius(4)
        .shadow(color: Color.primary.opacity(0.1), radius: 5)
        .padding()
        .id(UUID()) // Force redraw
    }
    
    // Helper Row Builder
    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.caption)
                .bold()
                .padding(8)
                .frame(width: 140, alignment: .leading)
                .background(Color.primary.opacity(0.1)) // Adaptive header bg
            
            Divider().background(Color.primary)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    
    private func resetForm() {
        projectName = ""
        meetingDate = Date()
        startTime = Date()
        endTime = Date()
        venue = ""
        selectedInternalAttendees = []
        internalAttendees = []
        externalAttendees = ""
        momPreparedBy = ""
        agendaItems = [""]
        discussionPoints = []
        newDiscussionTopic = ""
        newDiscussionNotes = ""
        actionItems = []
        newActionTask = ""
        newActionPerson = ""
        newActionDeadline = Date()
        generatedAnalysis = nil
        pdfURL = nil
        pdfURL = nil
        showShareSheet = false
        firebaseService.fetchNextMOMID { id in
            self.currentMOMID = id
        }
    }

    private func generateMOM() {
        guard validateFields() else {
            errorMessage = "Please fill in all required fields."
            showError = true
            return
        }
        
        // Auto-add pending discussion point if exists
        if !newDiscussionTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           !newDiscussionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addDiscussionPoint()
        }
        
        isGenerating = true
        generatedMOM = ""
        generatedAnalysis = nil
        showPreview = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateString = dateFormatter.string(from: meetingDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)
        
        let agendaText = agendaItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
        
        // We only send discussion text for analysis now
        
        _Concurrency.Task {
            do {
                let jsonResponse = try await geminiService.generateMinutesOfMeeting(
                    projectName: projectName,
                    date: dateString,
                    startTime: startTimeString,
                    endTime: endTimeString,
                    venue: venue,
                    internalAttendees: Array(selectedInternalAttendees).joined(separator: ", "),
                    externalAttendees: externalAttendees,
                    agenda: agendaText,
                    discussion: discussionTopics,
                    actionItems: "",
                    preparedBy: momPreparedBy
                )
                
                // Try to clean and parse JSON
                let cleanJson = jsonResponse.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let data = cleanJson.data(using: .utf8),
                   let analysis = try? JSONDecoder().decode(DiscussionAnalysis.self, from: data) {
                    
                    await MainActor.run {
                        self.generatedAnalysis = analysis
                        self.generatedMOM = "Generated"
                        self.isGenerating = false
                        self.isEditing = false // Switch to Preview Mode
                    }
                } else {
                    // Fallback if JSON fails: Use Manual Professional Defaults
                    print("JSON Parsing failed, using professional fallback")
                    let fallbackAnalysis = DiscussionAnalysis(
                        summary: discussionTopics,
                        keyPoints: [discussionTopics], // specific point
                        decisions: ["No final decision; items carried forward for next review."],
                        nextSteps: ["Owners to execute agreed tasks before the next meeting."]
                    )
                    
                    await MainActor.run {
                        self.generatedAnalysis = fallbackAnalysis
                        self.generatedMOM = "Generated"
                        self.isGenerating = false
                        self.isEditing = false // Switch to Preview Mode
                    }
                }

            } catch {
                print("Generation failed: \(error.localizedDescription)")
                // Network error: Use Manual Professional Defaults
                let offlineAnalysis = DiscussionAnalysis(
                    summary: discussionTopics.isEmpty ? "Discussion held to review status and agree on actions." : discussionTopics,
                    keyPoints: discussionTopics.isEmpty ? ["Review of project status"] : [discussionTopics],
                    decisions: ["No final decision; items carried forward for next review."],
                    nextSteps: ["Owners to execute agreed tasks before the next meeting."]
                )
                
                await MainActor.run {
                    self.generatedAnalysis = offlineAnalysis
                    self.generatedMOM = "Generated"
                    self.isGenerating = false
                    self.isEditing = false // Switch to Preview Mode
                }
            }
        }
    }
    
    private func buildFallbackMOM() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateString = dateFormatter.string(from: meetingDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)
        
        var mom = """
        MINUTES OF MEETING
        
        Project: \(projectName)
        Date: \(dateString)
        Time: \(startTimeString) - \(endTimeString)
        Venue: \(venue)
        
        ATTENDEES:
        Internal: \(Array(selectedInternalAttendees).joined(separator: ", "))
        """
        
        if !externalAttendees.isEmpty {
            mom += "\nExternal: \(externalAttendees)"
        }
        
        mom += "\n\nAGENDA:\n"
        for (index, item) in agendaItems.enumerated() where !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mom += "\(index + 1). \(item)\n"
        }
        
        mom += "\nDISCUSSION:\n\(discussionTopics)\n"
        
        mom += "\nACTION ITEMS:\n"
        for (index, item) in actionItems.enumerated() {
            let deadlineStr = item.deadline.formatted(date: .abbreviated, time: .omitted)
            mom += "\(index + 1). \(item.task) [Resp: \(item.person), Due: \(deadlineStr)]\n"
        }
        
        mom += "\nPrepared by: \(momPreparedBy)"
        
        return mom
    }
    
    private func buildMOMDocument() -> MOMDocument {
        MOMDocument(
            id: currentMOMID,
            projectName: projectName,
            date: meetingDate,
            startTime: startTime,
            endTime: endTime,
            venue: venue,
            internalAttendees: Array(selectedInternalAttendees),
            externalAttendees: externalAttendees,
            preparedBy: momPreparedBy,
            agenda: agendaItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            discussionPoints: discussionPoints,
            analysis: generatedAnalysis,
            actionItems: actionItems,
            createdAt: Date()
        )
    }

    private func saveMOM() {
        isSaving = true
        let doc = buildMOMDocument()
        
        // Step 1: Save MOM to minutes_of_meetings collection first to get the document ID
        firebaseService.saveMOM(doc) { result in
            switch result {
            case .success(let momDocumentId):
                // Step 2: Generate PDF
                let renderer = MOMPDFRenderer()
                guard let pdfURL = renderer.render(mom: doc) else {
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.errorMessage = "Failed to generate PDF."
                        self.showError = true
                    }
                    return
                }
                
                // Step 3: Upload PDF to Firebase Storage
                self.firebaseService.uploadMOMPDF(fileURL: pdfURL) { uploadResult in
                    switch uploadResult {
                    case .success(let downloadURL):
                        // Step 4: Save to documents collection with MOM ID
                        let desc = "Minutes of Meeting for \(doc.projectName) on \(doc.date.formatted(date: .numeric, time: .omitted))"
                        self.firebaseService.saveDocumentEntry(
                            name: doc.projectName.isEmpty ? "Untitled MOM" : doc.projectName,
                            url: downloadURL,
                            category: "MOMs",
                            description: desc,
                            userUid: self.authService.currentUid,
                            momId: momDocumentId  // Pass the MOM document ID here
                        ) { error in
                            DispatchQueue.main.async {
                                self.isSaving = false
                                if let error = error {
                                    self.errorMessage = "MOM saved but failed to link to documents: \(error.localizedDescription)"
                                    self.showError = true
                                } else {
                                    self.showSuccess = true
                                }
                            }
                        }
                        
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.isSaving = false
                            self.errorMessage = "MOM saved but failed to upload PDF: \(error.localizedDescription)"
                            self.showError = true
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.errorMessage = "Failed to save MOM: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func generateAndShare() {
        let doc = buildMOMDocument()
        let renderer = MOMPDFRenderer()
        if let url = renderer.render(mom: doc) {
            self.pdfURL = url
            self.showShareSheet = true
        }
    }
    
    private func generateAndPrint() {
        let doc = buildMOMDocument()
        let renderer = MOMPDFRenderer()
        if let url = renderer.render(mom: doc) {
            let printInfo = UIPrintInfo(dictionary: nil)
            printInfo.outputType = .general
            printInfo.jobName = "MOM Print"
            
            let controller = UIPrintInteractionController.shared
            controller.printInfo = printInfo
            controller.printingItem = url
            controller.present(animated: true)
        }
    }
}

struct InternalAttendeePickerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Binding var selectedAttendees: Set<String>
    let onDone: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(firebaseService.employees, id: \.id) { employee in
                    Button(action: {
                        if selectedAttendees.contains(employee.name) {
                            selectedAttendees.remove(employee.name)
                        } else {
                            selectedAttendees.insert(employee.name)
                        }
                    }) {
                        HStack {
                            Text(employee.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedAttendees.contains(employee.name) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Attendees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }
}

struct MeetingMOMDetailView: View {
    let meeting: Meeting
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Meeting Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(meeting.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                Text(meeting.date.formatted(date: .long, time: .shortened))
                            }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                Text("\(meeting.duration) min")
                            }
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Participants
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Participants")
                            .font(.headline)
                        
                        ForEach(meeting.participants, id: \.self) { participant in
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text(participant)
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Agenda
                    if !meeting.agenda.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Agenda")
                                .font(.headline)
                            
                            Text(meeting.agenda)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                    }
                    
                    // Minutes of Meeting
                    if let mom = meeting.mom {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Minutes of Meeting")
                                .font(.headline)
                            
                            Text(mom)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No Minutes Recorded")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Meeting Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Saved MOMs Feature

struct SavedMOMsView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(firebaseService.savedMOMs) { mom in
                NavigationLink(destination: MOMDetailView(mom: mom)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mom.projectName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(mom.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(mom.preparedBy)
                                .font(.caption)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Saved MOMs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                firebaseService.fetchMOMs()
            }
        }
    }
}

struct MOMDetailView: View {
    let mom: MOMDocument
    @State private var showingExport = false // Placeholder for export
    
    var discussionString: String {
        mom.discussionPoints.map { "Topic: \($0.topic)\nNotes: \($0.notes)" }.joined(separator: "\n\n")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("MINUTES OF MEETING")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
                
                Text(mom.id != nil ? "ID: MOM_\(mom.id!.prefix(6).uppercased())" : "ID: MOM")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                
                // Table 1: Details
                VStack(spacing: 0) {
                    Group {
                        detailRow(label: "Project Name", value: mom.projectName)
                        Divider().background(Color.primary)
                        detailRow(label: "Meeting Date & Time", value: "\(mom.date.formatted(date: .long, time: .omitted)) \(mom.startTime.formatted(date: .omitted, time: .shortened)) To \(mom.endTime.formatted(date: .omitted, time: .shortened))")
                        Divider().background(Color.primary)
                        detailRow(label: "Meeting Venue", value: mom.venue)
                        Divider().background(Color.primary)
                        detailRow(label: "Internal Attendees", value: mom.internalAttendees.joined(separator: ", "))
                        Divider().background(Color.primary)
                        detailRow(label: "External Attendees", value: mom.externalAttendees)
                        Divider().background(Color.primary)
                        detailRow(label: "MOM Prepared by", value: mom.preparedBy)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(Color.primary, lineWidth: 1.5)
                )
                .padding(.bottom, 20)
                
                // Table 2: Agenda
                VStack(alignment: .leading, spacing: 0) {
                    Text("Meeting Agenda:")
                        .font(.caption)
                        .bold()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.1))
                        .border(Color.primary, width: 1.5)
                    
                    ForEach(Array(mom.agenda.enumerated()), id: \.offset) { index, item in
                        if !item.isEmpty {
                            Text("\(index + 1). \(item)")
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .border(Color.primary, width: 1)
                                .offset(y: -1)
                        }
                    }
                }
                .padding(.bottom, 20)
                
                // Table 3: Discussion
                Text("Discussion:")
                    .font(.caption)
                    .bold()
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(alignment: .top, spacing: 0) {
                    // Left Column: Raw Discussion
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Discussion")
                            .font(.caption)
                            .bold()
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.1))
                            .border(Color.primary, width: 1.5)
                        
                        Text(discussionString)
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 200, alignment: .topLeading)
                            .border(Color.primary, width: 1)
                            .offset(y: -1)
                    }
                    .frame(width: 150)
                    
                    // Right Column: Analysis
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Remark/Comments/Notes")
                            .font(.caption)
                            .bold()
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.1))
                            .border(Color.primary, width: 1.5)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            if let analysis = mom.analysis {
                                if !analysis.summary.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Summary:").font(.caption).bold().underline()
                                        Text(analysis.summary).font(.caption)
                                    }
                                }
                                
                                if !analysis.keyPoints.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Key Points:").font(.caption).bold().underline()
                                        ForEach(analysis.keyPoints, id: \.self) { point in
                                            Text("• \(point)").font(.caption)
                                        }
                                    }
                                }
                                
                                if !analysis.decisions.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Decisions Taken:").font(.caption).bold().underline()
                                        ForEach(analysis.decisions, id: \.self) { item in
                                            Text("• \(item)").font(.caption)
                                        }
                                    }
                                }
                                
                                if !analysis.nextSteps.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Next Steps:").font(.caption).bold().underline()
                                        ForEach(analysis.nextSteps, id: \.self) { item in
                                            Text("• \(item)").font(.caption)
                                        }
                                    }
                                }
                            } else {
                                Text("No analysis available").font(.caption).italic().foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(minHeight: 200)
                        .border(Color.primary, width: 1)
                        .offset(y: -1)
                    }
                }
                .padding(.bottom, 20)
                
                // Table 4: Action Plan
                Text("Next Action Plan:")
                    .font(.caption)
                    .bold()
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("Task").font(.caption).bold().padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        Divider().frame(width: 1.5).background(Color.primary)
                        Text("Responsible Person").font(.caption).bold().padding(8).frame(width: 120, alignment: .leading)
                        Divider().frame(width: 1.5).background(Color.primary)
                        Text("Deadline").font(.caption).bold().padding(8).frame(width: 80, alignment: .leading)
                    }
                    .background(Color.primary.opacity(0.1))
                    .border(Color.primary, width: 1.5)
                    
                    // Rows
                    ForEach(mom.actionItems) { item in
                        HStack(spacing: 0) {
                            Text(item.task).font(.caption).padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            Divider().frame(width: 1).background(Color.primary)
                            Text(item.person).font(.caption).padding(8).frame(width: 120, alignment: .leading)
                            Divider().frame(width: 1).background(Color.primary)
                            Text(item.deadline.formatted(date: .numeric, time: .omitted)).font(.caption).padding(8).frame(width: 80, alignment: .leading)
                        }
                        .border(Color.primary, width: 1)
                        .offset(y: -1)
                    }
                }
                .padding(.bottom, 20)
                
                // Footer
                HStack {
                    Text("Generated on \(mom.createdAt.formatted(date: .numeric, time: .omitted))")
                    Spacer()
                    Text("Page 1 of 1")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(16)
        }
    }
    
    // Helper Row
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.caption)
                .bold()
                .padding(8)
                .frame(width: 140, alignment: .leading)
                .background(Color.primary.opacity(0.1))
            
            Divider().background(Color.primary)
            
            Text(value)
                .font(.caption)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Speech Manager
class SpeechManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isRecording = false
    
    func start(completion: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async {
                if self.audioEngine.isRunning {
                    self.stop()
                } else {
                    self.startRecording(completion: completion)
                }
            }
        }
    }
    
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isRecording = false
        }
    }
    
    private func startRecording(completion: @escaping (String) -> Void) {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                completion(result.bestTranscription.formattedString)
            }
            if error != nil || (result?.isFinal ?? false) {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true
    }
}

struct MicTextField: View {
    var title: String
    @Binding var text: String
    var axis: Axis = .horizontal
    @StateObject private var speechManager = SpeechManager()
    
    var body: some View {
        HStack {
            if axis == .vertical {
                TextField(title, text: $text, axis: .vertical)
                    .lineLimit(3...6)
            } else {
                TextField(title, text: $text)
            }
            
            Button(action: {
                if speechManager.isRecording {
                    speechManager.stop()
                } else {
                    let initialText = text
                    speechManager.start { newText in
                        if !initialText.isEmpty {
                            text = initialText + " " + newText
                        } else {
                            text = newText
                        }
                    }
                }
            }) {
                Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                    .foregroundColor(speechManager.isRecording ? .red : .gray)
                    .padding(8)
                    .background(speechManager.isRecording ? Color.red.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - PDF Renderer
class MOMPDFRenderer {
    func render(mom: MOMDocument) -> URL? {
        let html = generateHTML(mom: mom)
        let fmt = UIMarkupTextPrintFormatter(markupText: html)
        
        let render = UIPrintPageRenderer()
        render.addPrintFormatter(fmt, startingAtPageAt: 0)
        
        // A4 Paper Size (595.2 x 841.8 points)
        let paperRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let printableRect = paperRect.insetBy(dx: 36, dy: 36) // 0.5 inch margins
        
        render.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        render.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        
        for i in 0..<render.numberOfPages {
            UIGraphicsBeginPDFPage()
            render.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        
        UIGraphicsEndPDFContext()
        
        // Sanitize filename
        let safeProjectName = mom.projectName.components(separatedBy: .init(charactersIn: "\\/:*?\"<>|")).joined()
        let fileName = "MOM_\(safeProjectName)_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: url)
            return url
        } catch {
            print("PDF Write Error: \(error)")
            return nil
        }
    }
    
    private func generateHTML(mom: MOMDocument) -> String {
        let dateStr = mom.date.formatted(date: .long, time: .omitted)
        let startStr = mom.startTime.formatted(date: .omitted, time: .shortened)
        let endStr = mom.endTime.formatted(date: .omitted, time: .shortened)
        
        return """
        <html>
        <head>
            <style>
                body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; padding: 20px; color: #333; }
                h1 { color: #5B3FD3; border-bottom: 2px solid #5B3FD3; padding-bottom: 10px; }
                h2 { margin-top: 0; color: #444; }
                .meta { margin-bottom: 20px; background: #f9f9f9; padding: 15px; border-radius: 8px; }
                .meta p { margin: 5px 0; }
                .section { margin-top: 30px; }
                .section-title { font-size: 18px; font-weight: bold; color: #5B3FD3; margin-bottom: 10px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
                ul { padding-left: 20px; }
                li { margin-bottom: 5px; }
                table { width: 100%; border-collapse: collapse; margin-top: 10px; }
                th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
                th { background-color: #f2f2f2; }
                .note { font-size: 12px; color: #666; font-style: italic; margin-top: 50px; }
            </style>
        </head>
        <body>
            <h1>Minutes of Meeting</h1>
            
            <div class="meta">
                <h2>\(mom.projectName)</h2>
                <p><strong>Date:</strong> \(dateStr) | <strong>Time:</strong> \(startStr) - \(endStr)</p>
                <p><strong>Venue:</strong> \(mom.venue)</p>
                <p><strong>Prepared By:</strong> \(mom.preparedBy)</p>
            </div>
            
            <div class="section">
                <div class="section-title">Attendees</div>
                <p><strong>Internal:</strong> \(mom.internalAttendees.joined(separator: ", "))</p>
                <p><strong>External:</strong> \(mom.externalAttendees)</p>
            </div>
            
            <div class="section">
                <div class="section-title">Agenda</div>
                <ul>
                    \(mom.agenda.map { "<li>\($0)</li>" }.joined())
                </ul>
            </div>
            
            <div class="section">
                <div class="section-title">Discussion Points</div>
                \(mom.discussionPoints.map { point in
                    """
                    <div style="margin-bottom: 15px;">
                        <strong>\(point.topic)</strong>
                        <br>
                        <span style="white-space: pre-wrap;">\(point.notes)</span>
                    </div>
                    """
                }.joined())
            </div>
        
            <div class="section">
                <div class="section-title">Action Items</div>
                <table>
                    <tr>
                        <th>Task</th>
                        <th>Assigned To</th>
                        <th>Deadline</th>
                    </tr>
                    \(mom.actionItems.map { item in
                        """
                        <tr>
                            <td>\(item.task)</td>
                            <td>\(item.person)</td>
                            <td>\(item.deadline.formatted(date: .numeric, time: .omitted))</td>
                        </tr>
                        """
                    }.joined())
                </table>
            </div>
            
            <div class="section">
                <p class="note">Generated by Project Management App on \(Date().formatted())</p>
            </div>
        </body>
        </html>
        """
    }
}

struct MOMShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
