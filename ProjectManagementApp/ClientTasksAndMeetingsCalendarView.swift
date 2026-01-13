import SwiftUI
import Foundation
import Combine

struct ClientTasksAndMeetingsCalendarView: View {
    @State private var selectedDate = Date()
    @State private var showingMeetingDetail = false
    @State private var selectedMeeting: Meeting? = nil
    @State private var currentMonth = Date()
    @State private var selectedMonthIndex = 0
    @State private var selectedYearIndex = 0
    @State private var showingNewMeeting = false
    @State private var prefilledDateForNewMeeting: Date? = nil
    @State private var showingActionSheet = false
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var authService = FirebaseAuthService.shared
    @State private var didStartEventsListener = false
    
    @State private var meetings: [Meeting] = []
    
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
    
    var upcomingMeetings: [Meeting] {
        meetingsForDate(Date()).filter { $0.status == .scheduled || $0.status == .inProgress }
    }
    
    var pastMeetings: [Meeting] {
        meetingsForDate(Date()).filter { $0.status == .completed || $0.status == .cancelled }
    }
    
    // Function to get the dominant status color for a date
    private func dateStatusColor(for date: Date) -> Color {
        let dateMeetings = meetingsForDate(date)
        if dateMeetings.isEmpty { return .clear }
        
        // Priority order: cancelled > inProgress > completed > scheduled
        if dateMeetings.contains(where: { $0.status == .cancelled }) {
            return .red
        } else if dateMeetings.contains(where: { $0.status == .inProgress }) {
            return .orange
        } else if dateMeetings.contains(where: { $0.status == .completed }) {
            return .green
        } else if dateMeetings.contains(where: { $0.status == .scheduled }) {
            return .yellow
        }
        
        return .clear
    }
    
    func meetingsForDate(_ date: Date) -> [Meeting] {
        return meetings.filter { meeting in
            calendar.isDate(meeting.date, inSameDayAs: date)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    // Full Calendar
                    calendarSection
                    
                    // Selected Date Items
                    if !meetingsForDate(selectedDate).isEmpty {
                        selectedDateMeetingsSection
                    }
                    
                    // Meetings Lists
                    upcomingMeetingsSection
                    pastMeetingsSection
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            
            // Floating Action Button (+ button)
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
                        .background(showingActionSheet ? Color.red : Color.green)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .rotationEffect(.degrees(showingActionSheet ? 90 : 0))
                }
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("Meetings Calendar")
        .sheet(isPresented: $showingMeetingDetail) {
            if let meeting = selectedMeeting {
                MeetingDetailView(meeting: meeting)
            }
        }
        .sheet(isPresented: $showingNewMeeting) {
            NewMeetingView(prefilledDate: prefilledDateForNewMeeting) { newMeeting in
                meetings.append(newMeeting)
                selectedDate = newMeeting.date
            }
        }
        .onAppear {
            let currentMonthIndex = calendar.component(.month, from: currentMonth) - 1
            let currentYear = calendar.component(.year, from: currentMonth)
            if let yearIndex = years.firstIndex(of: currentYear) {
                selectedMonthIndex = currentMonthIndex
                selectedYearIndex = yearIndex
            }
            if !didStartEventsListener {
                if let role = authService.currentUser?.role {
                    switch role {
                    case .employee:
                        firebaseService.fetchEventsForEmployee(
                            userUid: FirebaseAuthService.shared.currentUid,
                            userEmail: authService.currentUser?.email
                        )
                    case .client:
                        firebaseService.fetchEventsForClient(
                            userUid: FirebaseAuthService.shared.currentUid,
                            userEmail: authService.currentUser?.email,
                            clientName: authService.currentUser?.name
                        )
                    case .manager, .admin, .superAdmin:
                        break
                    }
                    didStartEventsListener = true
                }
            }
            if firebaseService.employees.isEmpty {
                firebaseService.fetchEmployees()
            }
        }
        .onReceive(firebaseService.$events) { events in
            self.meetings = events
        }
        .onReceive(authService.$currentUser) { _ in
            if !didStartEventsListener, let role = authService.currentUser?.role {
                switch role {
                case .employee:
                    firebaseService.fetchEventsForEmployee(
                        userUid: FirebaseAuthService.shared.currentUid,
                        userEmail: authService.currentUser?.email
                    )
                case .client:
                    firebaseService.fetchEventsForClient(
                        userUid: FirebaseAuthService.shared.currentUid,
                        userEmail: authService.currentUser?.email,
                        clientName: authService.currentUser?.name
                    )
                case .manager, .admin, .superAdmin:
                    break
                }
                didStartEventsListener = true
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
    
    // MARK: - View Sections
    private var calendarSection: some View {
        VStack(spacing: 15) {
            // Month Header with Dropdowns
            HStack {
                Button(action: {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
                    updateSelectedIndices()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.green)
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
                                .foregroundColor(.green)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
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
                            Text(verbatim: String(years[selectedYearIndex]))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
                    updateSelectedIndices()
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.green)
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
        let hasItems = !meetingsForDate(date).isEmpty
        let statusColor = dateStatusColor(for: date)
        let itemCount = meetingsForDate(date).count
        
        return VStack(spacing: 4) {
            ZStack {
                // Background circle with status color
                Circle()
                    .fill(hasItems ? statusColor : Color.clear)
                    .frame(width: 30, height: 30)
                
                // Border for selected date
                if isSelected(date) && !isToday(date) {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 34, height: 34)
                }
                
                // Today's date has special styling
                if isToday(date) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 30, height: 30)
                }
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isToday(date) ? .bold : .regular)
                    .foregroundColor(dayTextColor(for: date, hasItems: hasItems))
            }
            .frame(width: 34, height: 34)
            
            // Show item count for dates with multiple items
            if itemCount > 1 {
                Text("\(itemCount)")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .onTapGesture {
            selectedDate = date
        }
    }
    
    private func dayTextColor(for date: Date, hasItems: Bool) -> Color {
        if isToday(date) {
            return .white
        } else if hasItems {
            // For dates with items, use contrasting text color
            let statusColor = dateStatusColor(for: date)
            return statusColor == .yellow ? .black : .white
        } else if isCurrentMonth(date) {
            return .primary
        } else {
            return .gray
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
                MeetingCard(
                    meeting: meeting,
                    isUpcoming: meeting.date > Date()
                ) {
                    selectedMeeting = meeting
                    showingMeetingDetail = true
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
                Text("Today's Meetings")
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
            
            if upcomingMeetings.isEmpty {
                Text("No meetings today")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(upcomingMeetings) { meeting in
                    MeetingCard(
                        meeting: meeting,
                        isUpcoming: true
                    ) {
                        selectedMeeting = meeting
                        showingMeetingDetail = true
                    }
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
                Text("Today's Completed Meetings")
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
                ForEach(pastMeetings) { meeting in
                    MeetingCard(
                        meeting: meeting,
                        isUpcoming: false
                    ) {
                        selectedMeeting = meeting
                        showingMeetingDetail = true
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var meetingsListSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Meetings")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(meetings.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            ForEach(meetings) { meeting in
                MeetingCard(
                    meeting: meeting,
                    isUpcoming: meeting.date > Date()
                ) {
                    selectedMeeting = meeting
                    showingMeetingDetail = true
                }
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

// MARK: - Client Calendar Task Card
struct ClientCalendarTaskCard: View {
    let task: Task
    
    var priorityDisplay: String {
        switch task.priority {
        case .p1: return "High"
        case .p2: return "Medium"
        case .p3: return "Low"
        }
    }
    
    var statusColor: Color {
        switch task.status {
        case .completed: return Color(red: 0.0, green: 0.8, blue: 0.7) // Teal (green-blue mix) for Done
        case .inProgress: return .yellow // Yellow for In Progress
        case .notStarted: return .red // Red for TODO
        case .stuck: return .orange
        case .waitingFor: return .purple
        case .onHoldByClient: return .orange
        case .needHelp: return .red
        case .canceled: return .gray
        }
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .p1: return .red
        case .p2: return .yellow
        case .p3: return .blue
        }
    }
    
    // Alarm system
    var isTaskOverdue: Bool {
        let alarmThreshold = 7
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: task.startDate, to: Date()).day ?? 0
        return daysSinceStart >= alarmThreshold && task.status == .inProgress
    }
    
    var taskDurationDays: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: task.startDate, to: Date()).day ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        Text("Assigned to: \(task.assignedTo)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Text(priorityDisplay)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor.opacity(0.2))
                            .foregroundColor(priorityColor)
                            .cornerRadius(4)
                        
                        // Alarm indicator
                        if isTaskOverdue {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text("\(taskDurationDays)d")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            
            HStack {
                // Status
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(task.status.rawValue)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Date Range
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(task.startDate.formatted(date: .abbreviated, time: .omitted)) - \(task.dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
}
