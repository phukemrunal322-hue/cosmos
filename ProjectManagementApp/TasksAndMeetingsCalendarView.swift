import SwiftUI
import Foundation
import Combine

struct TasksAndMeetingsCalendarView: View {
    @State private var selectedDate = Date()
    @State private var selectedViewType: ViewType = .tasks
    @State private var showingNewMeeting = false
    @State private var showingNewTask = false
    @State private var prefilledDateForNewMeeting: Date? = nil
    @State private var prefilledDateForNewTask: Date? = nil
    @State private var selectedMeeting: Meeting? = nil
    @State private var showAIMOM = false
    @State private var currentMonth = Date()
    @State private var selectedMonthIndex = 0
    @State private var selectedYearIndex = 0
    @State private var showingActionSheet = false
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    enum ViewType: String, CaseIterable {
        case tasks = "Tasks"
        case meetings = "Meetings"
    }
    
    // Live tasks state for calendar view
    @State private var tasks: [Task] = []
    @State private var selfTasksExternal: [Task] = []
    
    @State private var meetings: [Meeting] = []
    
    private let calendar = Calendar.current
    // Calendar color palette (from spec)
    private let colorNoTasks = Color(red: 189.0/255.0, green: 189.0/255.0, blue: 189.0/255.0) // #BDBDBD
    private let colorDone = Color(red: 76.0/255.0, green: 175.0/255.0, blue: 80.0/255.0) // #4CAF50
    private let colorRecurringDarkGreen = Color(red: 255.0/255.0, green: 245.0/255.0, blue: 157.0/255.0) // light lemon yellow for recurring tasks
    private let colorScheduledBlue = Color(red: 33.0/255.0, green: 150.0/255.0, blue: 243.0/255.0) // #2196F3
    private let colorTodoAmber = Color(red: 255.0/255.0, green: 193.0/255.0, blue: 7.0/255.0) // #FFC107
    private let colorAdminPurple = Color(red: 156.0/255.0, green: 39.0/255.0, blue: 176.0/255.0) // #9C27B0
    private let colorSelfLightPurple = Color(red: 225.0/255.0, green: 190.0/255.0, blue: 231.0/255.0) // #E1BEE7
    private let colorOverdueRed = Color(red: 244.0/255.0, green: 67.0/255.0, blue: 54.0/255.0) // #F44336
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1)
        else { return [] }
        
        var dates: [Date] = []
        var currentDate = monthFirstWeek.start
        
        while currentDate < monthLastWeek.end {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    
    private var years: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        let startYear = 1752
        return Array(startYear...(currentYear + 100))
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

        return projects
    }
    
    func tasksForDate(_ date: Date) -> [Task] {
        let day = calendar.startOfDay(for: date)
        return tasks.filter { task in
            if task.isRecurring {
                // Recurring tasks: start from assigned/startDate, repeat by pattern, optional end date
                let start = calendar.startOfDay(for: task.startDate)
                if day < start { return false }

                if let end = task.recurringEndDate {
                    let endDay = calendar.startOfDay(for: end)
                    if day > endDay { return false }
                }

                let interval: Int = {
                    if let v = task.recurringDays, v > 0 { return v }
                    if let pattern = task.recurringPattern {
                        switch pattern {
                        case .daily: return 1
                        case .weekly: return 7
                        case .biweekly: return 14
                        case .monthly: return 30
                        case .custom: return 1
                        }
                    }
                    return 1
                }()

                let diff = calendar.dateComponents([.day], from: start, to: day).day ?? 0
                if diff < 0 { return false }
                return diff % interval == 0
            } else {
                // Normal tasks: show on due date
                return calendar.isDate(task.dueDate, inSameDayAs: date)
            }
        }
    }
    
    private func priorityBorderColor(for date: Date) -> Color? {
        let dateTasks = tasksForDate(date)
        if dateTasks.isEmpty { return nil }
        if dateTasks.contains(where: { $0.priority == .p1 }) { return .red }
        if dateTasks.contains(where: { $0.priority == .p2 }) { return .orange }
        if dateTasks.contains(where: { $0.priority == .p3 }) { return .blue }
        return nil
    }

    // Priority ranking helper (P1 highest)
    private func priorityRank(_ p: Priority) -> Int {
        switch p {
        case .p1: return 0
        case .p2: return 1
        case .p3: return 2
        }
    }

    // Up to three priority dots for a given date, ordered by priority
    private func priorityDotsColors(for date: Date) -> [Color] {
        let dateTasks = tasksForDate(date)
        if dateTasks.isEmpty { return [] }
        let sorted = dateTasks.sorted { priorityRank($0.priority) < priorityRank($1.priority) }
        let top = Array(sorted.prefix(3))
        return top.map { t in
            switch t.priority {
            case .p1: return Color.red
            case .p2: return Color.orange
            case .p3: return Color.blue
            }
        }
    }

    private func updateTaskStatus(task: Task, to newStatus: TaskStatus) {
        let projectId = task.project?.documentId
        let uid = authService.currentUid
        let email = authService.currentUser?.email
        FirebaseService.shared.updateTaskStatus(
            title: task.title,
            projectId: projectId,
            forUserUid: uid,
            userEmail: email,
            to: newStatus,
            completion: nil
        )
        FirebaseService.shared.updateSelfTaskStatus(
            title: task.title,
            projectId: projectId,
            forUserUid: uid,
            userEmail: email,
            to: newStatus,
            completion: nil
        )
    }
    
    // Split large body into smaller views for faster type-checking
    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // View Type Selector
                viewTypeSelectorSection
                summaryCountHeader
                calendarSection
                selectedItemsSection
                secondarySections
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
    }

    private var summaryCountHeader: some View {
        HStack {
            if selectedViewType == .tasks {
                Text("Total Tasks: \(tasksForDate(selectedDate).count)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Text("Total Meetings: \(meetingsForDate(selectedDate).count)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(.background)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.05), radius: 2)
    }
    
    @ViewBuilder
    private var selectedItemsSection: some View {
        if selectedViewType == .tasks {
            // For tasks, we show date-specific lists below (pending/completed), so no extra top section
            EmptyView()
        } else {
            if !meetingsForDate(selectedDate).isEmpty {
                selectedDateMeetingsSection
            }
        }
    }
    
    @ViewBuilder
    private var secondarySections: some View {
        if selectedViewType == .tasks {
            upcomingTasksSection
            completedTasksSection
        } else {
            upcomingMeetingsSection
            pastMeetingsSection
        }
    }
    
    private var floatingButtons: some View {
        VStack(spacing: 16) {
            // Quick action buttons that appear when FAB is pressed
            if showingActionSheet {
                VStack(spacing: 12) {
                    // Schedule Meeting Button
                    Button(action: {
                        showingActionSheet = false
                        prefilledDateForNewMeeting = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        showingNewMeeting = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("Schedule Meeting")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    // Create Task Button
                    Button(action: {
                        showingActionSheet = false
                        prefilledDateForNewTask = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                        showingNewTask = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.square.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("Create Task")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Main Floating Action Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingActionSheet.toggle()
                }
            }) {
                Image(systemName: showingActionSheet ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(showingActionSheet ? Color.red : Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .rotationEffect(.degrees(showingActionSheet ? 90 : 0))
            }
        }
        .padding(.trailing, 24)
        .padding(.bottom, 24)
    }

    func meetingsForDate(_ date: Date) -> [Meeting] {
        return meetings.filter { meeting in
            calendar.isDate(meeting.date, inSameDayAs: date)
        }
    }
    
    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    func selectMonthAndYear(month: String, year: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        if let newDate = formatter.date(from: "\(month) \(year)") {
            currentMonth = newDate
        }
    }
    
    // Function to get the dominant status color for a date
    private func dateStatusColor(for date: Date) -> Color {
        if selectedViewType == .tasks {
            let dateTasks = tasksForDate(date)
            if dateTasks.isEmpty { return colorNoTasks } // no tasks → grey
            // Any recurring task on this date → dark green highlight
            if dateTasks.contains(where: { $0.isRecurring }) {
                return colorRecurringDarkGreen
            }
            // only self tasks → no color
            if dateTasks.allSatisfy({ $0.taskType == .selfTask }) { return .clear }
            // any non-self task → yellow
            return colorTodoAmber
        } else {
            let dateMeetings = meetingsForDate(date)
            if dateMeetings.isEmpty { return colorNoTasks } // no meetings → grey
            // meetings present → blue
            return colorScheduledBlue
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mainScrollContent
            floatingButtons
        }
        .navigationTitle("Tasks & Meetings")
        .sheet(isPresented: $showingNewMeeting) {
            NewMeetingView(prefilledDate: prefilledDateForNewMeeting) { newMeeting in
                meetings.append(newMeeting)
                selectedDate = newMeeting.date
            }
        }
        .sheet(isPresented: $showingNewTask) {
            CreateTaskView(
                taskType: .selfTask,
                projects: employeeProjects,
                prefilledAssignedDate: prefilledDateForNewTask,
                prefilledDueDate: prefilledDateForNewTask
            ) { taskData in
                let newTask = Task(
                    title: taskData.title,
                    description: taskData.description,
                    status: taskData.status,
                    priority: taskData.priority,
                    startDate: taskData.assignedDate,
                    dueDate: taskData.dueDate,
                    assignedTo: authService.currentUser?.email ?? "Current User",
                    comments: [],
                    department: nil,
                    project: taskData.project,
                    taskType: .selfTask,
                    isRecurring: taskData.isRecurring,
                    recurringPattern: taskData.recurringPattern,
                    recurringDays: taskData.recurringDays,
                    recurringEndDate: taskData.recurringEndDate,
                    subtask: taskData.subtask,
                    weightage: taskData.weightage,
                    subtaskStatus: nil
                )
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                firebaseService.createTask(newTask, assignedUid: uid, assignedEmail: email, completion: nil)
                firebaseService.saveSelfTask(task: newTask, createdByUid: uid, createdByEmail: email) { _ in }
                selectedDate = taskData.assignedDate
            }
        }
        .sheet(item: $selectedMeeting) { meeting in
            if showAIMOM {
                AI_MOMView(meeting: meeting)
            } else {
                MeetingDetailView(meeting: meeting)
            }
        }
        .onAppear {
            // Start events listener for current employee when meetings view is active
            if selectedViewType == .meetings && meetings.isEmpty {
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                firebaseService.fetchEventsForEmployee(userUid: uid, userEmail: email)
            }
            // Start tasks listener for current user
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            let name = authService.currentUser?.name
            firebaseService.fetchTasks(forUserUid: uid, userEmail: email, userName: name)
            // Also listen to '/selfTasks' for current user
            firebaseService.fetchSelfTasks(forUserUid: uid, userEmail: email) { tasks in
                // Update external self tasks and merge into calendar
                self.selfTasksExternal = tasks
                var aggregated = firebaseService.tasks
                aggregated.append(contentsOf: tasks)
                // Deduplicate by title + due date seconds
                var seen = Set<String>()
                let merged = aggregated.filter { t in
                    let key = t.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + "|" + String(Int(t.dueDate.timeIntervalSince1970))
                    if seen.contains(key) { return false }
                    seen.insert(key)
                    return true
                }
                self.tasks = merged
            }
            // Preload employees so NewMeetingView's Employee picker is ready on first open
            if firebaseService.employees.isEmpty {
                firebaseService.fetchEmployees()
            }
            let currentMonthIndex = calendar.component(.month, from: currentMonth) - 1
            let currentYear = calendar.component(.year, from: currentMonth)
            if let yearIndex = years.firstIndex(of: currentYear) {
                selectedMonthIndex = currentMonthIndex
                selectedYearIndex = yearIndex
            }
        }
        .onReceive(firebaseService.$tasks) { newTasks in
            // Merge '/tasks' with '/selfTasks' for the calendar
            var aggregated = newTasks
            aggregated.append(contentsOf: selfTasksExternal)
            var seen = Set<String>()
            self.tasks = aggregated.filter { t in
                let key = t.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + "|" + String(Int(t.dueDate.timeIntervalSince1970))
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
        }
        .onReceive(firebaseService.$events) { events in
            self.meetings = events
        }
        .onChange(of: selectedViewType) { newValue in
            if newValue == .meetings && meetings.isEmpty {
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                firebaseService.fetchEventsForEmployee(userUid: uid, userEmail: email)
            }
        }
        .onTapGesture {
            // Dismiss action sheet when tapping outside
            if showingActionSheet {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingActionSheet = false
                }
            }
        }
    }
    
    private var viewTypeSelectorSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("View")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Menu {
                    ForEach(ViewType.allCases, id: \.self) { type in
                        Button(action: {
                            selectedViewType = type
                        }) {
                            HStack {
                                Text(type.rawValue)
                                if selectedViewType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedViewType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var calendarSection: some View {
        VStack(spacing: 15) {
            // Month Header with Dropdowns
            HStack {
                Button(action: {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
                    updateSelectedIndices()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 15) {
                    // Month Dropdown
                    Menu {
                        ForEach(0..<months.count, id: \.self) { index in
                            Button(action: {
                                selectedMonthIndex = index
                                updateCurrentMonth()
                            }) {
                                HStack {
                                    Text(months[index])
                                    if selectedMonthIndex == index {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(months[selectedMonthIndex])
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Year Dropdown
                    Menu {
                        ScrollViewReader { proxy in
                            ScrollView {
                                ForEach(0..<years.count, id: \.self) { index in
                                    Button(action: {
                                        selectedYearIndex = index
                                        updateCurrentMonth()
                                    }) {
                                        HStack {
                                            Text(String(years[index]))
                                            if selectedYearIndex == index {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .id(index)
                                }
                            }
                            .frame(maxHeight: 300)
                            .onAppear {
                                proxy.scrollTo(selectedYearIndex, anchor: .center)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(String(years[selectedYearIndex]))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
                    updateSelectedIndices()
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                        .font(.headline)
                }
            }
            .padding(.horizontal)
            
            // Weekday Headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            // Calendar Days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(daysInMonth, id: \.self) { date in
                    dayView(for: date)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private func updateCurrentMonth() {
        let month = months[selectedMonthIndex]
        let year = years[selectedYearIndex]
        selectMonthAndYear(month: month, year: year)
    }
    
    private func updateSelectedIndices() {
        let currentMonthIndex = calendar.component(.month, from: currentMonth) - 1
        let currentYear = calendar.component(.year, from: currentMonth)
        if let yearIndex = years.firstIndex(of: currentYear) {
            selectedMonthIndex = currentMonthIndex
            selectedYearIndex = yearIndex
        }
    }
    
    private func dayView(for date: Date) -> some View {
        let hasItems = selectedViewType == .tasks ? !tasksForDate(date).isEmpty : !meetingsForDate(date).isEmpty
        let statusColor = dateStatusColor(for: date)
        let isCurrent = isCurrentMonth(date)
        
        return VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isCurrent ? (hasItems ? statusColor : colorNoTasks) : Color.gray.opacity(0.15))
                    .frame(width: 30, height: 30)
                
                // Today's date has special styling
                if isToday(date) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                }
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isToday(date) ? .bold : .regular)
                    .foregroundColor(dayTextColor(for: date, hasItems: hasItems))
            }
            .frame(width: 34, height: 34)
        }
        .onTapGesture {
            selectedDate = date
        }
    }
    
    private func dayTextColor(for date: Date, hasItems: Bool) -> Color {
        if !isCurrentMonth(date) { return .gray }
        if isToday(date) { return .white }
        if selectedViewType == .tasks {
            let dateTasks = tasksForDate(date)
            if dateTasks.isEmpty { return .black }
            if dateTasks.allSatisfy({ $0.taskType == .selfTask }) { return .primary }
            return .black // yellow background
        } else {
            if meetingsForDate(date).isEmpty { return .black }
            return .white // blue background
        }
    }
    
    private var selectedDateTasksSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Tasks on \(selectedDate.formatted(date: .complete, time: .omitted))")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(tasksForDate(selectedDate).count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            ForEach(tasksForDate(selectedDate)) { task in
                CalendarTaskCard(task: task)
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var selectedDateMeetingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Meetings on \(selectedDate.formatted(date: .complete, time: .omitted))")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(meetingsForDate(selectedDate).count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            ForEach(meetingsForDate(selectedDate)) { meeting in
                EmployeeMeetingCard(
                    meeting: meeting,
                    isUpcoming: meeting.date > Date()
                ) {
                    selectedMeeting = meeting
                    if meeting.date <= Date() {
                        showAIMOM = true
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var upcomingTasksSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(calendar.isDate(selectedDate, inSameDayAs: Date())
                     ? "Today's Tasks"
                     : "Tasks on \(selectedDate.formatted(date: .complete, time: .omitted))")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(tasksForDate(selectedDate).filter { $0.status != .completed }.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }
            
            ForEach(tasksForDate(selectedDate).filter { $0.status != .completed }) { task in
                CalendarTaskCard(task: task) { newStatus in
                    updateTaskStatus(task: task, to: newStatus)
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(calendar.isDate(selectedDate, inSameDayAs: Date())
                     ? "Today's Completed Tasks"
                     : "Completed Tasks on \(selectedDate.formatted(date: .complete, time: .omitted))")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(tasksForDate(selectedDate).filter { $0.status == .completed }.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            ForEach(tasksForDate(selectedDate).filter { $0.status == .completed }) { task in
                CalendarTaskCard(task: task) { newStatus in
                    updateTaskStatus(task: task, to: newStatus)
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var upcomingMeetingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(calendar.isDate(selectedDate, inSameDayAs: Date())
                     ? "Today's Meetings"
                     : "Meetings on \(selectedDate.formatted(date: .complete, time: .omitted))")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(meetingsForDate(selectedDate).filter { $0.status == .scheduled || $0.status == .inProgress }.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            ForEach(meetingsForDate(selectedDate).filter { $0.status == .scheduled || $0.status == .inProgress }) { meeting in
                EmployeeMeetingCard(
                    meeting: meeting,
                    isUpcoming: true
                ) {
                    selectedMeeting = meeting
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var pastMeetingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(calendar.isDate(selectedDate, inSameDayAs: Date())
                     ? "Today's Completed Meetings"
                     : "Completed Meetings on \(selectedDate.formatted(date: .complete, time: .omitted))")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(meetingsForDate(selectedDate).filter { $0.status == .completed }.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            ForEach(meetingsForDate(selectedDate).filter { $0.status == .completed }) { meeting in
                EmployeeMeetingCard(
                    meeting: meeting,
                    isUpcoming: false
                ) {
                    selectedMeeting = meeting
                    showAIMOM = true
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

// MARK: - Calendar Task Card
struct CalendarTaskCard: View {
    let task: Task
    let onChangeStatus: (TaskStatus) -> Void
    
    init(task: Task, onChangeStatus: @escaping (TaskStatus) -> Void = { _ in }) {
        self.task = task
        self.onChangeStatus = onChangeStatus
    }
    
    var priorityDisplay: String {
        switch task.priority {
        case .p1: return "High"
        case .p2: return "Medium"
        case .p3: return "Low"
        }
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .p1: return .green
        case .p2: return .yellow
        case .p3: return .red
        }
    }
    
    var statusColor: Color {
        switch task.status {
        case .completed: return .green
        case .inProgress: return .blue
        case .notStarted: return .gray
        case .stuck: return .orange
        case .waitingFor: return .purple
        case .onHoldByClient: return .orange
        case .needHelp: return .red
        case .canceled: return .gray
        }
    }
    
    var isOverdue: Bool {
        let comparison = Calendar.current.compare(task.dueDate, to: Date(), toGranularity: .day)
        return comparison == .orderedAscending && task.status != .completed
    }

    var isDueToday: Bool {
        Calendar.current.isDateInToday(task.dueDate) && task.status != .completed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title & description
            Text(task.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(task.description)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .lineLimit(1)
            
            // Badges row (priority, status, recurring, overdue/due today)
            HStack(spacing: 8) {
                // Priority badge
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                    Text(priorityDisplay)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(priorityColor.opacity(0.15))
                .foregroundColor(priorityColor)
                .cornerRadius(4)
                
                // Status badge (read-only in calendar)
                HStack(spacing: 4) {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : task.status == .inProgress ? "arrow.clockwise.circle.fill" : "circle")
                        .font(.system(size: 10))
                    Text(task.status.rawValue)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
                .cornerRadius(4)
                
                // Recurring badge
                if task.isRecurring {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10))
                        if let days = task.recurringDays {
                            Text("\(days)d")
                                .font(.system(size: 11, weight: .medium))
                        } else if let pattern = task.recurringPattern {
                            Text(pattern.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
                }
                
                if isOverdue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Overdue")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(4)
                } else if isDueToday {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 10))
                        Text("Due Today")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
                }
            }
            
            // Dates row (Due / Assigned)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(isOverdue ? .red : (task.isRecurring ? Color.orange : Color.red))
                    if isOverdue {
                        Text("Overdue")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    } else {
                        Text("Due: \(task.dueDate.formatted(date: .numeric, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundColor(task.isRecurring ? Color.orange : .gray)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundColor(task.isRecurring ? Color.orange : .purple)
                    Text("Assigned: \(task.startDate.formatted(date: .numeric, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundColor(task.isRecurring ? Color.orange : .gray)
                }
            }
            
            // Recurring summary row
            if task.isRecurring, let endDate = task.recurringEndDate {
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    Text("Recurring Task")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.purple)
                    Text("• End: \(endDate.formatted(date: .numeric, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}
