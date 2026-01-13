import SwiftUI

struct AnalyticsDashboardView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @State private var selectedDate = Date()
    @State private var showingProjects = false
    @State private var showingResources = false
    @State private var showingClients = false
    @State private var showingTasks = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Top Stat Cards
                // Adaptive grid: Fit as many 160pt cards as possible, centered
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 12)
                ], spacing: 12) {
                    DashboardStatCardNew(
                        title: "TOTAL PROJECTS",
                        value: "\(firebaseService.projects.count)",
                        icon: "rectangle.stack.fill",
                        color: .blue,
                        action: { showingProjects = true }
                    )
                    
                    DashboardStatCardNew(
                        title: "TOTAL RESOURCES",
                        value: "\(firebaseService.employees.count)",
                        icon: "person.2.fill",
                        color: .blue,
                        action: { showingResources = true }
                    )
                    
                    DashboardStatCardNew(
                        title: "TOTAL CLIENTS",
                        value: "\(firebaseService.clients.count)",
                        icon: "person.crop.circle.fill",
                        color: .red,
                        action: { showingClients = true }
                    )
                    
                    DashboardStatCardNew(
                        title: "TASKS COMPLETED",
                        value: "\(completedTasksCount)",
                        icon: "checkmark.square.fill",
                        color: .green,
                        action: { showingTasks = true }
                    )
                }
                
                // MARK: - Charts & Calendar Section
                // Adaptive grid for these two large blocks. 
                // On iPad: Side by Side (min 350 each). On iPhone: Stacked.
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 340), spacing: 20)
                ], spacing: 20) {
                    
                    // Project Analytics (Bar Chart)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Project Analytics Dashboard")
                            .font(.headline)
                        
                        Text("Monthly Project Status (Last 12 months)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        ProjectStatusBarChart(projects: firebaseService.projects)
                            .frame(height: 180)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Calendar & Events
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Project Calendar & Events")
                            .font(.headline)
                        
                        // Simple Calendar View
                        // Make sure CalendarGridView doesn't explode layout
                        CalendarGridView(selectedDate: $selectedDate, events: firebaseService.events)
                        
                        Divider()
                        
                        Text("Upcoming Events")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if upcomingEvents.isEmpty {
                            Text("No upcoming events.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(Array(upcomingEvents.prefix(3))) { event in
                                    HStack {
                                        Circle()
                                            .fill(eventColor(event))
                                            .frame(width: 8, height: 8)
                                        Text(event.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(event.date.formatted(date: .numeric, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .top) // Align top to match neighbor height if possible
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                }
                
                // MARK: - Bottom Section (Progress & Health)
                // Similar Adaptive Grid approach
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 340), spacing: 20)
                ], spacing: 20) {
                    
                    // Projects Progress List
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Projects Progress")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        if firebaseService.projects.isEmpty {
                            Text("No active projects")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(firebaseService.projects.prefix(5), id: \.documentId) { project in
                                    ProjectProgressRow(project: project)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Project Health Overview
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Project Health Overview")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        // Summary Bar
                        HealthSummaryBar(projects: firebaseService.projects)
                        
                        // Status Cards
                        // Inner adaptive grid for the 3 small cards if width is tight, 
                        // but usually they fit 3 in a row unless very narrow.
                        // Let's keep HStack for now but allow wrapping if needed?
                        // Actually, ScrollView horizontal or adaptive grid is safer.
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 12)], spacing: 12) {
                             HealthStatusCard(
                                title: "On Track",
                                count: onTrackCount,
                                color: .green.opacity(0.2),
                                textColor: .green
                            )
                            HealthStatusCard(
                                title: "Needs Attention",
                                count: needsAttentionCount,
                                color: .yellow.opacity(0.2),
                                textColor: .orange
                            )
                            HealthStatusCard(
                                title: "At Risk",
                                count: atRiskCount,
                                color: .red.opacity(0.2),
                                textColor: .red
                            )
                        }
                        
                        Text("Top At-Risk Projects")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)
                        
                        if atRiskProjects.isEmpty {
                            Text("No at-risk projects. Keep it up!")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            ForEach(atRiskProjects.prefix(3), id: \.documentId) { project in
                                Text("• \(project.name)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Spacer(minLength: 0)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Total Active Projects:")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(activeProjectsCount)")
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Avg Completion Rate:")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(String(format: "%.0f", averageCompletionRate))%")
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showingProjects) {
            ManageProjectsView()
        }
        .sheet(isPresented: $showingResources) {
            ManageResourcesView()
        }
        .sheet(isPresented: $showingClients) {
            ManageClientsView()
        }
        .sheet(isPresented: $showingTasks) {
            TaskManagementView()
        }
    }
    
    // MARK: - Computed Properties / Helpers
    
    private func loadData() {
        firebaseService.fetchProjects()
        firebaseService.fetchEmployees()
        firebaseService.fetchClients()
        firebaseService.fetchTasks(forUserUid: nil, userEmail: nil)
        firebaseService.fetchEvents()
    }
    
    private var completedTasksCount: Int {
        firebaseService.tasks.filter { $0.status == .completed }.count
    }
    
    private var upcomingEvents: [Meeting] {
        let now = Date()
        return firebaseService.events
            .filter { $0.date >= now }
            .sorted { $0.date < $1.date }
    }
    
    private func eventColor(_ event: Meeting) -> Color {
        return .red
    }
    
    // Health Metrics
    private var activeProjectsCount: Int {
        firebaseService.projects.filter { $0.progress < 100 }.count
    }
    
    private var averageCompletionRate: Double {
        let projects = firebaseService.projects
        guard !projects.isEmpty else { return 0 }
        let total = projects.reduce(0.0) { $0 + $1.progress }
        return total / Double(projects.count)
    }
    
    private var onTrackCount: Int {
        firebaseService.projects.filter { isProjectOnTrack($0) }.count
    }
    
    private var needsAttentionCount: Int {
        firebaseService.projects.filter { isProjectNeedsAttention($0) }.count
    }
    
    private var atRiskCount: Int {
        firebaseService.projects.filter { isProjectAtRisk($0) }.count
    }
    
    private var atRiskProjects: [Project] {
        firebaseService.projects.filter { isProjectAtRisk($0) }
    }
    
    private func isProjectOnTrack(_ p: Project) -> Bool {
        return !isProjectAtRisk(p) && !isProjectNeedsAttention(p)
    }
    
    private func isProjectAtRisk(_ p: Project) -> Bool {
        if Date() > p.endDate && p.progress < 100 { return true }
        return false
    }
    
    private func isProjectNeedsAttention(_ p: Project) -> Bool {
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: p.endDate).day ?? 0
        return daysUntilDue < 7 && daysUntilDue >= 0 && p.progress < 80
    }
}

// MARK: - Subviews

struct DashboardStatCardNew: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.subheadline)
                            .foregroundColor(color)
                    }
                    Spacer()
                    if action != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8) // Allow font to shrink slightly
                    
                    Text(value)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                if action != nil {
                    Text("Click to view")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .gray.opacity(0.08), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

struct ProjectProgressRow: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if let client = project.clientName {
                        Text(client)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(Int(project.progress))%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.gray)
                        .frame(width: geometry.size.width * CGFloat(min(max(project.progress / 100, 0), 1)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct HealthSummaryBar: View {
    let projects: [Project]
    
    var body: some View {
        let done = projects.filter { $0.progress >= 100 }.count
        let inProgress = projects.filter { $0.progress > 0 && $0.progress < 100 }.count
        let total = projects.count
        let todo = max(0, total - done - inProgress)
        
        VStack(spacing: 8) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                   if total > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(Double(done) / Double(total)))
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(Double(inProgress) / Double(total)))
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: geometry.size.width * CGFloat(Double(todo) / Double(total)))
                   } else {
                       Rectangle()
                           .fill(Color.gray.opacity(0.2))
                   }
                }
                .cornerRadius(6)
            }
            .frame(height: 12)
            
            // Allow this legend to wrap if needed
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading) {
                LabelDot(color: .green, text: "Done: \(done)")
                LabelDot(color: .blue, text: "In Prog: \(inProgress)")
                LabelDot(color: .gray, text: "To-Do: \(todo)")
            }
            
            HStack {
                Spacer()
                Text("Total: \(total)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct LabelDot: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct HealthStatusCard: View {
    let title: String
    let count: Int
    let color: Color
    let textColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
            
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 75)
        .background(color)
        .cornerRadius(12)
    }
}

struct ProjectStatusBarChart: View {
    let projects: [Project]
    
    var body: some View {
        let months = getLast12Months()
        
        // Compute stats for all months first to determine max height scale
        let allStats = months.map { getStats(for: $0) }
        // Find maximum single column total to normalize height
        // Max value is sum of pending+inProgress+completed for the busiest month
        let maxCount = allStats.map { $0.pending + $0.inProgress + $0.completed }.max() ?? 1
        let safeMax = max(Double(maxCount), 1.0)
        
        VStack {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 0) { // Spacing 0, use padding on bars or alignment
                    ForEach(months.indices, id: \.self) { index in
                        let monthDate = months[index]
                        let stats = allStats[index]
                        let totalHeight = geo.size.height - 20 // Reserve space for label
                        
                        VStack {
                            Spacer()
                            
                            // Stacked Bar
                            VStack(spacing: 0) {
                                // We need to proportionalize these against safeMax
                                
                                if stats.pending > 0 {
                                    Rectangle()
                                        .fill(Color.orange)
                                        .frame(height: totalHeight * (Double(stats.pending) / safeMax))
                                }
                                if stats.inProgress > 0 {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(height: totalHeight * (Double(stats.inProgress) / safeMax))
                                }
                                if stats.completed > 0 {
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(height: totalHeight * (Double(stats.completed) / safeMax))
                                }
                            }
                            .cornerRadius(4)
                            .frame(width: 8) // Thin bars to fit 12 months easily
                            
                            Text(monthDetails(monthDate))
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity) // Distribute equally
                    }
                }
            }
            .frame(height: 150)
            
            // Legend
            HStack(spacing: 16) {
                LabelDot(color: .green, text: "Comp")
                LabelDot(color: .blue, text: "In Prog")
                LabelDot(color: .orange, text: "Wait")
            }
            .padding(.top, 4)
        }
    }
    
    func getLast12Months() -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<12).compactMap { i in
            calendar.date(byAdding: .month, value: -11 + i, to: now)
        }
    }
    
    func monthDetails(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    func getStats(for date: Date) -> (completed: Int, inProgress: Int, pending: Int) {
        let calendar = Calendar.current
        let monthProjects = projects.filter {
            calendar.isDate($0.endDate, equalTo: date, toGranularity: .month)
        }
        
        let completed = monthProjects.filter { $0.progress >= 100 }.count
        let inProgress = monthProjects.filter { $0.progress > 0 && $0.progress < 100 }.count
        let pending = monthProjects.filter { $0.progress == 0 }.count
        
        return (completed, inProgress, pending)
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let events: [Meeting]
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            Text(currentMonthYear)
                .font(.headline)
            
            // Days Row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
            }
            
            // Dates Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Padding for start of month
                ForEach(0..<daysBeforeStart, id: \.self) { _ in
                    Text("")
                }
                
                ForEach(daysInMonth, id: \.self) { date in
                    VStack(spacing: 2) {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.caption)
                            .padding(6)
                            .background(isToday(date) ? Color.blue.opacity(0.2) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isToday(date) ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        // Event Dots
                        HStack(spacing: 2) {
                            ForEach(eventsForDate(date).prefix(3), id: \.id) { _ in
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 3, height: 3)
                            }
                        }
                    }
                    .frame(height: 30) // Fixed height to prevent jumping
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
        }
    }
    
    private var currentMonthYear: String {
        selectedDate.formatted(.dateTime.month().year())
    }
    
    private var daysBeforeStart: Int {
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }
    
    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))
        else { return [] }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }
    
    private func eventsForDate(_ date: Date) -> [Meeting] {
        events.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
