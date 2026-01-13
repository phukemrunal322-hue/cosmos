import SwiftUI

struct ManagerProjectsView: View {
    @State private var searchText: String = ""
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCompletedOnly: Bool = false
    @State private var isGridLayout: Bool = false
    @State private var isShowingAddProjectForm: Bool = false
    @State private var editingProject: Project? = nil
    
    // MARK: - Derived data
    private var projects: [Project] { firebaseService.projects }

    // Projects scoped to the logged-in manager: created by or assigned to this manager.
    // If no projects match the manager (for old data), fall back to showing all projects
    // so the table is never permanently empty.
    private var managerScopedProjects: [Project] {
        let allProjects = projects
        guard let managerNameRaw = authService.currentUser?.name
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !managerNameRaw.isEmpty else {
            return []
        }
        let managerLower = managerNameRaw.lowercased()
        let filteredForManager = allProjects.filter { project in
            let pmLower = project.projectManager?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let isManager = (pmLower == managerLower)
            let isAssigned = project.assignedEmployees.contains { name in
                name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == managerLower
            }
            return isManager || isAssigned
        }
        // Return filtered projects strictly; do not fallback to allProjects
        return filteredForManager
    }

// MARK: - Search Card (Card 1)
struct ManagerProjectsSearchCard: View {
    @Binding var searchText: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("e.g. Website Redesign or TechCorp or In Progress", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(10)
        }
        .padding(12)
        .background(.background)
        .cornerRadius(16)
    }
}

// MARK: - Actions Bar (Card 2)
struct ManagerProjectsActionBar: View {
    let showingCount: Int
    let completedCount: Int
    @Binding var isGridLayout: Bool
    @Binding var showCompletedOnly: Bool
    @Binding var isShowingAddProjectForm: Bool
    @Binding var editingProject: Project?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Text("Showing \(showingCount) records")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Button(action: { withAnimation { showCompletedOnly.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                        Text("View Completed (\(completedCount))")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(showCompletedOnly ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                    .foregroundColor(showCompletedOnly ? .green : .gray)
                    .cornerRadius(20)
                }

                HStack(spacing: 8) {
                    Button(action: { isGridLayout = false }) {
                        Image(systemName: "list.bullet")
                            .padding(8)
                            .background(isGridLayout ? Color.clear : Color.blue.opacity(0.12))
                            .foregroundColor(isGridLayout ? .gray : .blue)
                            .cornerRadius(8)
                    }
                    Button(action: { isGridLayout = true }) {
                        Image(systemName: "square.grid.2x2")
                            .padding(8)
                            .background(isGridLayout ? Color.blue.opacity(0.12) : Color.clear)
                            .foregroundColor(isGridLayout ? .blue : .gray)
                            .cornerRadius(8)
                    }
                }

                Button(action: {
                    editingProject = nil
                    isShowingAddProjectForm = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Project")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(22)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(12)
        .background(.background)
        .cornerRadius(16)
    }
}
    private var filteredProjects: [Project] {
        var base = managerScopedProjects
        if showCompletedOnly {
            base = base.filter { normalizedProgressPercentage($0.progress) >= 100 }
        }
        if searchText.isEmpty { return base }
        return base.filter { p in
            p.name.localizedCaseInsensitiveContains(searchText) ||
            p.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var totalProjects: Int { managerScopedProjects.count }
    private var completedProjectsCount: Int {
        managerScopedProjects.filter { normalizedProgressPercentage($0.progress) >= 100 }.count
    }
    private var inProgressProjectsCount: Int {
        managerScopedProjects.filter { let v = normalizedProgressPercentage($0.progress); return v > 0 && v < 100 }.count
    }
    private var notStartedProjectsCount: Int {
        managerScopedProjects.filter { normalizedProgressPercentage($0.progress) == 0 }.count
    }
    private var kanbanNotStartedProjects: [Project] {
        managerScopedProjects.filter { normalizedProgressPercentage($0.progress) == 0 }
    }
    private var kanbanInProgressProjects: [Project] {
        managerScopedProjects.filter {
            let v = normalizedProgressPercentage($0.progress)
            return v > 0 && v < 100
        }
    }
    private var kanbanCompletedProjects: [Project] {
        managerScopedProjects.filter { normalizedProgressPercentage($0.progress) >= 100 }
    }
    
    private func normalizedProgressPercentage(_ progress: Double) -> Int {
        if progress > 1 { return Int(progress) }
        return Int(progress * 100)
    }
    
    private func isSampleProject(_ project: Project) -> Bool {
        let trimmedName = project.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedName == "testorject" || trimmedName == "hi" || trimmedName == "testproject" || trimmedName == "cosmos" {
            return true
        }
        if trimmedName.contains("test") {
            return true
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header + Stats
            VStack(alignment: .leading, spacing: 12) {
                // Card 1: Search Bar
                ManagerProjectsSearchCard(searchText: $searchText)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colorScheme == .dark ? Color(white: 0.20) : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .gray.opacity(0.08), radius: 2, y: 1)
                
                // Stats Row: Total / Completed / In Progress / Not Started
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ManagerProjectsStatsCard(
                            title: "Total Projects",
                            value: totalProjects,
                            tint: .blue,
                            icon: "square.grid.2x2.fill"
                        )
                        ManagerProjectsStatsCard(
                            title: "Completed",
                            value: completedProjectsCount,
                            tint: .green,
                            icon: "checkmark.circle.fill"
                        )
                        ManagerProjectsStatsCard(
                            title: "In Progress",
                            value: inProgressProjectsCount,
                            tint: .orange,
                            icon: "clock.fill"
                        )
                        ManagerProjectsStatsCard(
                            title: "Not Started",
                            value: notStartedProjectsCount,
                            tint: .red,
                            icon: "flag.fill"
                        )
                    }
                    .padding(.horizontal, 2)
                }

                // Card 2: Actions Row
                ManagerProjectsActionBar(
                    showingCount: filteredProjects.count,
                    completedCount: completedProjectsCount,
                    isGridLayout: $isGridLayout,
                    showCompletedOnly: $showCompletedOnly,
                    isShowingAddProjectForm: $isShowingAddProjectForm,
                    editingProject: $editingProject
                )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colorScheme == .dark ? Color(white: 0.20) : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .gray.opacity(0.08), radius: 2, y: 1)
            }
            .padding()
            .background(.background)
            .shadow(color: .gray.opacity(0.08), radius: 2, y: 2)
            
            // Content
            if firebaseService.isLoading && projects.isEmpty {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5)
                    Text("Loading projects...").font(.subheadline).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = firebaseService.errorMessage, projects.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 50)).foregroundColor(.orange)
                    Text("Error").font(.headline)
                    Text(errorMessage).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
                    Button("Retry") { firebaseService.fetchProjects() }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isGridLayout {
                ScrollView {
                    ProjectKanbanBoard(
                        notStarted: kanbanNotStartedProjects,
                        inProgress: kanbanInProgressProjects,
                        completed: kanbanCompletedProjects
                    )
                    .padding()
                }
                .background(Color.gray.opacity(0.05))
            } else if filteredProjects.isEmpty {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Project List")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                Text("SR. NO.").font(.caption2).foregroundColor(.gray)
                                Text("Project Name").font(.caption2).foregroundColor(.gray)
                                Text("Client Name").font(.caption2).foregroundColor(.gray)
                                Text("Project Manager").font(.caption2).foregroundColor(.gray)
                                Text("Progress").font(.caption2).foregroundColor(.gray)
                                Text("Start Date").font(.caption2).foregroundColor(.gray)
                                Text("End Date").font(.caption2).foregroundColor(.gray)
                                Text("ACTIONS").font(.caption2).foregroundColor(.gray)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        Divider().padding(.horizontal, 12)
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.system(size: 44))
                                .foregroundColor(.gray)
                            Text("No Projects Found")
                                .font(.headline)
                            Text("No projects match the selected filters. Adjust your search or try resetting filters.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .padding(.vertical, 12)
                    }
                    .background(.background)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 2)
                    )
                    .shadow(color: .gray.opacity(0.08), radius: 6, y: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    ManagerProjectsTableView(
                        projects: filteredProjects,
                        onEdit: { project in
                            editingProject = project
                            isShowingAddProjectForm = true
                        },
                        onDelete: { project in
                            guard let documentId = project.documentId else { return }
                            firebaseService.deleteProject(documentId: documentId, completion: nil)
                        }
                    )
                    .padding()
                }
                .background(Color.gray.opacity(0.05))
            }
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            let name = authService.currentUser?.name
            firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email, userName: name)
            firebaseService.fetchEmployees()
            firebaseService.fetchClients()
        }
        .sheet(isPresented: $isShowingAddProjectForm) {
            AddProjectFormView(firebaseService: firebaseService, projectToEdit: editingProject)
        }
    }
}

struct ManagerProjectsTableView: View {
    let projects: [Project]
    let onEdit: (Project) -> Void
    let onDelete: (Project) -> Void
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Project List")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text("SR. NO.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)

                        Text("Project Name")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 180, alignment: .leading)

                        Text("Client Name")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 160, alignment: .leading)

                        Text("Project Manager")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 160, alignment: .leading)

                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 140, alignment: .leading)

                        Text("Start Date")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 100, alignment: .leading)

                        Text("End Date")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 100, alignment: .leading)

                        Text("ACTIONS")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 100, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.06))

                    Divider()

                    if !projects.isEmpty {
                        ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.subheadline)
                                    .frame(width: 60, alignment: .leading)

                                Text(project.name)
                                    .font(.subheadline)
                                    .frame(width: 180, alignment: .leading)

                                Text(project.clientName ?? "-")
                                    .font(.subheadline)
                                    .frame(width: 160, alignment: .leading)

                                Text(project.projectManager ?? "-")
                                    .font(.subheadline)
                                    .frame(width: 160, alignment: .leading)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(normalizedProgressPercentage(project.progress))%")
                                        .font(.caption)
                                    ProgressView(value: normalizedProgress(project.progress))
                                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                }
                                .frame(width: 140, alignment: .leading)

                                Text(dateFormatter.string(from: project.startDate))
                                    .font(.subheadline)
                                    .frame(width: 100, alignment: .leading)

                                Text(dateFormatter.string(from: project.endDate))
                                    .font(.subheadline)
                                    .frame(width: 100, alignment: .leading)

                                HStack(spacing: 8) {
                                    Button(action: { onEdit(project) }) {
                                        Image(systemName: "square.and.pencil")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Button(action: { onDelete(project) }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .frame(width: 100, alignment: .leading)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)

                            if project.id != projects.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(minWidth: 900, alignment: .leading)
            }
            .background(.background)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.08), radius: 3, y: 2)
        }
        .padding()
        .background(.background)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.25), lineWidth: 2)
        )
        .shadow(color: .gray.opacity(0.08), radius: 6, y: 2)
    }

    private func normalizedProgress(_ progress: Double) -> Double {
        if progress > 1 {
            return min(max(progress / 100.0, 0.0), 1.0)
        }
        return min(max(progress, 0.0), 1.0)
    }

    private func normalizedProgressPercentage(_ progress: Double) -> Int {
        if progress > 1 {
            return Int(progress)
        }
        return Int(normalizedProgress(progress) * 100)
    }
}

// MARK: - Manager Stats Tile
struct ManagerProjectsStatsCard: View {
    let title: String
    let value: Int
    let tint: Color
    let icon: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(tint)
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            Spacer()
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(tint)
            }
        }
        .padding(14)
        .background(.background)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color(white: 0.20) : Color.gray.opacity(0.45), lineWidth: 3)
        )
        .shadow(color: .gray.opacity(0.12), radius: 3, y: 2)
        .frame(width: 200)
    }
}

struct ProjectKanbanBoard: View {
    let notStarted: [Project]
    let inProgress: [Project]
    let completed: [Project]
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSevenStagePipeline = false

    private struct PipelineStage: Identifiable {
        let id = UUID()
        let name: String
        let level: Int
        let color: Color
    }

    private var pipelineStages: [PipelineStage] {
        [
            PipelineStage(name: "Diagnose", level: 1, color: Color.purple),
            PipelineStage(name: "Design Solution", level: 2, color: Color.blue),
            PipelineStage(name: "Roadmap", level: 3, color: Color.cyan),
            PipelineStage(name: "System Design", level: 4, color: Color.indigo),
            PipelineStage(name: "Implementation", level: 5, color: Color.orange),
            PipelineStage(name: "Monitor and Review and Optimization", level: 6, color: Color.green),
            PipelineStage(name: "Closure or Continuity", level: 7, color: Color.teal)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Project Kanban Board")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSevenStagePipeline.toggle()
                    }
                }) {
                    Text(isSevenStagePipeline ? "3-Stage Kanban" : "7-Stage Pipeline")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .foregroundColor(isSevenStagePipeline ? .blue : .primary)
                .background(
                    isSevenStagePipeline ? Color.blue.opacity(0.16) : Color.gray.opacity(0.12)
                )
                .cornerRadius(20)
                .buttonStyle(.plain)
            }
            
            if isSevenStagePipeline {
                // 7-stage pipeline layout
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pipeline Progress")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(pipelineStages) { stage in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stage.name)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                    Text("Level \(stage.level)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("0")
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                        .padding(.top, 4)
                                }
                                .padding(10)
                                .background(stage.color.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(stage.color.opacity(0.35), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(pipelineStages) { stage in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(stage.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Text("0")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Spacer(minLength: 0)
                                    
                                    VStack(alignment: .center, spacing: 4) {
                                        Image(systemName: "eye")
                                            .font(.caption)
                                            .foregroundColor(.gray.opacity(0.7))
                                        Text("No projects")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding()
                                .frame(width: 260, height: 130, alignment: .topLeading)
                                .background(stage.color.opacity(0.06))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(stage.color.opacity(0.4), lineWidth: 2)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                // 3-stage Kanban layout
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ProjectKanbanColumn(title: "Not Started", projects: notStarted, tint: Color.yellow)
                        ProjectKanbanColumn(title: "In Progress", projects: inProgress, tint: Color.blue)
                        ProjectKanbanColumn(title: "Completed", projects: completed, tint: Color.green)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color(white: 0.20) : Color.gray.opacity(0.25), lineWidth: 2)
        )
        .shadow(color: .gray.opacity(0.08), radius: 4, y: 2)
    }
}

struct ProjectKanbanColumn: View {
    let title: String
    let projects: [Project]
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(tint)
                Spacer()
                Text("\(projects.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if projects.isEmpty {
                    Text(emptyMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(projects) { project in
                        Text(project.name)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 230, alignment: .topLeading)
        .background(tint.opacity(0.08))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.4), lineWidth: 2)
        )
    }
    
    private var emptyMessage: String {
        switch title {
        case "Not Started":
            return "No projects in not started"
        case "In Progress":
            return "No projects in in progress"
        case "Completed":
            return "No projects in completed"
        default:
            return "No projects"
        }
    }
}
