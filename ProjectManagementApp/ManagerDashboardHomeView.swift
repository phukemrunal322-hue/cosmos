import SwiftUI

struct ManagerDashboardHomeView: View {
    @Binding var showDailyReportForm: Bool
    var onSelectProject: ((UUID) -> Void)? = nil
    var onSeeAllTasks: (() -> Void)? = nil
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    private var projectsCount: Int { firebaseService.projects.count }
    private var teamMembersCount: Int {
        let allAssigned = firebaseService.projects.flatMap { $0.assignedEmployees }
        return Set(allAssigned).count
    }
    private var totalTasksCount: Int { firebaseService.tasks.count }
    private var overdueTasksCount: Int {
        let cal = Calendar.current
        return firebaseService.tasks.filter { t in
            t.status != .completed && cal.compare(t.dueDate, to: Date(), toGranularity: .day) == .orderedAscending
        }.count
    }
    private var completedProjectsCount: Int {
        firebaseService.projects.filter { normalizedProgressPercentage($0.progress) >= 100 }.count
    }
    private var inProgressTasksCount: Int { firebaseService.tasks.filter { $0.status == .inProgress }.count }
    
    private func normalizedProgressPercentage(_ progress: Double) -> Int {
        if progress > 1 { return Int(progress) }
        return Int(progress * 100)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                WelcomeCard()
                
                ManagerStatsOverview(
                    projectsCount: projectsCount,
                    teamMembersCount: teamMembersCount,
                    totalTasksCount: totalTasksCount,
                    overdueTasksCount: overdueTasksCount,
                    completedProjectsCount: completedProjectsCount,
                    inProgressTasksCount: inProgressTasksCount
                )
                
                ManagerProjectProgressSection(projects: firebaseService.projects)
                ManagerUpcomingDeadlinesSection(tasks: firebaseService.tasks)
                ManagerTeamOverviewSection(projects: firebaseService.projects, employees: firebaseService.employees)
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            let name = authService.currentUser?.name
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email, userName: name)
            firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email, userName: name)
            if firebaseService.employees.isEmpty { firebaseService.fetchEmployees() }
            firebaseService.listenTaskStatusOptions()
        }
    }
}

struct ManagerStatsOverview: View {
    let projectsCount: Int
    let teamMembersCount: Int
    let totalTasksCount: Int
    let overdueTasksCount: Int
    let completedProjectsCount: Int
    let inProgressTasksCount: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ManagerStatCard(
                    title: "My Projects",
                    value: "\(projectsCount)",
                    subtitle: "\(completedProjectsCount) completed",
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    iconColor: Color.purple
                )
                ManagerStatCard(
                    title: "Team Members",
                    value: "\(teamMembersCount)",
                    subtitle: "Across all projects",
                    icon: "person.3.fill",
                    iconColor: Color.green
                )
                ManagerStatCard(
                    title: "Total Tasks",
                    value: "\(totalTasksCount)",
                    subtitle: "\(inProgressTasksCount) in progress",
                    icon: "list.bullet.rectangle.fill",
                    iconColor: Color.blue
                )
                ManagerStatCard(
                    title: "Overdue Tasks",
                    value: "\(overdueTasksCount)",
                    subtitle: "Need attention",
                    icon: "exclamationmark.triangle.fill",
                    iconColor: Color.gray
                )
            }
            .padding(.horizontal)
        }
    }
}

struct ManagerStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(iconColor)
            }
        }
        .padding(14)
        .background(.background)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.15), radius: 5, x: 0, y: 3)
    }
}

struct ManagerSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            content
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct ManagerProjectProgressSection: View {
    let projects: [Project]
    
    private func normalized(_ progress: Double) -> Int {
        if progress > 1 { return Int(progress) }
        return Int(progress * 100)
    }
    
    var body: some View {
        ManagerSectionCard(title: "Project Progress") {
            if projects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No projects assigned yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 20) {
                    ForEach(projects.prefix(4)) { project in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(project.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(normalized(project.progress))%")
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            GeometryReader { geom in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.blue, .purple]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(0, geom.size.width * CGFloat(normalized(project.progress)) / 100.0), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    if projects.count > 4 {
                        Divider()
                        HStack {
                            Spacer()
                            Text("+\(projects.count - 4) more projects")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }
}

struct ManagerUpcomingDeadlinesSection: View {
    let tasks: [Task]
    
    private var upcoming: [Task] {
        let cal = Calendar.current
        return tasks.filter { t in
            t.status != .completed &&
            cal.compare(t.dueDate, to: Date(), toGranularity: .day) != .orderedAscending &&
            ((cal.dateComponents([.day], from: Date(), to: t.dueDate).day) ?? 999) <= 7
        }
        .sorted { $0.dueDate < $1.dueDate }
    }
    
    var body: some View {
        ManagerSectionCard(title: "Upcoming Deadlines (Next 7 Days)") {
            if upcoming.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green.opacity(0.6))
                    Text("No upcoming deadlines!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 16) {
                    ForEach(upcoming.prefix(4)) { task in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "calendar")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 18))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                if let pname = task.project?.name, !pname.isEmpty {
                                    Text(pname)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(task.dueDate, style: .date)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                if task.priority == .p3 { // High
                                    Text("High Priority")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ManagerTeamOverviewSection: View {
    let projects: [Project]
    let employees: [EmployeeProfile]
    
    private var teamMembers: [EmployeeProfile] {
        // Collect all assigned emails and names from projects
        let assignedEmails = Set(projects.flatMap { $0.assignedEmployees.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() } })
        // Check both email and name fields as fallback
        
        return employees.filter { emp in
            let email = emp.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let name = emp.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            // Match if employee email is in assigned list OR if employee name is in assigned list
            return assignedEmails.contains(email) || assignedEmails.contains(name)
        }
    }
    
    private var uniqueAssignedCount: Int {
         Set(projects.flatMap { $0.assignedEmployees }).count
    }
    
    var body: some View {
        ManagerSectionCard(title: "Team Overview") {
            if projects.isEmpty || uniqueAssignedCount == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No team members assigned to your projects yet.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Active Projects")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(projects.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Team Members")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(uniqueAssignedCount)")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    if !teamMembers.isEmpty {
                        Text("Members")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.top, 4)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(teamMembers) { member in
                                    VStack(spacing: 8) {
                                        if let urlStart = member.profileImageURL, let url = URL(string: urlStart) {
                                            AsyncImage(url: url) { phase in
                                                if let image = phase.image {
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                } else {
                                                    Color.gray.opacity(0.2)
                                                }
                                            }
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Text(member.name.prefix(1).uppercased())
                                                        .font(.title3)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.blue)
                                                )
                                        }
                                        
                                        Text(member.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .frame(width: 70)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else if uniqueAssignedCount > 0 {
                         // Fallback if profiles not loaded but assignments exist in DB (e.g. emails don't match exactly or employee list not fetched)
                         Text("Team details loading...")
                             .font(.caption)
                             .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}
