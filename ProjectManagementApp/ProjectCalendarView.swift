import SwiftUI

struct ProjectCalendarView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var currentDate = Date()
    @State private var selectedDate = Date()
    @State private var showCreateMeetingSheet = false
    @State private var showCreateTaskSheet = false
    
    // Filters
    @State private var selectedType = "All Types"
    @State private var selectedStatus = "All Status"
    @State private var selectedProject = "All Projects"
    @State private var selectedEmployee = "All Employees"
    
    // Filter Options
    private let taskTypes = ["All Types", "Meetings", "Tasks"]
    private let taskStatuses = ["All Status", "TODO", "In Progress", "Stuck", "Waiting For", "Done", "Canceled", "Scheduled", "Completed"]
    
    // Calendar Logic
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    // computed properties
    private var year: Int { calendar.component(.year, from: currentDate) }
    private var month: Int { calendar.component(.month, from: currentDate) }
    
    // Filtered Data
    private var filteredTasks: [Task] {
        firebaseService.tasks.filter { task in
            let typeMatch: Bool
            if selectedType == "Meetings" {
                typeMatch = false
            } else {
                typeMatch = true
            }
            
            let statusMatch = selectedStatus == "All Status" || task.status.rawValue == selectedStatus
            let projectMatch = selectedProject == "All Projects" || (task.project?.name ?? "Unknown") == selectedProject
            let employeeMatch = selectedEmployee == "All Employees" || task.assignedTo == selectedEmployee || (task.assignedTo.contains(selectedEmployee))
            return typeMatch && statusMatch && projectMatch && employeeMatch
        }
    }
    
    private var filteredEvents: [Meeting] {
         firebaseService.events.filter { meeting in
             let typeMatch: Bool
             if selectedType == "Tasks" {
                 typeMatch = false
             } else {
                 typeMatch = true
             }
             
             let statusMatch = selectedStatus == "All Status" || meeting.status.rawValue == selectedStatus
             let projectMatch = selectedProject == "All Projects" || (meeting.project ?? "Unknown") == selectedProject
             let employeeMatch = selectedEmployee == "All Employees" || meeting.participants.contains(selectedEmployee)
             return typeMatch && statusMatch && projectMatch && employeeMatch
         }
    }
    
    // Add State
    @State private var editingMeeting: Meeting?
    @State private var showDayDetails = false

    // MARK: - Body
    var body: some View {
        ZStack {
             NavigationLink(destination: DayDetailsView(date: selectedDate), isActive: $showDayDetails) {
                 EmptyView()
             }
             
             GeometryReader { geometry in
                let isWide = geometry.size.width > 900
                
                ZStack(alignment: .bottomTrailing) {
                    if isWide {
                        HStack(spacing: 0) {
                            mainContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            Divider()
                            
                            sidePanelView
                                .frame(width: 350)
                                .background(Color(.systemBackground))
                        }
                    } else {
                        mainContent
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
        .sheet(isPresented: $showCreateMeetingSheet) {
            AdminCreateMeetingView()
        }
        .sheet(isPresented: $showCreateTaskSheet) {
            AdminCreateTaskView()
        }
        .sheet(item: $editingMeeting) { meeting in
            AdminCreateMeetingView(meetingToEdit: meeting)
        }
        .onAppear {
             // Fetch all data for Admin/SuperAdmin
             firebaseService.fetchTasks(forUserUid: nil, userEmail: nil)
             firebaseService.fetchEventsForEmployee(userUid: nil, userEmail: nil)
             
             if firebaseService.projects.isEmpty {
                 firebaseService.fetchProjects()
             }
             if firebaseService.employees.isEmpty {
                 firebaseService.fetchEmployees()
             }
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                statsView
                controlsBar
                calendarGrid
            }
            .padding(24)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project Calendar")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Manage meetings, tasks, milestones, and client interactions in one place.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Stats
    private var statsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ProjectStatCard(
                    title: "Total Scheduled",
                    value: "\(totalScheduledCount)",
                    color: .purple,
                    icon: "calendar"
                )
                
                ProjectStatCard(
                    title: "Approved Meetings",
                    value: "\(approvedMeetingsCount)",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                ProjectStatCard(
                    title: "Upcoming Deadlines",
                    value: "\(upcomingDeadlinesCount)",
                    color: .orange,
                    icon: "clock.fill"
                )
                
                ProjectStatCard(
                    title: "Pending Requests",
                    value: "\(pendingRequestsCount)",
                    color: .pink,
                    icon: "hourglass"
                )
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Controls
    private var controlsBar: some View {
        VStack(spacing: 16) {
            // Row 1: Month Navigation & Toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Left Arrow
                    Button(action: { moveMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    
                    // Month Year Text
                    Text(monthYearString)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(minWidth: 150)
                        .multilineTextAlignment(.center)
                    
                    // Right Arrow
                    Button(action: { moveMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    
                    // Add Event Button (Moved here, before Today)
                    Menu {
                        Button(action: { showCreateMeetingSheet = true }) {
                            Label("Add Event", systemImage: "calendar")
                        }
                        Button(action: { showCreateTaskSheet = true }) {
                            Label("Add Task", systemImage: "checklist")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.3), radius: 3, x: 0, y: 2)
                    }

                    // Today Button
                    Button(action: { currentDate = Date() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Today")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.indigo.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
            
            // Row 2: Filters Group (Dynamic)
            ViewThatFits {
                HStack(spacing: 12) {
                    filterMenu(title: selectedType, options: taskTypes, selection: $selectedType)
                    filterMenu(title: selectedStatus, options: taskStatuses, selection: $selectedStatus)
                    projectFilterMenu
                    employeeFilterMenu
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        filterMenu(title: selectedType, options: taskTypes, selection: $selectedType)
                        filterMenu(title: selectedStatus, options: taskStatuses, selection: $selectedStatus)
                        projectFilterMenu
                        employeeFilterMenu
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }
    
    // Generic Filter Menu
    private func filterMenu(title: String, options: [String], selection: Binding<String>) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: { selection.wrappedValue = option }) {
                    HStack {
                        Text(option)
                        if selection.wrappedValue == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    // Project Filter Menu (and Employee)
    private var projectFilterMenu: some View {
        Menu {
            Button("All Projects") { selectedProject = "All Projects" }
            ForEach(firebaseService.projects) { project in
                Button(project.name) { selectedProject = project.name }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedProject)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    private var employeeFilterMenu: some View {
        Menu {
            Button("All Employees") { selectedEmployee = "All Employees" }
            ForEach(firebaseService.employees) { employee in
                Button(employee.name) { selectedEmployee = employee.name }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedEmployee)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        VStack(spacing: 0) {
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12, corners: [.topLeft, .topRight])
            
            Divider()
            
            // Days
            let days = daysInCurrentMonth()
            let rows = days.chunked(into: 7)
            
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(rows[rowIndex], id: \.self) { date in
                            if let date = date {
                                DayCell(
                                    date: date,
                                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                    isToday: calendar.isDateInToday(date),
                                    events: eventsForDate(date)
                                )
                                .onTapGesture {
                                    selectedDate = date
                                    showDayDetails = true
                                }
                            } else {
                                Rectangle()
                                    .fill(Color(.systemBackground))
                                    .frame(height: 100)
                                    .frame(maxWidth: .infinity)
                            }
                            
                            if date != rows[rowIndex].last {
                                Divider()
                                   .frame(width: 1, height: 100)
                            }
                        }
                    }
                    Divider()
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Filter Logic Helpers
    private func moveMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentDate)
    }
    
    private func daysInCurrentMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentDate),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) 
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private var totalScheduledCount: Int {
        filteredEvents.count + filteredTasks.count
    }
    
    private var approvedMeetingsCount: Int {
        filteredEvents.filter { $0.status == .scheduled }.count
    }
    
    private var upcomingDeadlinesCount: Int {
        filteredTasks.filter { task in
            task.dueDate > Date() &&
            task.status != .completed &&
            task.status != .canceled
        }.count
    }
    
    private var pendingRequestsCount: Int {
        filteredTasks.filter { $0.status == .waitingFor || $0.status == .stuck }.count
    }


    // MARK: - Side Panel
    private var sidePanelView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Select a date")
                    .font(.headline)
                    .foregroundColor(.primary)
                Divider()
                    .frame(width: 40)
                    .padding(.top, 4)
            }
            
            if calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .year) { // Just a check
                // Selected Date Display
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text(selectedDate.formatted(date: .long, time: .omitted))
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    if eventsForDate(selectedDate).isEmpty {
                        Text("No events scheduled")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        // Event List
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(eventsForDate(selectedDate), id: \.id) { event in
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
                                    } else {
                                        // Task/Other Fallback
                                        HStack {
                                            Rectangle()
                                                .fill(event.color)
                                                .frame(width: 4)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(event.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Text(event.time)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(24)
    }
    
    // ...

    // Placeholder Event Logic
    struct CalendarEvent: Identifiable {
        let id = UUID()
        let title: String
        let time: String
        let color: Color
        let meeting: Meeting?
        let task: Task?
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        // Map real tasks/meetings here
        var events: [CalendarEvent] = []
        
        // Use Filtered Data
        let tasks = filteredTasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }
        for task in tasks {
            events.append(CalendarEvent(title: task.title, time: "Due Today", color: .orange, meeting: nil, task: task))
        }
        
        let meetings = filteredEvents.filter { calendar.isDate($0.date, inSameDayAs: date) }
        for meeting in meetings {
            events.append(CalendarEvent(title: meeting.title, time: meeting.date.formatted(date: .omitted, time: .shortened), color: .purple, meeting: meeting, task: nil))
        }
        
        return events
    }
    
    // ... (Keep existing stats vars)

}

// MARK: - Subcomponents

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let events: [ProjectCalendarView.CalendarEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? .blue : .primary)
                .padding(6)
                .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
                .clipShape(Circle())
            
            // Event Pills
            VStack(alignment: .leading, spacing: 2) {
                ForEach(events.prefix(3)) { event in
                    HStack(spacing: 2) {
                         Text(event.time.components(separatedBy: " ").first ?? "") // Just time part roughly
                            .font(.system(size: 8))
                         Text(event.title)
                            .fontWeight(.medium)
                     }
                     .font(.system(size: 9))
                     .foregroundColor(.blue)
                     .padding(.horizontal, 4)
                     .padding(.vertical, 2)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .background(Color.blue.opacity(0.1))
                     .cornerRadius(4)
                     .lineLimit(1)
                }
                if events.count > 3 {
                    Text("+\(events.count - 3) more")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                }
            }
            
            Spacer()
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemBackground))
        .contentShape(Rectangle()) // Make full cell tappable
    }
}

// Custom Stat Card for ProjectCalendarView
struct ProjectStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(width: 160, height: 140)
        .background(Color.black)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
