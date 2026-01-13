import SwiftUI

struct SuperAdminAdminReportsView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    
    // Filters
    @State private var selectedProject: Project? = nil
    @State private var selectedEmployee: EmployeeProfile? = nil
    
    // Context
    var userUid: String? = nil
    var userEmail: String? = nil
    var userName: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analytics & Reports")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("View comprehensive analytics and reports across different time periods")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Export Logic (Placeholder)
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Excel")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .cornerRadius(8)
                    }
                }
                
                // Filters Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Report Filters")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            selectedProject = nil
                            selectedEmployee = nil
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset Filters")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        // Project Filter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project Filter")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            
                            Menu {
                                Button("All Projects") { selectedProject = nil }
                                ForEach(firebaseService.projects) { project in
                                    Button(project.name) { selectedProject = project }
                                }
                            } label: {
                                HStack {
                                    Text(selectedProject?.name ?? "All Projects")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Employee Filter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Employee Filter")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green) // Using green to match 'Employee Filter' icon color in image logic if applicable, essentially distinctly handled
                            
                            Menu {
                                Button("All Employees") { selectedEmployee = nil }
                                ForEach(firebaseService.employees) { employee in
                                    Button(employee.name) { selectedEmployee = employee }
                                }
                            } label: {
                                HStack {
                                    Text(selectedEmployee?.name ?? "All Employees")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Stats Row
                // Stats Row
                // Stats Row
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ReportStatCard(
                        title: "Total Tasks",
                        value: "\(filteredTasks.count)",
                        color: .blue,
                        icon: "list.bullet"
                    )
                    
                    ReportStatCard(
                        title: "Completed",
                        value: "\(filteredTasks.filter { $0.status == .completed }.count)",
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                    
                    ReportStatCard(
                        title: "In Progress",
                        value: "\(filteredTasks.filter { $0.status == .inProgress }.count)",
                        color: .orange,
                        icon: "clock.fill"
                    )
                    
                    ReportStatCard(
                        title: "Completion Rate",
                        value: String(format: "%.0f%%", completionRate),
                        color: .purple,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                
                // Charts Row
                // Charts Column
                VStack(spacing: 24) {
                    // Status Distribution (Donut Chart)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.pie.fill")
                                .foregroundColor(.gray)
                            Text("Status Distribution")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.top)
                        .padding(.horizontal)
                        
                        StatusDonutChart(tasks: filteredTasks)
                            .frame(height: 180)
                            .padding(.bottom)
                    }
                    .background(Color.black)
                    .cornerRadius(12)
                    .shadow(color: .white.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    // Tasks Over Time (Line Chart)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundColor(.gray)
                            Text("Tasks Over Time")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.top)
                        .padding(.horizontal)
                        
                        TasksLineChart(tasks: filteredTasks)
                            .frame(height: 180)
                            .padding(.bottom)
                        
                        // Legend for Line Chart
                        HStack(spacing: 20) {
                            HStack(spacing: 4) {
                                Image(systemName: "line.diagonal")
                                    .foregroundColor(.green)
                                Text("Completed")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "line.diagonal")
                                    .foregroundColor(.purple)
                                Text("Created")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                    }
                    .background(Color.black)
                    .cornerRadius(12)
                    .shadow(color: .white.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    // MARK: - Task Status Breakdown (New)
                    // MARK: - Task Status Breakdown (New)
                    TaskStatusBreakdownView(tasks: filteredTasks)
                    
                    // MARK: - Priority Distribution
                    PriorityDistributionView(tasks: filteredTasks)
                    
                    // MARK: - Tasks By Project
                    TasksByProjectView(tasks: filteredTasks)
                    
                    // MARK: - Resource Performance
                    ResourcePerformanceView(tasks: filteredTasks, employees: firebaseService.employees)
                    

                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                // Force fetch latest data to ensure charts are dynamic and accurate
                if let uid = userUid {
                    firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: userEmail, userName: userName)
                    firebaseService.fetchEmployees() // Managers might need list of employees? Limit if needed.
                } else {
                    firebaseService.fetchProjects()
                    firebaseService.fetchEmployees()
                }
                
                // Fetch tasks (Filtered or All)
                firebaseService.fetchTasks(forUserUid: userUid, userEmail: userEmail)
                
            }
        }
        .refreshable {
            // Manual refresh on pull
            if let uid = userUid {
                 firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: userEmail, userName: userName)
            } else {
                 firebaseService.fetchProjects()
            }
            firebaseService.fetchEmployees()
            firebaseService.fetchTasks(forUserUid: userUid, userEmail: userEmail)
        }
        .animation(.default, value: filteredTasks.count)
    }
        
    // Computed Data
    var filteredTasks: [Task] {
            // Strictly fetch from 'tasks' collection as per user requirement (Project Management/Admin tasks)
            var tasks = firebaseService.tasks
            
            if let project = selectedProject {
                // Filter by project if selected
                tasks = tasks.filter { $0.project?.id == project.id }
            }
            
            if let employee = selectedEmployee {
                // Task has `assignedTo: String`. This string might be email or name.
                // checking User.swift: assignedTo is String.
                tasks = tasks.filter { $0.assignedTo == employee.email || $0.assignedTo == employee.name }
            }
            
            return tasks
        }
        
        var completionRate: Double {
            let total = filteredTasks.count
            guard total > 0 else { return 0 }
            let completed = filteredTasks.filter { $0.status == .completed }.count
            return Double(completed) / Double(total) * 100
        }

    
    // MARK: - Components
    
    struct ReportStatCard: View {
        let title: String
        let value: String
        let color: Color
        let icon: String
        
        var body: some View {
            VStack(spacing: 0) {
                // Top Colored Border
                Rectangle()
                    .fill(color)
                    .frame(height: 3)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        Text(value)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(color)
                    }
                }
                .padding(12)
            }
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
        }
    }
    
    struct StatusDonutChart: View {
        let tasks: [Task]
        
        var body: some View {
            let completed = tasks.filter { $0.status == .completed }.count
            let inProgress = tasks.filter { $0.status == .inProgress }.count
            let todo = tasks.filter { $0.status == .notStarted }.count
            let total = max(1, completed + inProgress + todo)
            
            let completedRatio = Double(completed) / Double(total)
            let inProgressRatio = Double(inProgress) / Double(total)
            let todoRatio = Double(todo) / Double(total)
            
            return VStack(spacing: 8) {
                // Top Label (Completed)
                Text("Completed \(Int(completedRatio * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                HStack(spacing: 12) {
                    // Left Label (In Progress)
                    Text("In Progress \(Int(inProgressRatio * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(width: 80, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                    
                    // Donut Chart
                    ZStack {
                        // Background
                        Circle()
                            .stroke(Color.gray.opacity(0.1), lineWidth: 18)
                        
                        // Completed Segment (Green)
                        if completed > 0 {
                            Circle()
                                .trim(from: 0, to: CGFloat(completedRatio))
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                        }
                        
                        // In Progress Segment (Blue)
                        if inProgress > 0 {
                            Circle()
                                .trim(from: CGFloat(completedRatio), to: CGFloat(completedRatio + inProgressRatio))
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                        }
                        
                        // To Do Segment (Gray)
                        if todo > 0 {
                            Circle()
                                .trim(from: CGFloat(completedRatio + inProgressRatio), to: 1.0)
                                .stroke(Color.gray, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                        }
                        
                        // Center Text
                        VStack(spacing: 0) {
                            Text("\(tasks.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Total")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 100, height: 100)
                    
                    // Right Spacer to balance the layout
                    Spacer()
                        .frame(width: 80)
                }
                
                // Bottom Label (To-Do)
                Text("To-Do \(Int(todoRatio * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .padding(.bottom, 4)
                
                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: .green, text: "Completed")
                    LegendItem(color: .blue, text: "In Progress")
                    LegendItem(color: .gray, text: "To-Do")
                }
            }
        }
    }
    
    struct LegendItem: View {
        let color: Color
        let text: String
        
        var body: some View {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(text)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    struct TasksLineChart: View {
        let tasks: [Task]
        @State private var selectedIndex: Int? = nil
        
        var body: some View {
            let sortedTasks = tasks.sorted { $0.startDate < $1.startDate }
            let calendar = Calendar.current
            let now = Date()
            
            // Window: Today and Last 5 Days (Total 6 Days)
            let endDate = calendar.startOfDay(for: now)
            let startDate = calendar.date(byAdding: .day, value: -5, to: endDate)!
            
            let datePoints = generateDates(from: startDate, to: endDate)
            
            // Calculate Cumulative Data
            // We calculate the state of the world at the END of each day.
            var createdData: [Double] = []
            var completedData: [Double] = []
            
            for date in datePoints {
                // Use Calendar's native "same day" check for maximum reliability across timezones
                // Created Daily:
                let createdCount = tasks.filter {
                    calendar.isDate($0.startDate, inSameDayAs: date)
                }.count
                createdData.append(Double(createdCount))
                
                // Completed Daily:
                let completedCount = tasks.filter {
                    $0.status == .completed && calendar.isDate($0.dueDate, inSameDayAs: date)
                }.count
                completedData.append(Double(completedCount))
            }
            
            let maxValue = max(createdData.max() ?? 5, completedData.max() ?? 5)
            let chartMax = maxValue == 0 ? 5 : maxValue * 1.2 // 20% buffer
            
            return GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                
                let leftMargin: CGFloat = 40
                let bottomMargin: CGFloat = 30
                let rightMargin: CGFloat = 20
                
                let chartWidth = width - leftMargin - rightMargin
                let chartHeight = height - bottomMargin
                
                ZStack(alignment: .leading) {
                    // BACKGROUND GRID & Y-AXIS
                    ForEach(0..<5) { i in
                        let val = chartMax / 4 * Double(i)
                        let y = chartHeight - (CGFloat(val) / CGFloat(chartMax) * chartHeight)
                        
                        // Grid Line
                        Path { path in
                            path.move(to: CGPoint(x: leftMargin, y: y))
                            path.addLine(to: CGPoint(x: width - rightMargin, y: y))
                        }
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        
                        // Label
                        Text(String(format: "%.0f", val))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .position(x: leftMargin / 2, y: y)
                    }
                    
                    // Rotated Y-Axis Title
                    Text("Tasks")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(-90))
                        .offset(x: -leftMargin + 10, y: 0)
                    
                    // DATA LINES
                    if !datePoints.isEmpty {
                        // Created (Purple)
                        Path { path in
                            for (i, val) in createdData.enumerated() {
                                let x = leftMargin + (CGFloat(i) / CGFloat(datePoints.count - 1)) * chartWidth
                                let y = chartHeight - (CGFloat(val) / CGFloat(chartMax) * chartHeight)
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        
                        // Completed (Green)
                        Path { path in
                            for (i, val) in completedData.enumerated() {
                                let x = leftMargin + (CGFloat(i) / CGFloat(datePoints.count - 1)) * chartWidth
                                let y = chartHeight - (CGFloat(val) / CGFloat(chartMax) * chartHeight)
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    
                    // X-AXIS LABELS (Daily)
                    ForEach(0..<datePoints.count, id: \.self) { index in
                        let date = datePoints[index]
                        let x = leftMargin + (CGFloat(index) / CGFloat(datePoints.count - 1)) * chartWidth
                        
                        Text("\(date.formatted(.dateTime.day()))/\(date.formatted(.dateTime.month(.twoDigits)))")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .position(x: x, y: height - 10)
                    }
                    
                    // INTERACTIVE TOOLTIP
                    if let idx = selectedIndex, idx < datePoints.count {
                        let x = leftMargin + (CGFloat(idx) / CGFloat(datePoints.count - 1)) * chartWidth
                        
                        // Selection Line
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: chartHeight))
                        }
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 1))
                        
                        // Tooltip
                        tooltipView(
                            date: datePoints[idx],
                            created: Int(createdData[idx]),
                            completed: Int(completedData[idx]),
                            xPosition: x,
                            chartWidth: chartWidth,
                            chartHeight: chartHeight
                        )
                    }
                    
                    // DATA POINT DOTS (Optional, for clarity)
                    // ... (Skipped to keep clean neon look)
                    
                    // TOUCH GESTURE
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - leftMargin
                                    let percentage = x / chartWidth
                                    let index = Int(round(percentage * CGFloat(datePoints.count - 1)))
                                    selectedIndex = min(max(0, index), datePoints.count - 1)
                                }
                                .onEnded { _ in
                                    selectedIndex = nil
                                }
                        )
                }
            }
        }
        
        @ViewBuilder
        func tooltipView(date: Date, created: Int, completed: Int, xPosition: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat) -> some View {
            let isRightSide = xPosition < chartWidth / 2
            
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(date: .numeric, time: .omitted))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Text("Completed:")
                        .foregroundColor(.green)
                    Text("\(completed) tasks")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .font(.caption2)
                
                HStack(spacing: 4) {
                    Text("Created:")
                        .foregroundColor(.purple)
                    Text("\(created) tasks")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .font(.caption2)
            }
            .padding(8)
            .background(Color.gray.opacity(0.95))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            // Adjust position so it doesn't go off screen
            .position(x: xPosition + (isRightSide ? 75 : -75), y: 50)
        }
        
        func generateDates(from start: Date, to end: Date) -> [Date] {
            var dates: [Date] = []
            var current = start
            let calendar = Calendar.current
            
            if start > end { return [end] }
            
            while current <= end {
                dates.append(current)
                if let next = calendar.date(byAdding: .day, value: 1, to: current) {
                    current = next
                } else {
                    break
                }
            }
            return dates
        }
    }
    
    // MARK: - Task Status Breakdown Component
    struct TaskStatusBreakdownView: View {
        let tasks: [Task]
        
        // Status Counts
        var completedTasks: Int { tasks.filter { $0.status == .completed }.count }
        
        // Broaden "In Progress" to include other active states
        var inProgressTasks: Int {
            tasks.filter {
                $0.status == .inProgress ||
                $0.status == .stuck ||
                $0.status == .needHelp
            }.count
        }
        
        // Broaden "To-Do" to include other pending states
        var todoTasks: Int {
            tasks.filter {
                $0.status == .notStarted ||
                $0.status == .waitingFor ||
                $0.status == .onHoldByClient
            }.count
        }
        
        // Total for percentage calculation (use displayed tasks sum to avoid 'cancelled' skewing bars if not shown)
        // Or use total tasks. Let's use the sum of these 3 buckets so the bars add up to 100% of "Active Lifecycle"
        var total: Int {
            let sum = completedTasks + inProgressTasks + todoTasks
            return max(sum, 1)
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.gray)
                    Text("Task Status Breakdown")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.top, 4)
                
                VStack(spacing: 24) {
                    // Completed Row
                    StatusProgressRow(
                        label: "Completed",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        count: completedTasks,
                        total: total
                    )
                    
                    // In Progress Row
                    StatusProgressRow(
                        label: "In Progress",
                        icon: "clock.fill",
                        color: .cyan, // "Same to same" - Cyan/Blue
                        count: inProgressTasks,
                        total: total
                    )
                    
                    // To-Do Row
                    StatusProgressRow(
                        label: "To-Do",
                        icon: "list.bullet",
                        color: .gray, // Dark gray in image
                        count: todoTasks,
                        total: total
                    )
                }
            }
            .padding()
            .background(Color.black)
            .cornerRadius(12)
            .shadow(color: .white.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    struct StatusProgressRow: View {
        let label: String
        let icon: String
        let color: Color
        let count: Int
        let total: Int
        
        var percentage: Double {
            return total > 0 ? Double(count) / Double(total) : 0
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                // Label Row
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.subheadline)
                    
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(count) tasks")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 14)
                        
                        // Fill
                        Capsule()
                            .fill(color)
                            .frame(width: max(0, geo.size.width * percentage), height: 14)
                        
                        // Percentage Text (Dynamic placement)
                        if percentage > 0.05 { // Only show if visible enough
                            HStack {
                                Spacer()
                                Text("\(Int(percentage * 100))%")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.trailing, 6)
                            }
                            .frame(width: max(0, geo.size.width * percentage))
                        }
                    }
                }
                .frame(height: 14)
            }
        }
    }
    
    // MARK: - Priority Distribution Component
    struct PriorityDistributionView: View {
        let tasks: [Task]
        
        // Counts (Excluding Completed/Cancelled to show only active load)
        var activeTasks: [Task] {
            tasks.filter { $0.status != .completed && $0.status != .canceled }
        }
        
        var highCount: Int { activeTasks.filter { $0.priority == .p1 }.count }
        var mediumCount: Int { activeTasks.filter { $0.priority == .p2 }.count }
        var lowCount: Int { activeTasks.filter { $0.priority == .p3 }.count }
        
        var total: Int { max(activeTasks.count, 1) }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.gray)
                    Text("Priority Distribution")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.top, 4)
                
                VStack(spacing: 20) {
                    // High Priority
                    PriorityRow(
                        label: "High",
                        color: Color(red: 1.0, green: 0.8, blue: 0.8), // Light Red Bg
                        textColor: Color(red: 0.8, green: 0.0, blue: 0.0), // Dark Red Text
                        barColor: Color.gray.opacity(0.3),
                        progressColor: .red,
                        count: highCount,
                        total: total
                    )
                    
                    // Medium Priority
                    PriorityRow(
                        label: "Medium",
                        color: Color(red: 1.0, green: 0.95, blue: 0.8), // Light Yellow Bg
                        textColor: Color(red: 0.7, green: 0.5, blue: 0.0), // Dark Yellow/Brown Text
                        progressColor: .orange,
                        count: mediumCount,
                        total: total
                    )
                    
                    // Low Priority
                    PriorityRow(
                        label: "Low",
                        color: Color(red: 0.8, green: 1.0, blue: 0.8), // Light Green Bg
                        textColor: Color(red: 0.0, green: 0.5, blue: 0.0), // Dark Green Text
                        progressColor: .green,
                        count: lowCount,
                        total: total
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .cornerRadius(12)
            .shadow(color: .white.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    struct PriorityRow: View {
        let label: String
        let color: Color
        let textColor: Color
        // Added barColor (track color) to satisfy the call site
        var barColor: Color = Color.gray.opacity(0.3)
        let progressColor: Color
        let count: Int
        let total: Int
        
        var percentage: Double {
            return total > 0 ? Double(count) / Double(total) : 0
        }
        
        var body: some View {
            HStack(spacing: 12) {
                // Label Badge
                Text(label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(textColor)
                    .frame(width: 60, height: 24)
                    .background(color)
                    .cornerRadius(4)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(progressColor)
                            .frame(width: max(0, geo.size.width * percentage), height: 6)
                    }
                }
                .frame(height: 6)
                
                // Count
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 20, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Tasks By Project Component
    struct TasksByProjectView: View {
        let tasks: [Task]
        
        // Aggregate by Project Name
        struct ProjectStat: Identifiable {
            let id = UUID()
            let name: String
            let count: Int
            let percentage: Double
        }
        
        var projectStats: [ProjectStat] {
            // User requested to see ALL tasks for the project (Total count), so we do NOT filter out completed.
            let grouped = Dictionary(grouping: tasks) { $0.project?.name ?? "Unknown Project" }
            let total = max(Double(tasks.count), 1)
            
            return grouped.map { (key, value) in
                ProjectStat(name: key, count: value.count, percentage: Double(value.count) / total)
            }.sorted { $0.count > $1.count } // Sort by most tasks
        }
        
        // Helper to generate consistent colors for project names
        func color(for projectName: String) -> Color {
            let colors: [Color] = [.blue, .purple, .pink, .orange, .yellow, .green, .cyan, .teal, .indigo, .mint]
            let hash = abs(projectName.hashValue)
            return colors[hash % colors.count]
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.gray)
                    Text("Tasks by Project")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.top, 4)
                
                VStack(spacing: 16) {
                    if projectStats.isEmpty {
                        Text("No projects found")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(projectStats.prefix(5)) { stat in // Show top 5
                            HStack(spacing: 12) {
                                // Dynamic Colored Indicator
                                Circle()
                                    .fill(color(for: stat.name))
                                    .frame(width: 8, height: 8)
                                
                                Text(stat.name)
                                    .font(.subheadline)
                                    .foregroundColor(.white) // Dark mode text
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text("\(stat.count)")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("(\(Int(stat.percentage * 100))%)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .top) // Align top to match neighbor height roughly
            .background(Color.black)
            .cornerRadius(12)
            .shadow(color: .white.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Resource Performance Component
    struct ResourcePerformanceView: View {
        let tasks: [Task]
        let employees: [EmployeeProfile]
        @State private var exportDate = Date()
        
        struct ResourceStat: Identifiable {
            let id = UUID()
            let name: String
            let email: String
            let role: String
            let total: Int
            let completed: Int
            let inProgress: Int
            let todo: Int
            let completionPercentage: Double
        }
        
        // Helper to calculate stats for a single group
        func calculateStat(assigneeName: String, taskList: [Task]) -> ResourceStat {
            let safeAssignee = assigneeName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Comprehensive Strategy to Find Employee Profile
            // 1. Exact Name
            // 2. Case-insensitive Name
            // 3. Exact ID
            // 4. Case-insensitive Email
            let employee = employees.first { $0.name == safeAssignee }
            ?? employees.first { $0.name.caseInsensitiveCompare(safeAssignee) == .orderedSame }
            ?? employees.first { $0.id == safeAssignee }
            ?? employees.first { $0.email.caseInsensitiveCompare(safeAssignee) == .orderedSame }
            
            let name = employee?.name ?? safeAssignee
            let email = employee?.email ?? (employee != nil ? "No Email" : "")
            
            // Role Resolution
            // Check roleType -> position -> Fallback
            // Special handling: If the name explicitly says "Super Admin", show that.
            var role = employee?.roleType ?? employee?.position ?? "User"
            if role == "User" || role.isEmpty {
                if name.localizedCaseInsensitiveContains("Admin") {
                    role = "Admin"
                }
                if name.localizedCaseInsensitiveContains("Super") {
                    role = "Super Admin"
                }
            }
            
            let total = taskList.count
            let completed = taskList.filter { $0.status == .completed }.count
            let inProgress = taskList.filter { $0.status == .inProgress || $0.status == .stuck || $0.status == .needHelp }.count
            let todo = taskList.filter { $0.status == .notStarted || $0.status == .waitingFor }.count
            
            let pct = total > 0 ? Double(completed) / Double(total) * 100 : 0
            
            // Format "Unassigned" correctly
            let displayName = (name.isEmpty || name == "Unassigned") ? "Unassigned" : name
            let displayRole = (displayName == "Unassigned") ? "-" : role
            
            return ResourceStat(
                name: displayName,
                email: email,
                role: displayRole,
                total: total,
                completed: completed,
                inProgress: inProgress,
                todo: todo,
                completionPercentage: pct
            )
        }
        
        var stats: [ResourceStat] {
            // Group by assignedTo (Assuming it's a Name or ID string matching 'assignedTo' in Task)
            let grouped = Dictionary(grouping: tasks) { $0.assignedTo }
            
            let result: [ResourceStat] = grouped.map { (assigneeName, taskList) in
                calculateStat(assigneeName: assigneeName, taskList: taskList)
            }
            
            return result.sorted { $0.total > $1.total }
        }
        
        func generateCSV() -> URL {
            let fileName = "ResourcePerformance.csv"
            let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            var csvString = "Resource,Email,Role,Total Tasks,Completed,In Progress,To-Do,Completion %\n"
            
            for stat in stats {
                let row = "\"\(stat.name)\",\"\(stat.email)\",\"\(stat.role)\",\(stat.total),\(stat.completed),\(stat.inProgress),\(stat.todo),\(String(format: "%.1f", stat.completionPercentage))%\n"
                csvString.append(row)
            }
            
            do {
                try csvString.write(to: path, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to create CSV: \(error)")
            }
            return path
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.gray)
                    Text("Resource Performance")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    ShareLink(item: generateCSV(), preview: SharePreview("Resource Performance", image: Image(systemName: "tablecells"))) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Excel")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 4)
                
                Text("Performance breakdown by team member")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Table content
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Table Header
                        HStack(spacing: 20) {
                            Text("Resource")
                                .frame(width: 150, alignment: .leading)
                            Text("Role")
                                .frame(width: 100, alignment: .leading)
                            Text("Total Tasks")
                                .frame(width: 90, alignment: .center)
                            Text("Completed")
                                .frame(width: 80, alignment: .center)
                            Text("In Progress")
                                .frame(width: 80, alignment: .center)
                            Text("To-Do")
                                .frame(width: 60, alignment: .center)
                            Text("Completion %")
                                .frame(width: 100, alignment: .trailing)
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .padding(.bottom, 12)
                        .padding(.horizontal, 4)
                        
                        if stats.isEmpty {
                            Text("No data available")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .frame(height: 40)
                        } else {
                            ForEach(stats) { stat in
                                VStack(spacing: 0) {
                                    Divider().background(Color.gray.opacity(0.2))
                                    
                                    HStack(spacing: 20) {
                                        // Resource Name + Email
                                        HStack {
                                            Circle()
                                                .fill(Color.purple)
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Text(stat.name.prefix(1).uppercased())
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(stat.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                                if !stat.email.isEmpty {
                                                    Text(stat.email)
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        .frame(width: 150, alignment: .leading)
                                        
                                        // Role Badge
                                        Text(stat.role)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.purple)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.purple.opacity(0.15))
                                            .cornerRadius(4)
                                            .frame(width: 100, alignment: .leading)
                                        
                                        // Counts
                                        Text("\(stat.total)")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .frame(width: 90, alignment: .center)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption2)
                                            Text("\(stat.completed)")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                        .frame(width: 80, alignment: .center)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption2)
                                            Text("\(stat.inProgress)")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .frame(width: 80, alignment: .center)
                                        
                                        Text("\(stat.todo)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .frame(width: 60, alignment: .center)
                                        
                                        // Percentage
                                        Text("\(Int(stat.completionPercentage))%")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                            .frame(width: 100, alignment: .trailing)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 4)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .cornerRadius(12)
            .shadow(color: .white.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}
