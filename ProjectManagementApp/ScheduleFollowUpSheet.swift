import SwiftUI
import FirebaseFirestore

struct ScheduleFollowUpSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var firebaseService: FirebaseService
    var selectedLead: Lead? = nil
    
    // Internal state for the form
    @State private var leadId: String = ""
    @State private var followUpType: String = "Phone Call"
    @State private var followUpDate = Date()
    @State private var followUpTime = Date()
    @State private var priority: String = "Medium"
    @State private var notes: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    // Derived date with time
    var combinedDate: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: followUpDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: followUpTime)
        
        return calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute
        )) ?? Date()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Header with Icon
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .padding(10)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schedule New Follow-Up")
                            .font(.headline)
                        Text("Create a new follow-up reminder")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Lead Selection Row
                        HStack(alignment: .top, spacing: 16) {
                            // Select Lead
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Select Lead", systemImage: "person.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                
                                Menu {
                                    ForEach(firebaseService.leads) { lead in
                                        Button(action: { leadId = lead.documentId ?? "" }) {
                                            if leadId == lead.documentId {
                                                Label(lead.name, systemImage: "checkmark")
                                            } else {
                                                Text(lead.name)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedLeadName)
                                            .foregroundColor(leadId.isEmpty ? .gray : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                Text("\(firebaseService.leads.count) leads available")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Follow-Up Type
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Follow-Up Type", systemImage: "phone.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                
                                Menu {
                                    ForEach(firebaseService.leadFollowUpTypes, id: \.self) { type in
                                        Button(type) { followUpType = type }
                                    }
                                } label: {
                                    HStack {
                                        Text(followUpType)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Date & Time Row
                        HStack(spacing: 16) {
                            // Date
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Date", systemImage: "calendar")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                
                                DatePicker("", selection: $followUpDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Time
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Time", systemImage: "clock.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                
                                DatePicker("", selection: $followUpTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        
                        // Priority & Notes
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Priority", systemImage: "flag.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                
                                Picker("Priority", selection: $priority) {
                                    Text("High").tag("High")
                                    Text("Medium").tag("Medium")
                                    Text("Low").tag("Low")
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Notes", systemImage: "square.and.pencil")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                
                                TextEditor(text: $notes)
                                    .frame(height: 100)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(24)
                }
                .background(Color(.systemGray6))
                
                // Footer Buttons
                HStack(spacing: 16) {
                    Button(action: scheduleFollowUp) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Schedule Follow-Up")
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.purple : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isSubmitting)
                    
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            if let lead = selectedLead {
                leadId = lead.documentId ?? ""
            }
        }
    }
    
    var selectedLeadName: String {
        if let lead = firebaseService.leads.first(where: { $0.documentId == leadId }) {
            return "\(lead.name) (\(lead.companyName ?? "Unknown"))"
        }
        return "Select a Lead"
    }
    
    var isFormValid: Bool {
        return !leadId.isEmpty
    }
    
    func scheduleFollowUp() {
        guard isFormValid else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        // 1. Update the Lead document with the new follow-up date
        let updateData: [String: Any] = [
            "followUpDate": Timestamp(date: combinedDate),
            "followUpType": followUpType, // Optional: Store type if needed in lead
            "notes": notes // Optional: Append or replace notes
        ]
        
        // 2. Also log this as an 'Activity' or 'Interaction' if you have a separate collection
        // For now, we'll just update the lead as that's the primary request "connected to db"
        
        firebaseService.updateLead(documentId: leadId, data: updateData) { error in
            isSubmitting = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                dismiss()
            }
        }
    }
}
