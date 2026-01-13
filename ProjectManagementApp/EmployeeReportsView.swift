import SwiftUI

struct EmployeeReportsView: View {
    @ObservedObject var firebaseService: FirebaseService
    @ObservedObject var authService: FirebaseAuthService
    @Environment(\.dismiss) private var dismiss
    @State private var isExportingCSV: Bool = false
    @State private var csvURL: URL?
    
    private var tasks: [Task] {
        firebaseService.tasks
    }
    
    private var projects: [Project] {
        firebaseService.projects
    }
    
    private var totalTasks: Int {
        tasks.count
    }
    
    private var completedTasks: Int {
        tasks.filter { $0.status == .completed }.count
    }
    
    private var inProgressTasks: Int {
        tasks.filter { $0.status == .inProgress }.count
    }
    
    private var pendingTasks: Int {
        tasks.filter { $0.status == .notStarted }.count
    }
    
    private var overdueTasks: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return tasks.filter { task in
            let comparison = Calendar.current.compare(task.dueDate, to: today, toGranularity: .day)
            return comparison == .orderedAscending && task.status != .completed
        }.count
    }
    
    private var employeeProjects: [Project] {
        var projects = firebaseService.projects
        
        let currentEmail = authService.currentUser.map { user in
            user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } ?? ""
        let tasks = firebaseService.tasks
        
        var allowedDocumentIds = Set<String>()
        var allowedNames = Set<String>()
        for task in tasks {
            if let pid = task.project?.documentId, !pid.isEmpty {
                allowedDocumentIds.insert(pid)
            }
            let name = task.project?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if !name.isEmpty {
                allowedNames.insert(name)
            }
        }
        
        projects = projects.filter { project in
            var isAllowed = false
            if !currentEmail.isEmpty {
                if project.assignedEmployees.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == currentEmail }) {
                    isAllowed = true
                }
            }
            if let docId = project.documentId, allowedDocumentIds.contains(docId) {
                isAllowed = true
            }
            let projectNameLower = project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if allowedNames.contains(projectNameLower) {
                isAllowed = true
            }
            return isAllowed
        }
        
        // Match "My Projects" default view which shows only in-progress projects (< 100%)
        projects = projects.filter { normalizedProgress($0.progress) < 1.0 }
        
        return projects
    }
    
    private var completionRate: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(completedTasks) / Double(totalTasks)
    }
    
    private var uniqueProjectsCount: Int {
        employeeProjects.count
    }
    
    private var completedProjectsCount: Int {
        employeeProjects.filter { normalizedProgress($0.progress) >= 1.0 }.count
    }
    
    private var inProgressProjectsCount: Int {
        employeeProjects.filter {
            let p = normalizedProgress($0.progress)
            return p > 0.0 && p < 1.0
        }.count
    }
    
    private var pendingProjectsCount: Int {
        employeeProjects.filter { normalizedProgress($0.progress) == 0.0 }.count
    }
    
    private var highPriorityTasks: [Task] {
        tasks.filter { $0.priority == .p1 }
    }
    
    private var mediumPriorityTasks: [Task] {
        tasks.filter { $0.priority == .p2 }
    }
    
    private var lowPriorityTasks: [Task] {
        tasks.filter { $0.priority == .p3 }
    }
    
    // Column totals for Activity Summary header (sum of all rows shown in table)
    private var activityTotalColumnSum: Int {
        uniqueProjectsCount + totalTasks + highPriorityTasks.count
    }
    
    private var activityCompletedColumnSum: Int {
        let highCompleted = highPriorityTasks.filter { $0.status == .completed }.count
        return completedProjectsCount + completedTasks + highCompleted
    }
    
    private var activityInProgressColumnSum: Int {
        let highInProgress = highPriorityTasks.filter { $0.status == .inProgress }.count
        return inProgressProjectsCount + inProgressTasks + highInProgress
    }
    
    private var activityPendingColumnSum: Int {
        let highPending = highPriorityTasks.filter { $0.status == .notStarted }.count
        return pendingProjectsCount + pendingTasks + highPending
    }
    
    private func ratio(_ part: Int, of total: Int) -> Double {
        guard total > 0 else { return 0.0 }
        return Double(part) / Double(total)
    }
    
    private func normalizedProgress(_ value: Double) -> Double {
        if value > 1 { return min(max(value, 0), 100) / 100.0 }
        return max(0.0, min(1.0, value))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    topStatsSection
                    completionSection
                    prioritySection
                    activitySummarySection
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Reports & Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Export CSV") {
                        generateCSVAndShare()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            firebaseService.fetchProjects()
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email)
        }
        .sheet(isPresented: $isExportingCSV, onDismiss: {
            csvURL = nil
        }) {
            if let url = csvURL {
                ReportShareSheet(activityItems: [url])
            } else {
                Text("Preparing export...")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reports & Analytics")
                .font(.title2)
                .fontWeight(.bold)
            Text("Overview of your performance and task statistics")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var topStatsSection: some View {
        HStack(spacing: 12) {
            MetricCard(title: "Total Projects", value: "\(uniqueProjectsCount)", icon: "square.grid.2x2.fill", color: Color.blue.opacity(0.15), accent: .blue)
            MetricCard(title: "Total Tasks", value: "\(totalTasks)", icon: "list.bullet.rectangle.fill", color: Color.purple.opacity(0.15), accent: .purple)
            MetricCard(title: "Completed", value: "\(completedTasks)", icon: "checkmark.circle.fill", color: Color.green.opacity(0.15), accent: .green)
            MetricCard(title: "Overdue", value: "\(overdueTasks)", icon: "clock.badge.exclamationmark", color: Color.red.opacity(0.15), accent: .red)
        }
    }
    
    private var completionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Completion Rate")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.1f%%", completionRate * 100))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                
                ProgressView(value: completionRate)
                    .tint(.purple)
                    .frame(height: 8)
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                CompletionStatCard(title: "Done", value: completedTasks, color: .green)
                CompletionStatCard(title: "In Progress", value: inProgressTasks, color: .orange)
                CompletionStatCard(title: "To-Do", value: pendingTasks, color: .yellow)
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tasks by Priority")
                .font(.headline)
                .fontWeight(.semibold)
            
            PriorityRow(title: "High Priority", color: .red, tasks: highPriorityTasks, total: totalTasks)
            PriorityRow(title: "Medium Priority", color: .orange, tasks: mediumPriorityTasks, total: totalTasks)
            PriorityRow(title: "Low Priority", color: .green, tasks: lowPriorityTasks, total: totalTasks)
        }
        .padding()
        .background(.background)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var activitySummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Header row with column totals
                    HStack(spacing: 0) {
                        Text("Category")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(minWidth: 140, alignment: .leading)
                        Text("Total (\(activityTotalColumnSum))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: 80, alignment: .trailing)
                        Text("Completed (\(activityCompletedColumnSum))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: 110, alignment: .trailing)
                        Text("In Progress (\(activityInProgressColumnSum))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: 120, alignment: .trailing)
                        Text("Pending (\(activityPendingColumnSum))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    
                    Divider()
                        .padding(.leading, 12)
                    
                    // Data rows (full-width, horizontally scrollable)
                    VStack(spacing: 0) {
                        ActivityRow(title: "Projects", total: uniqueProjectsCount, completed: completedProjectsCount, inProgress: inProgressProjectsCount, pending: pendingProjectsCount)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        Divider().padding(.leading, 12)
                        ActivityRow(title: "Tasks", total: totalTasks, completed: completedTasks, inProgress: inProgressTasks, pending: pendingTasks)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        Divider().padding(.leading, 12)
                        ActivityRow(title: "High Priority", total: highPriorityTasks.count, completed: highPriorityTasks.filter { $0.status == .completed }.count, inProgress: highPriorityTasks.filter { $0.status == .inProgress }.count, pending: highPriorityTasks.filter { $0.status == .notStarted }.count)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .background(.background)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.12), radius: 6, x: 0, y: 3)
    }

    private func generateCSVAndShare() {
        var rows: [[String]] = []
        rows.append(["Category", "Total", "Completed", "In Progress", "Pending"])
        rows.append([
            "Projects",
            "\(uniqueProjectsCount)",
            "\(completedProjectsCount)",
            "\(inProgressProjectsCount)",
            "\(pendingProjectsCount)"
        ])
        rows.append([
            "Tasks",
            "\(totalTasks)",
            "\(completedTasks)",
            "\(inProgressTasks)",
            "\(pendingTasks)"
        ])
        let highCompleted = highPriorityTasks.filter { $0.status == .completed }.count
        let highInProgress = highPriorityTasks.filter { $0.status == .inProgress }.count
        let highPending = highPriorityTasks.filter { $0.status == .notStarted }.count
        rows.append([
            "High Priority",
            "\(highPriorityTasks.count)",
            "\(highCompleted)",
            "\(highInProgress)",
            "\(highPending)"
        ])

        let csvString = rows.map { $0.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") }.joined(separator: "\n")

        do {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            let fileURL = documentsDir.appendingPathComponent("ActivitySummary.csv")
            try csvString.data(using: .utf8)?.write(to: fileURL, options: .atomic)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            print("Error writing CSV: \(error.localizedDescription)")
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(accent)
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color)
        .cornerRadius(14)
    }
}

struct CompletionStatCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PriorityRow: View {
    let title: String
    let color: Color
    let tasks: [Task]
    let total: Int
    
    private var ratio: Double {
        guard total > 0 else { return 0.0 }
        return Double(tasks.count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(tasks.count) tasks")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: CGFloat(ratio) * geometry.size.width, height: 6)
                }
            }
            .frame(height: 10)
        }
    }
}

struct ActivityRow: View {
    let title: String
    let total: Int
    let completed: Int?
    let inProgress: Int?
    let pending: Int?
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(total)")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 80, alignment: .trailing)
            Text(completed.map { "\($0)" } ?? "-")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 110, alignment: .trailing)
            Text(inProgress.map { "\($0)" } ?? "-")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 120, alignment: .trailing)
            Text(pending.map { "\($0)" } ?? "-")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 100, alignment: .trailing)
        }
    }
}
