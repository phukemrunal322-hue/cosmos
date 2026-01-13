import SwiftUI
import Combine

struct EmployeeMeetingsView: View {
    @State private var selectedDate = Date()
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
    
    @State private var meetings: [Meeting] = []
    
    @ObservedObject private var authService = FirebaseAuthService.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    private let calendar = Calendar.current
    
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
    
    private func isAdminCreated(_ meeting: Meeting) -> Bool {
        let currentUid = authService.currentUid
        let currentEmail = authService.currentUser.map { user in
            user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        if let creatorUid = meeting.createdByUid,
           let currentUid = currentUid,
           !creatorUid.isEmpty,
           !currentUid.isEmpty {
            // If creator and current user UID match, it's self-created (not admin)
            return creatorUid != currentUid
        }
        if let creatorEmail = meeting.createdByEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let currentEmail = currentEmail,
           !currentEmail.isEmpty {
            // If creator and current user email match, it's self-created (not admin)
            return creatorEmail != currentEmail
        }
        return false
    }
    
    // Function to get the dominant status color for a date
    private func dateStatusColor(for date: Date) -> Color {
        let dateMeetings = meetingsForDate(date)
        
        if dateMeetings.isEmpty {
            return .clear
        }
        
        // Priority order: cancelled > inProgress > completed > scheduled
        if dateMeetings.contains(where: { $0.status == .cancelled }) {
            return .red
        } else if dateMeetings.contains(where: { $0.status == .inProgress }) {
            return .orange
        } else if dateMeetings.contains(where: { $0.status == .completed }) {
            return .green
        } else if dateMeetings.contains(where: { $0.status == .scheduled && isAdminCreated($0) }) {
            return .yellow
        }
        
        return .clear
    }
    
    var upcomingMeetings: [Meeting] {
        meetings.filter { $0.date > Date() && $0.status == .scheduled }
    }
    
    var pastMeetings: [Meeting] {
        meetings.filter { $0.date <= Date() && $0.status == .completed }
    }
    
    var todaysMeetings: [Meeting] {
        upcomingMeetings.filter { Calendar.current.isDateInToday($0.date) }
    }
    
    var nonTodayUpcomingMeetings: [Meeting] {
        upcomingMeetings.filter { !Calendar.current.isDateInToday($0.date) }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    calendarSection
                    
                    if !meetingsForDate(selectedDate).isEmpty {
                        selectedDateMeetingsSection
                    }
                    
                    todaysMeetingsSection
                    upcomingMeetingsSection
                    meetingHistorySection
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            
            // Floating Action Button
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
        .navigationTitle("Meetings & Calendar")
        .sheet(isPresented: $showingNewMeeting) {
            NewMeetingView(prefilledDate: prefilledDateForNewMeeting) { newMeeting in
                selectedDate = newMeeting.date
            }
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskView(prefilledDate: prefilledDateForNewTask) { taskData in
                // Create a meeting that represents the task
                let taskMeeting = Meeting(
                    title: "Task: \(taskData.title)",
                    date: taskData.startDate,
                    duration: 0,
                    participants: [],
                    agenda: "Task: \(taskData.title)\nProject: \(taskData.project)\nStart: \(taskData.startDate.formatted())\nEnd: \(taskData.endDate.formatted())",
                    meetingType: .oneOnOne,
                    project: taskData.project,
                    status: .scheduled,
                    mom: nil,
                    location: "Personal",
                    createdByUid: authService.currentUid,
                    createdByEmail: authService.currentUser?.email
                )
                meetings.append(taskMeeting)
                selectedDate = taskData.startDate
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
            if meetings.isEmpty {
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                firebaseService.fetchEventsForEmployee(userUid: uid, userEmail: email)
            }
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
        .onReceive(firebaseService.$events) { events in
            self.meetings = events
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
                                            Text("\(years[index])")
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
                            Text("\(years[selectedYearIndex])")
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
        let hasMeetings = !meetingsForDate(date).isEmpty
        let statusColor = dateStatusColor(for: date)
        
        return VStack(spacing: 4) {
            ZStack {
                // Background circle with status color
                Circle()
                    .fill(hasMeetings ? statusColor : Color.clear)
                    .frame(width: 30, height: 30)
                
                // Border for selected date
                if isSelected(date) && !isToday(date) {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 34, height: 34)
                }
                
                // Today's date has special styling
                if isToday(date) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                }
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isToday(date) ? .bold : .regular)
                    .foregroundColor(dayTextColor(for: date, hasMeetings: hasMeetings))
            }
            .frame(width: 34, height: 34)
            
            // Show meeting count for dates with multiple meetings
            if meetingsForDate(date).count > 1 {
                Text("\(meetingsForDate(date).count)")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .onTapGesture {
            selectedDate = date
            if meetingsForDate(date).isEmpty {
                prefilledDateForNewMeeting = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
                showingNewMeeting = true
            }
        }
    }
    
    private func dayTextColor(for date: Date, hasMeetings: Bool) -> Color {
        if isToday(date) {
            return .white
        } else if hasMeetings {
            // For dates with meetings, use contrasting text color
            let statusColor = dateStatusColor(for: date)
            return statusColor == .yellow ? .black : .white
        } else if isCurrentMonth(date) {
            return .primary
        } else {
            return .gray
        }
    }
    
    private func dayBackgroundColor(for date: Date) -> Color {
        if isToday(date) {
            return Color.blue
        } else if isSelected(date) {
            return Color.blue.opacity(0.2)
        } else {
            return Color.clear
        }
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
    
    private var todaysMeetingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Today's Schedule")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if todaysMeetings.isEmpty {
                Text("No meetings scheduled for today")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(todaysMeetings) { meeting in
                    EmployeeMeetingCard(
                        meeting: meeting,
                        isUpcoming: true
                    ) {
                        selectedMeeting = meeting
                    }
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
                Text("Upcoming Meetings")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(upcomingMeetings.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            if nonTodayUpcomingMeetings.isEmpty {
                Text("No upcoming meetings")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(nonTodayUpcomingMeetings) { meeting in
                    EmployeeMeetingCard(
                        meeting: meeting,
                        isUpcoming: true
                    ) {
                        selectedMeeting = meeting
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var meetingHistorySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Meeting History")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(pastMeetings.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            if pastMeetings.isEmpty {
                Text("No past meetings")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(pastMeetings.prefix(3)) { meeting in
                    EmployeeMeetingCard(
                        meeting: meeting,
                        isUpcoming: false
                    ) {
                        selectedMeeting = meeting
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
}

// MARK: - New Task View
struct NewTaskView: View {
    @Environment(\.dismiss) private var dismiss
    let prefilledDate: Date?
    let onSave: (TaskData) -> Void
    
    @State private var title = ""
    @State private var project = ""
    @State private var startDate: Date
    @State private var endDate: Date
    
    init(prefilledDate: Date?, onSave: @escaping (TaskData) -> Void) {
        self.prefilledDate = prefilledDate
        self.onSave = onSave
        let initialDate = prefilledDate ?? Date()
        _startDate = State(initialValue: initialDate)
        _endDate = State(initialValue: initialDate.addingTimeInterval(86400)) // Default: 1 day later
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                    TextField("Project Name", text: $project)
                }
                
                Section(header: Text("Dates")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Date", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Create New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create Task") {
                        let taskData = TaskData(
                            title: title,
                            project: project.isEmpty ? "General" : project,
                            startDate: startDate,
                            endDate: endDate
                        )
                        onSave(taskData)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// Simple struct to pass task data
struct TaskData {
    let title: String
    let project: String
    let startDate: Date
    let endDate: Date
}

struct EmployeeMeetingCard: View {
    let meeting: Meeting
    let isUpcoming: Bool
    let action: () -> Void
    
    var statusColor: Color {
        switch meeting.status {
        case .scheduled: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Meeting Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(meeting.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(meeting.meetingType.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if let project = meeting.project {
                        Text(project)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(meeting.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(meeting.date, style: .time)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if isUpcoming {
                        Text(meeting.date, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Duration and Participants
            HStack {
                Label("\(meeting.duration) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Label("\(meeting.participants.count) people", systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
        .onTapGesture {
            action()
        }
    }
}
