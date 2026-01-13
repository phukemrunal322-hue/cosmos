import SwiftUI

struct DayDetailsView: View {
    let date: Date
    @Environment(\.dismiss) var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var editingMeeting: Meeting?
    
    // Simple calendar logic just to parse date
    private let calendar = Calendar.current
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Stats or Summary?
                // Just listing events for now as per request.
                
                let events = eventsForDate(date)
                
                if events.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No events or tasks for this day")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(events) { event in
                            if let meeting = event.meeting {
                                AdminEventDetailView(
                                    event: meeting,
                                    onEdit: {
                                        self.editingMeeting = meeting
                                    },
                                    onDelete: {
                                        if let docId = meeting.documentId {
                                            firebaseService.deleteEvent(documentId: docId) { _ in }
                                        }
                                    }
                                )
                            } else if let task = event.task {
                                // Task Card
                                TaskDetailCard(task: task)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
        .navigationTitle(date.formatted(date: .complete, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingMeeting) { meeting in
            AdminCreateMeetingView(meetingToEdit: meeting)
        }
    }
    
    // Internal struct for display
    struct DetailEvent: Identifiable {
        let id = UUID()
        let meeting: Meeting?
        let task: Task?
    }
    
    private func eventsForDate(_ date: Date) -> [DetailEvent] {
        var results: [DetailEvent] = []
        
        // Filter Meetings
        let meetings = firebaseService.events.filter { calendar.isDate($0.date, inSameDayAs: date) }
        for m in meetings {
            results.append(DetailEvent(meeting: m, task: nil))
        }
        
        // Filter Tasks
        let tasks = firebaseService.tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }
        for t in tasks {
            results.append(DetailEvent(meeting: nil, task: t))
        }
        
        return results
    }
}

// Simple Task Card for reuse or we could define it here
struct TaskDetailCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TASK")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(task.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(task.title)
                .font(.headline)
            
            if !task.assignedTo.isEmpty {
                Text("Assigned to: \(task.assignedTo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
