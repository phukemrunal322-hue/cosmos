import SwiftUI

struct ManageProjectsView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var searchText = ""
    @State private var showingAddProject = false
    @State private var selectedProject: Project?
    @State private var projectToEdit: Project?
    @State private var projectToDelete: Project?
    @State private var showingDeleteAlert = false
    
    // UI State
    @State private var hideCompleted = false // Default: Show all
    @State private var isKanbanView = false // Renamed from isGridView to isKanbanView
    
    var filteredProjects: [Project] {
        var projects = firebaseService.projects
        
        // Filter by Search
        if !searchText.isEmpty {
            projects = projects.filter { project in
                project.name.lowercased().contains(searchText.lowercased()) ||
                (project.clientName?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        // Filter by Completion (Hide Completed)
        if hideCompleted {
            projects = projects.filter { $0.progress < 100 }
        }
        
        return projects
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            statsSection
            contentSection
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            if firebaseService.projects.isEmpty {
                firebaseService.fetchProjects()
            }
            if firebaseService.employees.isEmpty {
                firebaseService.fetchEmployees()
            }
            if firebaseService.clients.isEmpty {
                firebaseService.fetchClients()
            }
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView()
        }
        .sheet(item: $projectToEdit) { project in
            AddProjectView(project: project)
        }
        .sheet(item: $selectedProject) { project in
            AdminProjectDetailView(project: project)
        }
        .alert("Delete Project?", isPresented: $showingDeleteAlert, presenting: projectToDelete) { project in
            Button("Cancel", role: .cancel) { projectToDelete = nil }
            Button("Delete", role: .destructive) {
                if let docId = project.documentId {
                    firebaseService.deleteProject(documentId: docId)
                }
                projectToDelete = nil
            }
        } message: { project in
            Text("Are you sure you want to delete '\(project.name)'? This action cannot be undone.")
        }
    }
    
    // MARK: - Sub-views
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Manage Projects")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showingAddProject = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Project")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            
            // Search Bar
            searchBar
            
            // Search & Actions Bar (Compact)
            if !firebaseService.projects.isEmpty {
                actionsBar
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search projects...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var actionsBar: some View {
        HStack {
            // Showing records count
            Text("Showing \(filteredProjects.count)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Hide/Show Completed Toggle
                Button(action: { hideCompleted.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: hideCompleted ? "eye.slash.fill" : "eye.fill")
                        Text(hideCompleted ? "Hidden" : "All")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(hideCompleted ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundColor(hideCompleted ? .orange : .blue)
                    .cornerRadius(6)
                }
                
                // Divider
                Divider()
                    .frame(height: 16)
                
                // Toggle Layout Buttons
                HStack(spacing: 0) {
                    Button(action: { isKanbanView = false }) {
                        Image(systemName: "list.bullet")
                            .padding(6)
                            .background(isKanbanView ? Color.clear : Color(.systemBackground))
                            .cornerRadius(4)
                            .foregroundColor(isKanbanView ? .gray : .primary)
                            .shadow(color: isKanbanView ? .clear : .gray.opacity(0.1), radius: 1)
                    }
                    
                    Button(action: { isKanbanView = true }) {
                        Image(systemName: "square.grid.2x2")
                            .padding(6)
                            .background(isKanbanView ? Color(.systemBackground) : Color.clear)
                            .cornerRadius(4)
                            .foregroundColor(isKanbanView ? .primary : .gray)
                            .shadow(color: isKanbanView ? .gray.opacity(0.1) : .clear, radius: 1)
                    }
                }
                .padding(2)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
        }
        .padding(.top, 4)
    }
    
    private var statsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ManagementStatCard(
                    title: "Total Projects",
                    count: firebaseService.projects.count,
                    icon: "diagram.2.fill",
                    color: .blue
                )
                
                ManagementStatCard(
                    title: "Completed",
                    count: firebaseService.projects.filter { $0.progress >= 100 }.count,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                ManagementStatCard(
                    title: "In Progress",
                    count: firebaseService.projects.filter { $0.progress > 0 && $0.progress < 100 }.count,
                    icon: "clock.fill",
                    color: .orange
                )
                
                ManagementStatCard(
                    title: "Not Started",
                    count: firebaseService.projects.filter { $0.progress == 0 }.count,
                    icon: "flag.fill",
                    color: .red
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6).opacity(0.3))
    }
    
    private var contentSection: some View {
        Group {
            if firebaseService.projects.isEmpty {
                EmptyStateView(title: "No Projects Found", message: "Add your first project to get started")
            } else if filteredProjects.isEmpty {
                EmptyStateView(title: "No Results", message: "Try a different search term or check filters")
            } else {
                if isKanbanView {
                    AdminProjectKanbanBoard(projects: filteredProjects) { project in
                         selectedProject = project
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredProjects.enumerated()), id: \.element.documentId) { index, project in
                                AdminProjectCard(
                                    project: project,
                                    index: index + 1,
                                    action: { selectedProject = project },
                                    onEdit: { projectToEdit = project },
                                    onDelete: {
                                        projectToDelete = project
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

// MARK: - Kanban Board Components
struct AdminProjectKanbanBoard: View {
    let projects: [Project]
    let onProjectTap: (Project) -> Void
    @State private var selectedViewMode: Int = 0 // 0: 3-Stage, 1: 7-Stage
    
    // 3-Stage Data
    var notStartedProjects: [Project] { projects.filter { $0.progress == 0 } }
    var inProgressProjects: [Project] { projects.filter { $0.progress > 0 && $0.progress < 100 } }
    var completedProjects: [Project] { projects.filter { $0.progress >= 100 } }
    
    // 7-Stage Pipeline Definitions
    struct PipelineStage: Identifiable {
        let id = UUID()
        let name: String
        let level: Int
        let color: Color
        let range: ClosedRange<Double> // Progress range for mapping
    }
    
    let pipelineStages: [PipelineStage] = [
        PipelineStage(name: "Diagnose", level: 1, color: .purple, range: 0...14),
        PipelineStage(name: "Design Solution", level: 2, color: .blue, range: 15...29),
        PipelineStage(name: "Roadmap", level: 3, color: .cyan, range: 30...44),
        PipelineStage(name: "System Design", level: 4, color: .indigo, range: 45...59),
        PipelineStage(name: "Implementation", level: 5, color: .orange, range: 60...74),
        PipelineStage(name: "Monitor and Review", level: 6, color: .green, range: 75...89),
        PipelineStage(name: "Closure or Continuity", level: 7, color: .teal, range: 90...100)
    ]
    
    func projectsForStage(_ stage: PipelineStage) -> [Project] {
        projects.filter { stage.range.contains($0.progress) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // View Mode Toggle
            HStack {
                Spacer()
                Picker("View Mode", selection: $selectedViewMode) {
                    Text("3-Stage View").tag(0)
                    Text("7-Stage View").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
                .padding(.vertical, 8)
                Spacer()
            }
            .background(Color(.systemBackground))
            .zIndex(1)
            
            if selectedViewMode == 0 {
                // 3-Stage Kanban View
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        KanbanColumn(title: "Not Started", count: notStartedProjects.count, projects: notStartedProjects, themeColor: .yellow, onTap: onProjectTap)
                        KanbanColumn(title: "In Progress", count: inProgressProjects.count, projects: inProgressProjects, themeColor: .blue, onTap: onProjectTap)
                        KanbanColumn(title: "Completed", count: completedProjects.count, projects: completedProjects, themeColor: .green, onTap: onProjectTap)
                    }
                    .padding()
                }
            } else {
                // 7-Stage Pipeline View
                VStack(spacing: 0) {
                    // Pipeline Progress Header
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(pipelineStages) { stage in
                                VStack(spacing: 4) {
                                    Text(stage.name)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(stage.color)
                                    Text("Level \(stage.level)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.gray)
                                    
                                    Rectangle()
                                        .fill(stage.color)
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                        .padding(.horizontal, 4)
                                        .padding(.top, 4)
                                    
                                    Text("\(projectsForStage(stage).count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.top, 2)
                                }
                                .frame(width: 120)
                                
                                if stage.id != pipelineStages.last?.id {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.gray.opacity(0.3))
                                        .frame(width: 10)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 2)
                    
                    // Pipeline Columns
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(pipelineStages) { stage in
                                PipelineColumn(
                                    stage: stage,
                                    projects: projectsForStage(stage),
                                    onTap: onProjectTap
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.05))
    }
}

// 3-Stage Column & Card (Existing)
struct KanbanColumn: View {
    let title: String
    let count: Int
    let projects: [Project]
    let themeColor: Color
    let onTap: (Project) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(themeColor)
                    .padding(6)
                    .background(themeColor.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding()
            .background(themeColor.opacity(0.1))
            .cornerRadius(12, corners: [.topLeft, .topRight])
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeColor.opacity(0.3), lineWidth: 1)
            )
            
            // Content
            ScrollView {
                VStack(spacing: 12) {
                    if projects.isEmpty {
                        Text("No projects in \(title.lowercased())")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    } else {
                        ForEach(projects, id: \.documentId) { project in
                            KanbanCard(project: project, themeColor: themeColor) {
                                onTap(project)
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity)
    }
}

struct KanbanCard: View {
    let project: Project
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let client = project.clientName {
                    Text("Client: \(client)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Progress
                VStack(alignment: .trailing, spacing: 2) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(themeColor)
                                .frame(width: geometry.size.width * CGFloat(project.progress / 100), height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(Int(project.progress))%")
                        .font(.caption2)
                        .foregroundColor(themeColor)
                }
                
                // Dates
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start: \(project.startDate.formatted(date: .numeric, time: .omitted))")
                    Text("End:   \(project.endDate.formatted(date: .numeric, time: .omitted))")
                }
                .font(.caption2)
                .foregroundColor(.gray)
                
                // Objective Snippet
                if let firstObj = project.objectives.first {
                    Text("Obj: \(firstObj.title)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Action Icons Footer
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "eye")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Image(systemName: "square.and.pencil")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(12)
            .background(themeColor.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 7-Stage Pipeline Components
struct PipelineColumn: View {
    let stage: AdminProjectKanbanBoard.PipelineStage
    let projects: [Project]
    let onTap: (Project) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(stage.color)
                    .frame(width: 8, height: 8)
                Text(stage.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(projects.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(stage.color)
                    .padding(4)
                    .background(stage.color.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(10)
            .background(stage.color.opacity(0.05))
            .cornerRadius(12, corners: [.topLeft, .topRight])
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(stage.color.opacity(0.2), lineWidth: 1)
            )
            
            // Content
            ScrollView {
                VStack(spacing: 12) {
                    if projects.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "circle.dotted")
                                .font(.title3)
                                .foregroundColor(.gray.opacity(0.3))
                            Text("No projects")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(projects, id: \.documentId) { project in
                            PipelineCard(project: project, stageColor: stage.color, onTap: { onTap(project) })
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .frame(width: 250) // Slightly narrower for 7-stage
        .frame(maxHeight: .infinity)
    }
}

struct PipelineCard: View {
    let project: Project
    let stageColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header: Name & ID/Sr
                HStack {
                    Text(project.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                }
                
                // Client
                if let client = project.clientName {
                    Text("Client: \(client)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // Progress Bar
                VStack(alignment: .trailing, spacing: 2) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(project.progress))%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(stageColor)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 3).cornerRadius(1.5)
                            Rectangle().fill(stageColor).frame(width: g.size.width * (project.progress / 100), height: 3).cornerRadius(1.5)
                        }
                    }
                    .frame(height: 3)
                }
                
                Divider()
                
                // Substages (Mocked visual)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Substages")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Manage")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                    }
                    HStack(spacing: 4) {
                        Text("Discovery")
                            .font(.system(size: 8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(2)
                        Text("Analysis")
                            .font(.system(size: 8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(2)
                        Text("+1 more")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                
                // Bottom Dropdown visual
                HStack {
                    Text(project.name) // Using project name as stage name approx
                        .font(.system(size: 9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
            .padding(10)
            .background(Color(.systemBackground)) // Card background
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(stageColor.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                // Left colored strip
                HStack {
                    Rectangle()
                        .fill(stageColor)
                        .frame(width: 3)
                        .cornerRadius(1.5)
                        .padding(.vertical, 4)
                        .padding(.leading, 2)
                    Spacer()
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Helper Views & Extensions
struct EmptyStateView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper for rounded corners on specific sides
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Reuse existing AddProjectView and related components (Ensuring they are present)
// ... (AddProjectView and AdminProjectDetailView, AdminProjectCard code remains same as previous step) ...

struct AdminProjectCard: View {
    let project: Project
    let index: Int
    let action: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Sr No. Badge
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Header: Name & Actions
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if let client = project.clientName {
                                Text(client)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(6)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // Details Grid
                    HStack(alignment: .top, spacing: 16) {
                        // PM
                        if let manager = project.projectManager {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Manager")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                                Text(manager)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        // Progress
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Progress")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 4) {
                                ProgressView(value: project.progress, total: 100)
                                    .progressViewStyle(LinearProgressViewStyle(tint: project.progress >= 100 ? .green : .blue))
                                    .frame(width: 50)
                                Text("\(Int(project.progress))%")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(project.progress >= 100 ? .green : .blue)
                            }
                        }
                    }
                    
                    // Footer: Dates
                    HStack {
                        Label(project.startDate.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Label(project.endDate.formatted(date: .numeric, time: .omitted), systemImage: "flag.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddProjectView: View {
    let project: Project?
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    // Project Details
    @State private var projectName = ""
    @State private var selectedClient = ""
    @State private var selectedManager = ""
    
    // Timeline
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 30) // +30 days
    
    // Assignees
    @State private var selectedAssignees: Set<String> = []
    
    // OKRs
    @State private var objectives: [TempObjective] = []
    
    // UI State
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    init(project: Project? = nil) {
        self.project = project
        _projectName = State(initialValue: project?.name ?? "")
        _selectedClient = State(initialValue: project?.clientName ?? "")
        _selectedManager = State(initialValue: project?.projectManager ?? "")
        _startDate = State(initialValue: project?.startDate ?? Date())
        _endDate = State(initialValue: project?.endDate ?? Date().addingTimeInterval(86400 * 30))
        _selectedAssignees = State(initialValue: Set(project?.assignedEmployees ?? []))
        
        let tempObjectives = project?.objectives.map { obj in
            TempObjective(title: obj.title, keyResults: obj.keyResults.map { TempKeyResult(description: $0.description) })
        } ?? []
        _objectives = State(initialValue: tempObjectives)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Section 1: Project Details
                Section(header: Label("Project Details", systemImage: "briefcase.fill").font(.headline)) {
                    TextField("Project Name *", text: $projectName)
                    
                    Picker("Company Name *", selection: $selectedClient) {
                         Text("Select a company").tag("")
                         ForEach(firebaseService.clients, id: \.name) { client in
                             Text(client.name).tag(client.name) // Using name as ID for simplicity
                         }
                    }
                    
                    Picker("Project Manager *", selection: $selectedManager) {
                        Text("Select a project manager").tag("")
                        ForEach(firebaseService.employees, id: \.name) { emp in
                            Text(emp.name).tag(emp.name)
                        }
                    }
                }
                
                // Section 2: Assignees
                Section(header: Label("Assignees", systemImage: "person.3.fill").font(.headline)) {
                    if firebaseService.employees.isEmpty {
                        Text("No employees available").foregroundColor(.gray)
                    } else {
                        List {
                            ForEach(firebaseService.employees, id: \.id) { emp in
                                Button(action: {
                                    if selectedAssignees.contains(emp.name) {
                                        selectedAssignees.remove(emp.name)
                                    } else {
                                        selectedAssignees.insert(emp.name)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedAssignees.contains(emp.name) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(selectedAssignees.contains(emp.name) ? .blue : .gray)
                                        Text(emp.name)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .frame(height: 150) // Limit height to make it scrollable within form
                    }
                }
                
                // Section 3: Timeline
                Section(header: Label("Timeline", systemImage: "calendar").font(.headline)) {
                    DatePicker("Start Date *", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date *", selection: $endDate, displayedComponents: .date)
                }
                
                // Section 4: OKRs
                Section(header: HStack {
                    Label("OKRs", systemImage: "target").font(.headline)
                    Spacer()
                    Button("Add") {
                        objectives.append(TempObjective())
                    }
                    .font(.subheadline)
                }) {
                    if objectives.isEmpty {
                        Text("No OKRs added. Tap 'Add' to define objectives.").foregroundColor(.gray).font(.caption)
                    } else {
                        ForEach($objectives) { $objective in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Objective")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Button(action: {
                                        if let idx = objectives.firstIndex(where: { $0.id == objective.id }) {
                                            objectives.remove(at: idx)
                                        }
                                    }) {
                                        Image(systemName: "trash").foregroundColor(.red).font(.caption)
                                    }
                                }
                                
                                TextField("Enter objective...", text: $objective.title)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Text("Key Results")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .padding(.top, 4)
                                
                                ForEach($objective.keyResults) { $kr in
                                    HStack {
                                        Image(systemName: "circle.fill").font(.system(size: 6)).foregroundColor(.gray)
                                        TextField("Result...", text: $kr.description)
                                            .textFieldStyle(PlainTextFieldStyle())
                                        Button(action: {
                                            if let idx = objective.keyResults.firstIndex(where: { $0.id == kr.id }) {
                                                objective.keyResults.remove(at: idx)
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.5))
                                        }
                                    }
                                }
                                
                                Button(action: {
                                    objective.keyResults.append(TempKeyResult())
                                }) {
                                    Label("Add Result", systemImage: "plus")
                                        .font(.caption)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(project == nil ? "Add New Project" : "Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(project == nil ? "Create Project" : "Save Changes") {
                        saveProject()
                    }
                    .disabled(projectName.isEmpty || selectedClient.isEmpty || selectedManager.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func saveProject() {
        guard !projectName.isEmpty, !selectedClient.isEmpty, !selectedManager.isEmpty else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        let finalObjectives = objectives.map { tempObj in
            Objective(
                id: UUID(),
                title: tempObj.title,
                keyResults: tempObj.keyResults.compactMap { kr in
                    kr.description.isEmpty ? nil : KeyResult(description: kr.description)
                }
            )
        }.filter { !$0.title.isEmpty }
        
        if let project = project, let docId = project.documentId {
            firebaseService.updateProject(
                documentId: docId,
                name: projectName,
                clientName: selectedClient,
                projectManager: selectedManager,
                assignedEmployees: Array(selectedAssignees),
                startDate: startDate,
                endDate: endDate,
                objectives: finalObjectives
            ) { error in
                isSubmitting = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
        } else {
            firebaseService.createProject(
                name: projectName,
                clientName: selectedClient,
                projectManager: selectedManager,
                assignedEmployees: Array(selectedAssignees),
                startDate: startDate,
                endDate: endDate,
                objectives: finalObjectives
            ) { error in
                isSubmitting = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
        }
    }
}

struct TempObjective: Identifiable {
    let id = UUID()
    var title: String = ""
    var keyResults: [TempKeyResult] = []
    
    init(title: String = "", keyResults: [TempKeyResult] = []) {
        self.title = title
        self.keyResults = keyResults
    }
}

struct TempKeyResult: Identifiable {
    let id = UUID()
    var description: String = ""
    
    init(description: String = "") {
        self.description = description
    }
}

struct AdminProjectDetailView: View {
    let project: Project
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Project Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(project.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let client = project.clientName {
                            HStack(spacing: 6) {
                                Image(systemName: "building.2.fill")
                                Text(client)
                            }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        }
                        
                        Text(project.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(project.progress))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * CGFloat(project.progress / 100), height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Details
                    VStack(spacing: 16) {
                        ResourceDetailRow(icon: "calendar", title: "Start Date", value: project.startDate.formatted(date: .long, time: .omitted))
                        ResourceDetailRow(icon: "calendar", title: "End Date", value: project.endDate.formatted(date: .long, time: .omitted))
                        
                        if let manager = project.projectManager {
                            ResourceDetailRow(icon: "person.fill.badge.plus", title: "Project Manager", value: manager)
                        }
                        
                        if !project.assignedEmployees.isEmpty {
                            ResourceDetailRow(icon: "person.2.fill", title: "Team Size", value: "\(project.assignedEmployees.count) members")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // OKRs Display (New)
                    if !project.objectives.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Objectives & Key Results")
                                .font(.headline)
                            
                            ForEach(project.objectives) { objective in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("🎯 \(objective.title)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(objective.keyResults) { kr in
                                        HStack(alignment: .top) {
                                            Text("•")
                                            Text(kr.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.leading, 8)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Project Details")
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
