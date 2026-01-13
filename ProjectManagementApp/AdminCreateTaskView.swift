import SwiftUI

struct AdminCreateTaskView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    
    // We can wrap the existing CreateTaskView
    var body: some View {
        CreateTaskView(
            taskType: .adminTask,
            projects: firebaseService.projects,
            onSave: { newTaskData in
                // Convert to Task object
                let newTask = Task(
                    title: newTaskData.title,
                    description: newTaskData.description,
                    status: newTaskData.status,
                    priority: newTaskData.priority,
                    startDate: newTaskData.assignedDate,
                    dueDate: newTaskData.dueDate,
                    assignedTo: "", // Will be filled by service or UI logic if needed
                    comments: [],
                    department: nil,
                    project: newTaskData.project,
                    taskType: .adminTask,
                    isRecurring: newTaskData.isRecurring,
                    recurringPattern: newTaskData.recurringPattern,
                    recurringDays: newTaskData.recurringDays,
                    recurringEndDate: newTaskData.recurringEndDate,
                    subtask: newTaskData.subtask,
                    weightage: newTaskData.weightage,
                    subtaskStatus: nil
                )
                
                // Handle saving via FirebaseService
                firebaseService.createTask(newTask, assignedUid: nil, assignedEmail: nil) { success in
                    if success {
                        dismiss()
                    }
                }
            }
        )
    }
}
