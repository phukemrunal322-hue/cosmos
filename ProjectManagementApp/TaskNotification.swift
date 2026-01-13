import SwiftUI
import Foundation
import Combine

// Task Notification Model
struct TaskNotification: Identifiable {
    let id = UUID()
    let taskTitle: String
    let taskDescription: String
    let dueDate: Date
    let priority: Priority
    let type: NotificationType
    let createdAt: Date
    var isRead: Bool = false
    
    enum NotificationType: String {
        case taskAssigned = "New Task Assigned"
        case taskDueSoon = "Task Due Soon"
        case taskOverdue = "Task Overdue"
        case taskCompleted = "Task Completed"
        case taskUpdated = "Task Updated"
        
        var icon: String {
            switch self {
            case .taskAssigned: return "bell.badge"
            case .taskDueSoon: return "clock.badge.exclamationmark"
            case .taskOverdue: return "exclamationmark.triangle"
            case .taskCompleted: return "checkmark.circle"
            case .taskUpdated: return "arrow.triangle.2.circlepath"
            }
        }
        
        var color: Color {
            switch self {
            case .taskAssigned: return .blue
            case .taskDueSoon: return .orange
            case .taskOverdue: return .red
            case .taskCompleted: return .green
            case .taskUpdated: return .purple
            }
        }
    }
}

// Notification Manager - Observable Object to manage notifications
class NotificationManager: ObservableObject {
    @Published var notifications: [TaskNotification] = []
    private var cancellables = Set<AnyCancellable>()
    private let firebaseService = FirebaseService.shared
    private let authService = FirebaseAuthService.shared
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    init() {
        startListeningForOverdueTasks()
    }
    
    private func startListeningForOverdueTasks() {
        let uid = authService.currentUid
        let email = authService.currentUser?.email
        // Ensure tasks listener is active for the current user
        firebaseService.fetchTasks(forUserUid: uid, userEmail: email)
        
        firebaseService.$tasks
            .receive(on: RunLoop.main)
            .sink { [weak self] tasks in
                self?.updateNotifications(from: tasks)
            }
            .store(in: &cancellables)
    }
    
    private func updateNotifications(from tasks: [Task]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Overdue = due date strictly before today and not completed
        let overdueTasks = tasks.filter { task in
            guard task.status != .completed else { return false }
            let taskDay = calendar.startOfDay(for: task.dueDate)
            return taskDay < today
        }
        .sorted { $0.dueDate > $1.dueDate }
        
        // Map to TaskNotification; keep existing read state where possible
        var newNotifications: [TaskNotification] = []
        for task in overdueTasks {
            let existing = notifications.first { $0.taskTitle == task.title && calendar.isDate($0.dueDate, inSameDayAs: task.dueDate) }
            let isRead = existing?.isRead ?? false
            let notif = TaskNotification(
                taskTitle: task.title,
                taskDescription: task.description,
                dueDate: task.dueDate,
                priority: task.priority,
                type: .taskOverdue,
                createdAt: task.dueDate,
                isRead: isRead
            )
            newNotifications.append(notif)
        }
        notifications = newNotifications
    }
    
    func markAsRead(_ notification: TaskNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
    }
    
    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
    }
    
    func deleteNotification(_ notification: TaskNotification) {
        notifications.removeAll { $0.id == notification.id }
    }
    
    func addNotification(_ notification: TaskNotification) {
        notifications.insert(notification, at: 0)
    }
}

// Notification Bell Icon View
struct NotificationBellIcon: View {
    @ObservedObject var notificationManager: NotificationManager
    @Binding var showNotifications: Bool
    
    var body: some View {
        Button(action: {
            showNotifications = true
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                if notificationManager.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 18, height: 18)
                        
                        Text("\(notificationManager.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: -8)
                }
            }
        }
    }
}

// Notifications List View
struct NotificationsView: View {
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.05).ignoresSafeArea()
                
                if notificationManager.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Notifications")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notificationManager.notifications) { notification in
                                NotificationCard(
                                    notification: notification,
                                    onMarkAsRead: {
                                        notificationManager.markAsRead(notification)
                                    },
                                    onDelete: {
                                        notificationManager.deleteNotification(notification)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if notificationManager.unreadCount > 0 {
                        Button("Mark All Read") {
                            notificationManager.markAllAsRead()
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}

// Notification Card
struct NotificationCard: View {
    let notification: TaskNotification
    let onMarkAsRead: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: notification.type.icon)
                    .font(.title3)
                    .foregroundColor(notification.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.type.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(notification.type.color)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.taskTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(notification.taskDescription)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Label(
                        notification.dueDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )
                    .font(.caption2)
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(timeAgo(from: notification.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(
            notification.isRead
            ? Color(.secondarySystemBackground)
            : Color.blue.opacity(0.05)
        )
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
        .contextMenu {
            if !notification.isRead {
                Button(action: onMarkAsRead) {
                    Label("Mark as Read", systemImage: "checkmark")
                }
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
