import SwiftUI
import Combine

struct ClientMeetingsCalendarView: View {
    @State private var selectedDate = Date()
    @State private var showingMeetingDetail = false
    @State private var selectedMeeting: Meeting? = nil
    @State private var currentMonth = Date()
    @State private var selectedMonthIndex = 0
    @State private var selectedYearIndex = 0
    @State private var showingNewMeeting = false
    @State private var prefilledDateForNewMeeting: Date? = nil
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
    
    var upcomingMeetings: [Meeting] {
        meetings.filter { $0.date > Date() && $0.status == .scheduled }
    }
    
    var pastMeetings: [Meeting] {
        meetings.filter { $0.date <= Date() && ($0.status == .completed || $0.status == .cancelled) }
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
        } else if dateMeetings.contains(where: { $0.status == .scheduled }) {
            return .yellow
        }
        
        return .clear
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                calendarSection
                
                if !meetingsForDate(selectedDate).isEmpty {
                    selectedDateMeetingsSection
                }
                
                upcomingMeetingsSection
                pastMeetingsSection
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle("Meetings & Calendar")
        .sheet(isPresented: $showingMeetingDetail) {
            if let meeting = selectedMeeting {
                MeetingDetailView(meeting: meeting)
            }
        }
        .sheet(isPresented: $showingNewMeeting) {
            NewMeetingView(prefilledDate: prefilledDateForNewMeeting) { newMeeting in
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
                        firebaseService.fetchEventsForEmployee(userUid: FirebaseAuthService.shared.currentUid, userEmail: authService.currentUser?.email)
                    case .client:
                        firebaseService.fetchEventsForClient(userUid: FirebaseAuthService.shared.currentUid, userEmail: authService.currentUser?.email, clientName: authService.currentUser?.name)
                    case .manager, .admin, .superAdmin:
                        break
                    }
                    didStartEventsListener = true
                }
            }
        }
        .onReceive(firebaseService.$events) { events in
            self.meetings = events
        }
        .onReceive(authService.$currentUser) { _ in
            if !didStartEventsListener, let role = authService.currentUser?.role {
                switch role {
                case .employee:
                    firebaseService.fetchEventsForEmployee(userUid: FirebaseAuthService.shared.currentUid, userEmail: authService.currentUser?.email)
                case .client:
                    firebaseService.fetchEventsForClient(userUid: FirebaseAuthService.shared.currentUid, userEmail: authService.currentUser?.email, clientName: authService.currentUser?.name)
                case .manager, .admin, .superAdmin:
                    break
                }
                didStartEventsListener = true
            }
            if firebaseService.employees.isEmpty {
                firebaseService.fetchEmployees()
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
                                            Text(verbatim: String(years[index]))
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
            return Color.green
        } else if isSelected(date) {
            return Color.green.opacity(0.2)
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
            
            if upcomingMeetings.isEmpty {
                Text("No upcoming meetings")
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
}

extension Meeting {
    func withStatus(_ newStatus: MeetingStatus) -> Meeting {
        return Meeting(
            title: self.title,
            date: self.date,
            duration: self.duration,
            participants: self.participants,
            agenda: self.agenda,
            meetingType: self.meetingType,
            project: self.project,
            status: newStatus,
            mom: self.mom,
            location: self.location
        )
    }
}

struct MeetingCard: View {
    let meeting: Meeting
    let isUpcoming: Bool
    let action: () -> Void
    
    var statusColor: Color {
        switch meeting.status {
        case .scheduled:
            return .yellow
        case .completed:
            return .green
        case .cancelled:
            return .red
        case .inProgress:
            return .orange
        }
    }
    
    var statusText: String {
        switch meeting.status {
        case .scheduled:
            return "Scheduled"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Rejected"
        case .inProgress:
            return "In Progress"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(meeting.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(meeting.meetingType.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if let project = meeting.project {
                            Text(project)
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
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
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        // Status indicator
                        Text(statusText)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    Label("\(meeting.duration) min", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Label("\(meeting.participants.count) people", systemImage: "person.2")
                        .font(.caption2)
                        .foregroundColor(.gray)
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
        .buttonStyle(PlainButtonStyle())
    }
}
