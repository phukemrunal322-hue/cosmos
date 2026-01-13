import SwiftUI
import FirebaseFirestore

struct SubtaskListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    let taskId: String
    let taskTitle: String
    @State private var subtasks: [SubTaskItem] = []
    @State private var subtaskListener: ListenerRegistration?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if subtasks.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.3))
                                
                                Text("No Subtasks")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                Text("Add subtasks to break down this task")
                                    .font(.subheadline)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
                                SubtaskCard(
                                    index: index + 1,
                                    subtask: subtask,
                                    onToggle: {
                                        toggleSubtask(subtask)
                                    },
                                    onDelete: {
                                        deleteSubtask(subtask)
                                    }
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Subtask Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            fetchSubtasks()
        }
        .onDisappear {
            subtaskListener?.remove()
        }
    }
    
    private func fetchSubtasks() {
        if let listener = subtaskListener { listener.remove() }
        
        subtaskListener = firebaseService.listenToSubtasks(taskId: taskId) { items in
            self.subtasks = items
        }
    }
    
    private func toggleSubtask(_ subtask: SubTaskItem) {
        let updated = SubTaskItem(
            id: subtask.id,
            title: subtask.title,
            isCompleted: !subtask.isCompleted,
            createdAt: subtask.createdAt,
            assignedTo: subtask.assignedTo
        )
        
        firebaseService.updateSubtask(taskId: taskId, subtask: updated) { error in
            if error == nil {
                let action = updated.isCompleted ? "completed subtask" : "uncompleted subtask"
                let activity = ActivityItem(user: "Super Admin", action: action, message: subtask.title, type: "subtask")
                firebaseService.addTaskActivity(taskId: taskId, activity: activity) { _ in }
            }
        }
    }
    
    private func deleteSubtask(_ subtask: SubTaskItem) {
        firebaseService.deleteSubtask(taskId: taskId, subtaskId: subtask.id) { error in
            if error == nil {
                let activity = ActivityItem(user: "Super Admin", action: "removed subtask", message: subtask.title, type: "subtask")
                firebaseService.addTaskActivity(taskId: taskId, activity: activity) { _ in }
            }
        }
    }
}

struct SubtaskCard: View {
    let index: Int
    let subtask: SubTaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Subtask")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            // Subtask Title
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Button(action: onToggle) {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(subtask.isCompleted ? .green : .gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subtask.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .strikethrough(subtask.isCompleted)
                        
                        if let assignee = subtask.assignedTo, !assignee.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                Text(assignee)
                                    .font(.caption)
                            }
                            .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            Divider()
            
            // Status Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Text(subtask.isCompleted ? "TODO" : "TODO")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            
            // Metadata
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(subtask.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(subtask.isCompleted ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(subtask.isCompleted ? "Completed" : "Pending")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .alert("Delete Subtask", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this subtask?")
        }
    }
}
