import SwiftUI
import UIKit

struct DailyReportFormView: View {
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    @State private var employeeName: String = "John Doe"
    @State private var clientName: String = ""
    @State private var projectName: String = ""
    @State private var dailyHours: String = "8.0"
    @State private var objectiveForDay: String = ""
    @State private var obstaclesChallenges: String = ""
    @State private var nextActionPlan: String = ""
    @State private var comments: String = ""
    @State private var tasksDone: String = ""
    @State private var statusLabel: String = ""
    @State private var generatedReport: String = ""
    @State private var isGenerating: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var shareItems: [Any] = []
    @State private var isEditingReport: Bool = false
    @State private var editedReport: String = ""
    @State private var showSaveSuccess: Bool = false
    @State private var showPreview: Bool = false
    @State private var showSavedReports: Bool = false
    @State private var selectedReportType: ReportType = .daily
    @State private var weekNumber: String = ""
    @State private var weekStartDate: Date = Date()
    @State private var weekEndDate: Date = Date()
    @StateObject private var speechHelper = SpeechRecognizerHelper()
    @State private var activeSpeechField: WeeklySpeechField?
    
    // Monthly Report Fields
    @State private var month: Date = Date()
    @State private var executiveSummary: String = ""
    @State private var keyActivities: String = ""
    @State private var challengesRisks: String = ""
    @State private var achievementsHighlights: String = ""
    @State private var learningsObservations: String = ""
    @State private var nextMonthObjectives: String = ""
    @State private var consultantNote: String = ""
    @State private var dailyCache = ReportFormCache()
    @State private var weeklyCache = ReportFormCache()
    @State private var monthlyCache = ReportFormCache()
    @State private var lastSelectedReportType: ReportType = .daily
    
    private let geminiService = GeminiAPIService()
    
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
    
    private var reportNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MFI_DR_dd"
        return formatter.string(from: Date())
    }
    
    private var reportDateDisplay: String {
        switch selectedReportType {
        case .weekly:
            return formattedWeeklyDateRange()
        case .monthly:
            return formattedMonth()
        default:
            return currentDate
        }
    }
    
    // All projects currently assigned to the logged-in employee (live from Firebase)
    private var assignedProjects: [Project] {
        firebaseService.projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Form Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Generate Performance Report")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 8)

                        ReportTypePicker(selectedReportType: $selectedReportType)
                        
                        // Saved Reports button (below tabs)
                        HStack {
                            Spacer()
                            Button(action: { showSavedReports = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                    Text("Saved Reports")
                                }
                                .font(.subheadline)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(18)
                            }
                        }
                        .padding(.bottom, 8)

                        if selectedReportType == .monthly {
                            MonthlyReportFormFields(
                                clientName: $clientName,
                                projectName: $projectName,
                                month: $month,
                                executiveSummary: $executiveSummary,
                                keyActivities: $keyActivities,
                                challengesRisks: $challengesRisks,
                                achievementsHighlights: $achievementsHighlights,
                                learningsObservations: $learningsObservations,
                                nextMonthObjectives: $nextMonthObjectives,
                                consultantNote: $consultantNote,
                                assignedProjects: assignedProjects,
                                onMicTap: { field in
                                    switch field {
                                    case .executiveSummary:
                                        toggleWeeklySpeech(for: .monthlyExecutiveSummary)
                                    case .keyActivities:
                                        toggleWeeklySpeech(for: .monthlyKeyActivities)
                                    case .challengesRisks:
                                        toggleWeeklySpeech(for: .monthlyChallenges)
                                    case .achievementsHighlights:
                                        toggleWeeklySpeech(for: .monthlyAchievements)
                                    case .learningsObservations:
                                        toggleWeeklySpeech(for: .monthlyLearnings)
                                    case .nextMonthObjectives:
                                        toggleWeeklySpeech(for: .monthlyNextObjectives)
                                    case .consultantNote:
                                        toggleWeeklySpeech(for: .monthlyConsultantNote)
                                    }
                                },
                                micIcon: { field in
                                    switch field {
                                    case .executiveSummary:
                                        return weeklySpeechIcon(for: .monthlyExecutiveSummary)
                                    case .keyActivities:
                                        return weeklySpeechIcon(for: .monthlyKeyActivities)
                                    case .challengesRisks:
                                        return weeklySpeechIcon(for: .monthlyChallenges)
                                    case .achievementsHighlights:
                                        return weeklySpeechIcon(for: .monthlyAchievements)
                                    case .learningsObservations:
                                        return weeklySpeechIcon(for: .monthlyLearnings)
                                    case .nextMonthObjectives:
                                        return weeklySpeechIcon(for: .monthlyNextObjectives)
                                    case .consultantNote:
                                        return weeklySpeechIcon(for: .monthlyConsultantNote)
                                    }
                                },
                                isRecordingForField: { field in
                                    switch field {
                                    case .executiveSummary:
                                        return speechHelper.isRecording && activeSpeechField == .monthlyExecutiveSummary
                                    case .keyActivities:
                                        return speechHelper.isRecording && activeSpeechField == .monthlyKeyActivities
                                    case .challengesRisks:
                                        return speechHelper.isRecording && activeSpeechField == .monthlyChallenges
                                    case .achievementsHighlights:
                                        return speechHelper.isRecording && activeSpeechField == .monthlyAchievements
                                    case .learningsObservations:
                                        return speechHelper.isRecording && activeSpeechField == .monthlyLearnings
                                    case .nextMonthObjectives:
                                        return speechHelper.isRecording && activeSpeechField == .monthlyNextObjectives
                                    case .consultantNote:
                                        return speechHelper.isRecording && activeSpeechField == .monthlyConsultantNote
                                    }
                                }
                            )
                            
                            // Status
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Status")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                Menu {
                                    ForEach(firebaseService.taskStatusOptions.filter {
                                        let v = $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                        return v != "all" && v != "today's task" && v != "todays task" && v != "today" && v != "recurring task"
                                    }, id: \.self) { label in
                                        Button(label) {
                                            statusLabel = label
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(statusLabel.isEmpty ? "Select status" : statusLabel)
                                            .foregroundColor(statusLabel.isEmpty ? .gray : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            
                            // Generate Report Button
                            Button(action: generateReport) {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("Generate Report")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canGenerate ? Color.purple : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!canGenerate || isGenerating)
                        } else {
                        // Employee Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Employee Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            
                            TextField("Enter employee name", text: $employeeName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(true)
                        }
                        
                        // Client Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Client Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            
                            if selectedReportType == .weekly {
                                ZStack(alignment: .trailing) {
                                    TextField("e.g. Acme Corp", text: $clientName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    Button(action: {
                                        toggleWeeklySpeech(for: .clientName)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .clientName))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .clientName ? .red : .gray)
                                            .padding(.trailing, 8)
                                    }
                                }
                            } else {
                                TextField("e.g. Acme Corp", text: $clientName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        // Project Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            
                            // Project picker showing only projects assigned to this employee (live)
                            Menu {
                                if assignedProjects.isEmpty {
                                    Text("No projects assigned")
                                } else {
                                    ForEach(assignedProjects) { project in
                                        Button(project.name) {
                                            projectName = project.name
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(projectName.isEmpty ? "Select project" : projectName)
                                        .foregroundColor(projectName.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        if selectedReportType == .weekly {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Week Number")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                TextField("e.g. 52", text: $weekNumber)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Weekly Hours")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                TextField("e.g. 40.0", text: $dailyHours)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Date")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                DatePicker("", selection: $weekStartDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("End Date")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                DatePicker("", selection: $weekEndDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Challenges")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("Voice Input Supported")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.25))
                                        .cornerRadius(6)
                                }
                                
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $obstaclesChallenges)
                                        .frame(height: 80)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    Button(action: {
                                        toggleWeeklySpeech(for: .challenges)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .challenges))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .challenges ? .red : .gray)
                                            .padding(12)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Key Achievements (One per line)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("Voice Input Supported")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.25))
                                        .cornerRadius(6)
                                }
                                
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $tasksDone)
                                        .frame(height: 120)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    Button(action: {
                                        toggleWeeklySpeech(for: .achievements)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .achievements))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .achievements ? .red : .gray)
                                            .padding(12)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Urgent Action Items (One per line)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("Voice Input Supported")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.25))
                                        .cornerRadius(6)
                                }
                                
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $nextActionPlan)
                                        .frame(height: 80)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    Button(action: {
                                        toggleWeeklySpeech(for: .urgentItems)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .urgentItems))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .urgentItems ? .red : .gray)
                                            .padding(12)
                                    }
                                }
                            }
                        } else {
                            // Daily Hours
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Daily Hours")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                TextField("e.g. 8.0", text: $dailyHours)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            // Today's Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                Text(currentDate)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // Objective for the Day
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Objective for the Day")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $objectiveForDay)
                                        .frame(height: 80)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    Button(action: {
                                        toggleWeeklySpeech(for: .dailyObjective)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .dailyObjective))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .dailyObjective ? .red : .gray)
                                            .padding(12)
                                    }
                                }
                            }
                            
                            // Obstacles / Challenges
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Obstacles / Challenges")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $obstaclesChallenges)
                                        .frame(height: 80)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    Button(action: {
                                        toggleWeeklySpeech(for: .dailyObstacles)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .dailyObstacles))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .dailyObstacles ? .red : .gray)
                                            .padding(12)
                                    }
                                }
                            }
                            
                            // Next Action Plan
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Comments/Remarks")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $comments)
                                        .frame(height: 80)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    Button(action: {
                                        toggleWeeklySpeech(for: .dailyComments)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .dailyComments))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .dailyComments ? .red : .gray)
                                            .padding(12)
                                    }
                                }
                            }

                            // Next Action Plan
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Next Action Plan (one per line)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $nextActionPlan)
                                        .frame(height: 80)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    Button(action: {
                                        toggleWeeklySpeech(for: .dailyNextAction)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .dailyNextAction))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .dailyNextAction ? .red : .gray)
                                            .padding(12)
                                    }
                                }
                            }
                            
                            // Tasks Done
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tasks Done Today")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $tasksDone)
                                        .frame(height: 120)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    Button(action: {
                                        toggleWeeklySpeech(for: .dailyTasks)
                                    }) {
                                        Image(systemName: weeklySpeechIcon(for: .dailyTasks))
                                            .foregroundColor(speechHelper.isRecording && activeSpeechField == .dailyTasks ? .red : .gray)
                                            .padding(12)
                                    }
                                }
                            }
                        }
                        
                        // Status
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            
                            Menu {
                                ForEach(firebaseService.taskStatusOptions.filter {
                                    let v = $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    return v != "all" && v != "today's task" && v != "todays task" && v != "today" && v != "recurring task"
                                }, id: \.self) { label in
                                    Button(label) {
                                        statusLabel = label
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(statusLabel.isEmpty ? "Select status" : statusLabel)
                                        .foregroundColor(statusLabel.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Generate Report Button
                        Button(action: generateReport) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Generate Report")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canGenerate ? Color.purple : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canGenerate || isGenerating)
                        }
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(15)
                    .shadow(color: .gray.opacity(0.2), radius: 5)
                    
                    // Report Preview Section
                    if showPreview {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Report Preview")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            // Action buttons aligned to the right
                            HStack(spacing: 12) {
                                Spacer()
                                Button(action: { exportPDFDirectly() }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.doc")
                                        Text("Download PDF")
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(18)
                                }
                                Button(action: { sharePDF(includeText: false) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share")
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(18)
                                }
                            }
                            
                            DailyProgressReportPreview(
                                reportNumber: reportNumber,
                                date: reportDateDisplay,
                                reportType: selectedReportType,
                                employeeName: employeeName,
                                clientName: clientName,
                                projectName: projectName,
                                dailyHours: dailyHours,
                                objective: objectiveForDay,
                                tasksDone: tasksDone,
                                obstacles: obstaclesChallenges,
                                nextActionPlan: nextActionPlan,
                                comments: comments,
                                summary: generatedReport,
                                status: statusLabel
                            )
                            .padding(.top, 4)
                            
                            // Save row
                            HStack(spacing: 16) {
                                Button(action: saveReport) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "tray.and.arrow.down")
                                        Text("Save")
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(18)
                                }
                            }
                        }
                        .padding()
                        .background(.background)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.2), radius: 5)
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("AI Daily Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSaveSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Report saved successfully!")
            }
            .sheet(isPresented: $showSavedReports) {
                SavedDailyReportsView(
                    firebaseService: firebaseService,
                    authService: authService
                )
            }
            .onAppear {
                // Auto-fill employee name from the logged-in user
                if let userName = authService.currentUser?.name, !userName.isEmpty {
                    employeeName = userName
                }
                
                // Fetch projects assigned to this employee so the picker is live
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email)
                firebaseService.listenTaskStatusOptions()
                let calendar = Calendar.current
                let weekOfYear = calendar.component(.weekOfYear, from: Date())
                if weekNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    weekNumber = String(weekOfYear)
                }
                if weekEndDate < weekStartDate {
                    weekEndDate = weekStartDate
                }
                lastSelectedReportType = selectedReportType
                cacheCurrentFields(for: selectedReportType)
            }
            .onChange(of: selectedReportType) { newValue in
                cacheCurrentFields(for: lastSelectedReportType)
                applyCache(for: newValue)
                lastSelectedReportType = newValue
            }
            .onReceive(firebaseService.$projects) { projects in
                // If no project selected yet, preselect the first assigned project
                if projectName.isEmpty, let first = projects.first {
                    projectName = first.name
                }
            }
        }
    }
    
    private var canGenerate: Bool {
        let trimmedProject = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedProject.isEmpty { return false }
        
        switch selectedReportType {
        case .monthly:
            let hasMonthlyContent =
                !executiveSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !keyActivities.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !challengesRisks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !achievementsHighlights.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !learningsObservations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !nextMonthObjectives.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !consultantNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasMonthlyContent
        default:
            return !tasksDone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func generateReport() {
        isGenerating = true
        generatedReport = ""
        isEditingReport = false
        showPreview = true
        
        let promptDate: String
        if selectedReportType == .weekly {
            promptDate = formattedWeeklyDateRange()
        } else if selectedReportType == .monthly {
            promptDate = formattedMonth()
        } else {
            promptDate = currentDate
        }
        
        if selectedReportType == .weekly {
            let trimmedAchievements = tasksDone.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUrgent = nextActionPlan.trimmingCharacters(in: .whitespacesAndNewlines)
            var combined = trimmedAchievements
            if !trimmedUrgent.isEmpty {
                if !combined.isEmpty {
                    combined.append("\n\nUrgent action items:\n")
                }
                combined.append(trimmedUrgent)
            }
            if combined.isEmpty {
                combined = obstaclesChallenges
            }
            tasksDone = combined
        } else if selectedReportType == .monthly {
            var sections: [String] = []
            let trimmedExecutive = executiveSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedExecutive.isEmpty {
                sections.append("Executive Summary:\n\(trimmedExecutive)")
            }
            let trimmedKeyActivities = keyActivities.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKeyActivities.isEmpty {
                sections.append("Key Activities (one per line):\n\(trimmedKeyActivities)")
            }
            let trimmedChallenges = challengesRisks.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedChallenges.isEmpty {
                sections.append("Challenges & Risks:\n\(trimmedChallenges)")
            }
            let trimmedAchievementsHighlights = achievementsHighlights.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedAchievementsHighlights.isEmpty {
                sections.append("Achievements / Highlights:\n\(trimmedAchievementsHighlights)")
            }
            let trimmedLearnings = learningsObservations.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLearnings.isEmpty {
                sections.append("Learnings & Observations:\n\(trimmedLearnings)")
            }
            let trimmedObjectives = nextMonthObjectives.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedObjectives.isEmpty {
                sections.append("Next Month's Objectives:\n\(trimmedObjectives)")
            }
            let trimmedNote = consultantNote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNote.isEmpty {
                sections.append("Consultant's Note / Recommendations:\n\(trimmedNote)")
            }
            tasksDone = sections.joined(separator: "\n\n")
        }
        
        // Use _Concurrency.Task to explicitly reference Swift's concurrency Task
        _Concurrency.Task {
            do {
                let report = try await geminiService.generateDailyReport(
                    employeeName: employeeName,
                    projectName: projectName,
                    date: promptDate,
                    tasksDone: tasksDone
                )
                
                await MainActor.run {
                    generatedReport = report
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    // Silent fallback: no alert; just provide a basic summary
                    isGenerating = false
                    let fallback = buildFallbackReportText()
                    generatedReport = fallback
                }
            }
        }
    }
    
    private func saveReport() {
        var textToSave: String
        if isEditingReport {
            generatedReport = editedReport
            textToSave = editedReport
            isEditingReport = false
        } else {
            let trimmed = generatedReport.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                textToSave = buildFallbackReportText()
                generatedReport = textToSave
            } else {
                textToSave = generatedReport
            }
        }
        let uid = authService.currentUid
        let email = authService.currentUser?.email
        let name = employeeName
        let project = projectName
        let tasks = tasksDone
        let text = textToSave
        let trimmedStatus = statusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusToSave: String? = trimmedStatus.isEmpty ? nil : trimmedStatus
        firebaseService.saveEmployeeDailyReport(
            employeeUid: uid,
            employeeEmail: email,
            employeeName: name,
            projectName: project,
            date: Date(),
            tasksDone: tasks,
            reportText: text,
            status: statusToSave,
            dailyHours: dailyHours,
            objective: objectiveForDay,
            obstacles: obstaclesChallenges,
            nextActionPlan: nextActionPlan,
            comments: comments,
            reportType: selectedReportType.rawValue
        ) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else {
                clearFields(for: selectedReportType)
                showSaveSuccess = true
            }
        }
    }
    
    private func sharePDF(includeText: Bool) {
        guard let pdfData = renderReportToPDF() else {
            errorMessage = "Failed to generate PDF for sharing. Please try again."
            showError = true
            return
        }
        let tmpDir = FileManager.default.temporaryDirectory
        let fileName = "DailyReport_\(reportNumber).pdf"
        let fileURL = tmpDir.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: fileURL, options: .atomic)
        } catch {
            errorMessage = "Failed to prepare PDF for sharing. Please try again."
            showError = true
            return
        }
        var items: [Any] = [fileURL]
        if includeText {
            let trimmed = generatedReport.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                let fallback = buildFallbackReportText()
                generatedReport = fallback
                items.append(fallback)
            } else {
                items.append(generatedReport)
            }
        }
        shareItems = items
        presentActivityController(with: items)
    }

    private func presentActivityController(with items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let sheet = activityVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = false
        }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            DispatchQueue.main.async {
                top.present(activityVC, animated: true)
            }
        }
    }
    
    private func exportPDFDirectly() {
        guard let pdfData = renderReportToPDF() else {
            errorMessage = "Failed to generate PDF. Please try again."
            showError = true
            return
        }
        let tmpDir = FileManager.default.temporaryDirectory
        let fileName = "DailyReport_\(reportNumber).pdf"
        let fileURL = tmpDir.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: fileURL, options: .atomic)
        } catch {
            errorMessage = "Failed to prepare PDF. Please try again."
            showError = true
            return
        }
        presentDocumentPicker(for: fileURL)
    }
    
    private func presentDocumentPicker(for url: URL) {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = false
        }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            DispatchQueue.main.async {
                top.present(picker, animated: true)
            }
        }
    }
    
    private func renderReportToPDF() -> Data? {
        let controller = UIHostingController(
            rootView: DailyProgressReportPreview(
                reportNumber: reportNumber,
                date: reportDateDisplay,
                reportType: selectedReportType,
                employeeName: employeeName,
                clientName: clientName,
                projectName: projectName,
                dailyHours: dailyHours,
                objective: objectiveForDay,
                tasksDone: tasksDone,
                obstacles: obstaclesChallenges,
                nextActionPlan: nextActionPlan,
                comments: comments,
                summary: generatedReport,
                status: statusLabel
            )
            .padding()
        )
        let targetSize = CGSize(width: 595.2, height: 842)
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .white
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: targetSize))
        let data = renderer.pdfData { context in
            context.beginPage()
            controller.view.layer.render(in: context.cgContext)
        }
        return data
    }

    private func formattedWeeklyDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: weekStartDate)
        let end = formatter.string(from: weekEndDate)
        let trimmedWeek = weekNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedWeek.isEmpty {
            return "\(start) - \(end)"
        } else {
            return "Week \(trimmedWeek) (\(start) - \(end))"
        }
    }
    
    private func formattedMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private func toggleWeeklySpeech(for field: WeeklySpeechField) {
        // If already recording for this field, stop only the mic but keep text
        if speechHelper.isRecording && activeSpeechField == field {
            speechHelper.stop()
            activeSpeechField = nil
            return
        }

        // If recording for another field, stop that first
        if speechHelper.isRecording {
            speechHelper.stop()
        }

        // Start recording for the requested field.
        // Capture the current text for each field so new speech is appended
        // to the existing content without erasing it.
        activeSpeechField = field

        let baseClient = clientName
        let baseChallenges = obstaclesChallenges
        let baseAchievements = tasksDone
        let baseUrgent = nextActionPlan
        let baseObjective = objectiveForDay
        let baseDailyObstacles = obstaclesChallenges
        let baseComments = comments
        let baseNext = nextActionPlan
        let baseDailyTasks = tasksDone
        let baseMonthlyExecutiveSummary = executiveSummary
        let baseMonthlyKeyActivities = keyActivities
        let baseMonthlyChallenges = challengesRisks
        let baseMonthlyAchievements = achievementsHighlights
        let baseMonthlyLearnings = learningsObservations
        let baseMonthlyNextObjectives = nextMonthObjectives
        let baseMonthlyConsultantNote = consultantNote

        speechHelper.toggle { text in
            switch self.activeSpeechField {
            case .clientName:
                let prefix = baseClient.isEmpty ? "" : baseClient + " "
                self.clientName = prefix + text
            case .challenges:
                let prefix = baseChallenges.isEmpty ? "" : baseChallenges + " "
                self.obstaclesChallenges = prefix + text
            case .achievements:
                let prefix = baseAchievements.isEmpty ? "" : baseAchievements + " "
                self.tasksDone = prefix + text
            case .urgentItems:
                let prefix = baseUrgent.isEmpty ? "" : baseUrgent + " "
                self.nextActionPlan = prefix + text
            case .dailyObjective:
                let prefix = baseObjective.isEmpty ? "" : baseObjective + " "
                self.objectiveForDay = prefix + text
            case .dailyObstacles:
                let prefix = baseDailyObstacles.isEmpty ? "" : baseDailyObstacles + " "
                self.obstaclesChallenges = prefix + text
            case .dailyComments:
                let prefix = baseComments.isEmpty ? "" : baseComments + " "
                self.comments = prefix + text
            case .dailyNextAction:
                let prefix = baseNext.isEmpty ? "" : baseNext + " "
                self.nextActionPlan = prefix + text
            case .dailyTasks:
                let prefix = baseDailyTasks.isEmpty ? "" : baseDailyTasks + " "
                self.tasksDone = prefix + text
            case .monthlyExecutiveSummary:
                let prefix = baseMonthlyExecutiveSummary.isEmpty ? "" : baseMonthlyExecutiveSummary + " "
                self.executiveSummary = prefix + text
            case .monthlyKeyActivities:
                let prefix = baseMonthlyKeyActivities.isEmpty ? "" : baseMonthlyKeyActivities + " "
                self.keyActivities = prefix + text
            case .monthlyChallenges:
                let prefix = baseMonthlyChallenges.isEmpty ? "" : baseMonthlyChallenges + " "
                self.challengesRisks = prefix + text
            case .monthlyAchievements:
                let prefix = baseMonthlyAchievements.isEmpty ? "" : baseMonthlyAchievements + " "
                self.achievementsHighlights = prefix + text
            case .monthlyLearnings:
                let prefix = baseMonthlyLearnings.isEmpty ? "" : baseMonthlyLearnings + " "
                self.learningsObservations = prefix + text
            case .monthlyNextObjectives:
                let prefix = baseMonthlyNextObjectives.isEmpty ? "" : baseMonthlyNextObjectives + " "
                self.nextMonthObjectives = prefix + text
            case .monthlyConsultantNote:
                let prefix = baseMonthlyConsultantNote.isEmpty ? "" : baseMonthlyConsultantNote + " "
                self.consultantNote = prefix + text
            case .none:
                break
            }
        }
    }

    private func weeklySpeechIcon(for field: WeeklySpeechField) -> String {
        if speechHelper.isRecording && activeSpeechField == field {
            return "mic.circle.fill"
        } else {
            return "mic.circle"
        }
    }

    private func buildFallbackReportText() -> String {
        let trimmedProject = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTasks = tasksDone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedObstacles = obstaclesChallenges.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNext = nextActionPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComments = comments.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHours = dailyHours.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = []

        let header: String
        switch selectedReportType {
        case .daily:
            header = "Daily summary for \(employeeName) on project \(trimmedProject.isEmpty ? "-" : trimmedProject)."
        case .weekly:
            header = "Weekly summary for \(employeeName) on project \(trimmedProject.isEmpty ? "-" : trimmedProject)."
        case .monthly:
            header = "Monthly summary for \(employeeName) on project \(trimmedProject.isEmpty ? "-" : trimmedProject)."
        }
        lines.append(header)

        if !trimmedHours.isEmpty {
            lines.append("Reported hours: \(trimmedHours).")
        }
        if !trimmedTasks.isEmpty {
            lines.append("Key work completed: \(trimmedTasks)")
        }
        if !trimmedObstacles.isEmpty {
            lines.append("Obstacles or risks: \(trimmedObstacles)")
        }
        if !trimmedNext.isEmpty {
            lines.append("Planned next actions: \(trimmedNext)")
        }
        if !trimmedComments.isEmpty {
            lines.append("Additional remarks: \(trimmedComments)")
        }

        return lines.joined(separator: "\n\n")
    }
    
    private func cacheCurrentFields(for type: ReportType) {
        let cache = ReportFormCache(
            dailyHours: dailyHours,
            objective: objectiveForDay,
            obstacles: obstaclesChallenges,
            nextActionPlan: nextActionPlan,
            comments: comments,
            tasksDone: tasksDone,
            statusLabel: statusLabel,
            generatedReport: generatedReport
        )
        switch type {
        case .daily:
            dailyCache = cache
        case .weekly:
            weeklyCache = cache
        case .monthly:
            monthlyCache = cache
        }
    }
    
    private func applyCache(for type: ReportType) {
        let cache: ReportFormCache
        switch type {
        case .daily:
            cache = dailyCache
        case .weekly:
            cache = weeklyCache
        case .monthly:
            cache = monthlyCache
        }
        dailyHours = cache.dailyHours
        objectiveForDay = cache.objective
        obstaclesChallenges = cache.obstacles
        nextActionPlan = cache.nextActionPlan
        comments = cache.comments
        tasksDone = cache.tasksDone
        statusLabel = cache.statusLabel
        generatedReport = cache.generatedReport
    }
    
    private func clearFields(for type: ReportType) {
        switch type {
        case .daily:
            dailyHours = "8.0"
            objectiveForDay = ""
            obstaclesChallenges = ""
            nextActionPlan = ""
            comments = ""
            tasksDone = ""
            statusLabel = ""
            generatedReport = ""
        case .weekly:
            dailyHours = ""
            objectiveForDay = ""
            obstaclesChallenges = ""
            nextActionPlan = ""
            comments = ""
            tasksDone = ""
            statusLabel = ""
            generatedReport = ""
        case .monthly:
            executiveSummary = ""
            keyActivities = ""
            challengesRisks = ""
            achievementsHighlights = ""
            learningsObservations = ""
            nextMonthObjectives = ""
            consultantNote = ""
            dailyHours = ""
            objectiveForDay = ""
            obstaclesChallenges = ""
            nextActionPlan = ""
            comments = ""
            tasksDone = ""
            statusLabel = ""
            generatedReport = ""
        }
        cacheCurrentFields(for: type)
    }
}

enum MonthlySpeechField {
    case executiveSummary
    case keyActivities
    case challengesRisks
    case achievementsHighlights
    case learningsObservations
    case nextMonthObjectives
    case consultantNote
}

enum WeeklySpeechField {
    case clientName
    case challenges
    case achievements
    case urgentItems
    case dailyObjective
    case dailyObstacles
    case dailyComments
    case dailyNextAction
    case dailyTasks
    case monthlyExecutiveSummary
    case monthlyKeyActivities
    case monthlyChallenges
    case monthlyAchievements
    case monthlyLearnings
    case monthlyNextObjectives
    case monthlyConsultantNote
}

// MARK: - Share Sheet
struct ReportShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SavedDailyReportsView: View {
    @ObservedObject var firebaseService: FirebaseService
    @ObservedObject var authService: FirebaseAuthService
    @Environment(\.dismiss) private var dismiss
    
    private var reports: [EmployeeDailyReport] {
        firebaseService.dailyReports
    }
    
    private var dailyReports: [EmployeeDailyReport] {
        reports.filter { normalizedType(for: $0) == .daily }
    }
    
    private var weeklyReports: [EmployeeDailyReport] {
        reports.filter { normalizedType(for: $0) == .weekly }
    }
    
    private var monthlyReports: [EmployeeDailyReport] {
        reports.filter { normalizedType(for: $0) == .monthly }
    }
    
    private func normalizedType(for report: EmployeeDailyReport) -> ReportType {
        if let raw = report.reportType, let parsed = ReportType(rawValue: raw) {
            return parsed
        }
        // Backward compatibility: old reports without type are treated as Daily
        return .daily
    }
    
    @ViewBuilder
    private func reportCard(for report: EmployeeDailyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(report.projectName)
                    .font(.headline)
                Spacer()
                Button(action: {
                    firebaseService.deleteEmployeeDailyReport(documentId: report.id) { success in
                        if !success {
                            print("Failed to delete daily report with id: \(report.id)")
                        }
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding(.bottom, 4)

            Text("Summary:")
                .font(.headline)

            VStack(spacing: 0) {
                summaryRow(label: "Employee", value: report.employeeName)
                Divider()
                summaryRow(label: "Project", value: report.projectName)
                Divider()
                summaryRow(label: "Daily Hours", value: report.dailyHours ?? "")
                Divider()
                summaryRow(label: "Task Status", value: report.status ?? "")
                Divider()
                summaryRow(label: "Objective", value: report.objective ?? "")
                Divider()
                summaryRow(label: "Tasks Completed", value: report.tasksDone)
                Divider()
                summaryRow(label: "Obstacles/Challenges", value: report.obstacles ?? "")
                Divider()
                summaryRow(label: "Next Action Plan", value: report.nextActionPlan ?? "")
                Divider()
                summaryRow(label: "Comments/Remarks", value: report.comments ?? "")
            }
            .font(.subheadline)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.vertical, 8)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Daily Reports") {
                    if dailyReports.isEmpty {
                        Text("No daily reports yet.")
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(dailyReports) { report in
                            reportCard(for: report)
                        }
                    }
                }
                
                Section("Weekly Reports") {
                    if weeklyReports.isEmpty {
                        Text("No weekly reports yet.")
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(weeklyReports) { report in
                            reportCard(for: report)
                        }
                    }
                }
                
                Section("Monthly Reports") {
                    if monthlyReports.isEmpty {
                        Text("No monthly reports yet.")
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(monthlyReports) { report in
                            reportCard(for: report)
                        }
                    }
                }
            }
            .navigationTitle("Saved Reports")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            let uid = authService.currentUid
            let email = authService.currentUser?.email
            firebaseService.listenEmployeeDailyReports(forUserUid: uid, userEmail: email)
        }
    }
}

// MARK: - Helper Functions for Report Views

private func summaryRow(label: String, value: String) -> some View {
    HStack(alignment: .top) {
        Text(label)
            .fontWeight(.semibold)
            .frame(width: 140, alignment: .leading)
        Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(8)
}

private func summaryRow(label: String, value: Date, style: Text.DateStyle) -> some View {
    HStack(alignment: .top) {
        Text(label)
            .fontWeight(.semibold)
            .frame(width: 140, alignment: .leading)
        Text(value, style: style)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(8)
}

struct ReportFormCache {
    var dailyHours: String = "8.0"
    var objective: String = ""
    var obstacles: String = ""
    var nextActionPlan: String = ""
    var comments: String = ""
    var tasksDone: String = ""
    var statusLabel: String = ""
    var generatedReport: String = ""
}

enum ReportType: String, CaseIterable {
    case daily = "Daily Report"
    case weekly = "Weekly Report"
    case monthly = "Monthly Report"
}

struct ReportTypePicker: View {
    @Binding var selectedReportType: ReportType

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReportType.allCases, id: \.self) { reportType in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedReportType = reportType
                    }
                }) {
                    Text(reportType.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedReportType == reportType ? .bold : .regular)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if selectedReportType == reportType {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.systemBackground))
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                }
                            }
                        )
                        .foregroundColor(selectedReportType == reportType ? .accentColor : .secondary)
                }
            }
        }
        .padding(4)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct DailyProgressReportPreview: View {
    let reportNumber: String
    let date: String
    let reportType: ReportType
    let employeeName: String
    let clientName: String
    let projectName: String
    let dailyHours: String
    let objective: String
    let tasksDone: String
    let obstacles: String
    let nextActionPlan: String
    let comments: String
    let summary: String
    let status: String
    
    private var titleText: String {
        switch reportType {
        case .daily:
            return "Daily Progress Report"
        case .weekly:
            return "Weekly Progress Report"
        case .monthly:
            return "Monthly Progress Report"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 4) {
                Text(titleText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 1)
            }

            VStack(spacing: 0) {
                headerRow(label: "Report No.", value: reportNumber)
                Divider()
                headerRow(label: "Date", value: date)
                Divider()
                headerRow(label: "Client Name -", value: clientName)
                Divider()
                headerRow(label: "Project Name -", value: projectName)
                Divider()
                headerRow(label: "Consultant Name:", value: employeeName)
                Divider()
                headerRow(
                    label: reportType == .weekly ? "Weekly Hours:" : "Daily Hours:",
                    value: dailyHours.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Hours Worked: -" : "Hours Worked: \(dailyHours)"
                )
            }
            .font(.subheadline)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.black.opacity(0.6), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("AI Summary")
                    .font(.headline)
                Text(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No AI summary generated yet." : summary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            detailsSection
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(4)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .foregroundColor(.black)
    }

    @ViewBuilder
    private var detailsSection: some View {
        switch reportType {
        case .daily:
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Details")
                    .font(.headline)

                VStack(spacing: 0) {
                    summaryRow(label: "Task Status", value: status)
                    Divider()
                    summaryRow(label: "Objective", value: objective)
                    Divider()
                    summaryRow(label: "Tasks Completed", value: tasksDone)
                    Divider()
                    summaryRow(label: "Obstacles/Challenges", value: obstacles)
                    Divider()
                    summaryRow(label: "Next Action Plan", value: nextActionPlan)
                    Divider()
                    summaryRow(label: "Comments/Remarks", value: comments)
                }
                .font(.subheadline)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.black.opacity(0.6), lineWidth: 1)
                )
            }
        case .weekly:
            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly Details")
                    .font(.headline)

                VStack(spacing: 0) {
                    summaryRow(label: "Task Status", value: status)
                    Divider()
                    summaryRow(label: "Key Achievements", value: tasksDone)
                    Divider()
                    summaryRow(label: "Challenges", value: obstacles)
                    Divider()
                    summaryRow(label: "Urgent Action Items", value: nextActionPlan)
                    Divider()
                    summaryRow(label: "Comments/Remarks", value: comments)
                }
                .font(.subheadline)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.black.opacity(0.6), lineWidth: 1)
                )
            }
        case .monthly:
            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly Details")
                    .font(.headline)

                VStack(spacing: 0) {
                    summaryRow(label: "Task Status", value: status)
                    Divider()
                    summaryRow(label: "Monthly Highlights", value: tasksDone)
                    Divider()
                    summaryRow(label: "Comments/Remarks", value: comments)
                }
                .font(.subheadline)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.black.opacity(0.6), lineWidth: 1)
                )
            }
        }
    }
    
    
    private func headerRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
    }
}

struct DailyReportFullScreenView: View {
    @Environment(\.dismiss) private var dismiss

    let reportNumber: String
    let date: String
    let reportType: ReportType
    let employeeName: String
    let clientName: String
    let projectName: String
    let dailyHours: String
    let objective: String
    let tasksDone: String
    let obstacles: String
    let nextActionPlan: String
    let comments: String
    let summary: String
    let status: String

    var body: some View {
        NavigationView {
            ScrollView {
                DailyProgressReportPreview(
                    reportNumber: reportNumber,
                    date: date,
                    reportType: reportType,
                    employeeName: employeeName,
                    clientName: clientName,
                    projectName: projectName,
                    dailyHours: dailyHours,
                    objective: objective,
                    tasksDone: tasksDone,
                    obstacles: obstacles,
                    nextActionPlan: nextActionPlan,
                    comments: comments,
                    summary: summary,
                    status: status
                )
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Daily Progress Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DailyReportFormView()
}

struct MonthlyReportFormFields: View {
    @Binding var clientName: String
    @Binding var projectName: String
    @Binding var month: Date
    @Binding var executiveSummary: String
    @Binding var keyActivities: String
    @Binding var challengesRisks: String
    @Binding var achievementsHighlights: String
    @Binding var learningsObservations: String
    @Binding var nextMonthObjectives: String
    @Binding var consultantNote: String
    
    var assignedProjects: [Project]
    var onMicTap: (MonthlySpeechField) -> Void
    var micIcon: (MonthlySpeechField) -> String
    var isRecordingForField: (MonthlySpeechField) -> Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Client Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Client Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                TextField("e.g. Acme Corp", text: $clientName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Project Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                Menu {
                    if assignedProjects.isEmpty {
                        Text("No projects assigned")
                    } else {
                        ForEach(assignedProjects) { project in
                            Button(project.name) {
                                projectName = project.name
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(projectName.isEmpty ? "Select project" : projectName)
                            .foregroundColor(projectName.isEmpty ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Month
            VStack(alignment: .leading, spacing: 8) {
                Text("Month")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                DatePicker("", selection: $month, displayedComponents: .date)
                    .labelsHidden()
            }
            
            // Executive Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Executive Summary")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $executiveSummary)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Button(action: { onMicTap(.executiveSummary) }) {
                        Image(systemName: micIcon(.executiveSummary))
                            .foregroundColor(isRecordingForField(.executiveSummary) ? .red : .gray)
                            .padding(12)
                    }
                }
            }
            
            // Key Activities
            VStack(alignment: .leading, spacing: 8) {
                Text("Key Activities (One per line)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $keyActivities)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Button(action: { onMicTap(.keyActivities) }) {
                        Image(systemName: micIcon(.keyActivities))
                            .foregroundColor(isRecordingForField(.keyActivities) ? .red : .gray)
                            .padding(12)
                    }
                }
            }
            
            // Challenges & Risks
            VStack(alignment: .leading, spacing: 8) {
                Text("Challenges & Risks (One per line)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $challengesRisks)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Button(action: { onMicTap(.challengesRisks) }) {
                        Image(systemName: micIcon(.challengesRisks))
                            .foregroundColor(isRecordingForField(.challengesRisks) ? .red : .gray)
                            .padding(12)
                    }
                }
            }
            
            // Achievements / Highlights
            VStack(alignment: .leading, spacing: 8) {
                Text("Achievements / Highlights (One per line)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $achievementsHighlights)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Button(action: { onMicTap(.achievementsHighlights) }) {
                        Image(systemName: micIcon(.achievementsHighlights))
                            .foregroundColor(isRecordingForField(.achievementsHighlights) ? .red : .gray)
                            .padding(12)
                    }
                }
            }
            
            // Learnings & Observations
            VStack(alignment: .leading, spacing: 8) {
                Text("Learnings & Observations")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $learningsObservations)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Button(action: { onMicTap(.learningsObservations) }) {
                        Image(systemName: micIcon(.learningsObservations))
                            .foregroundColor(isRecordingForField(.learningsObservations) ? .red : .gray)
                            .padding(12)
                    }
                }
            }
            
            // Next Month’s Objectives
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Month’s Objectives (One per line)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $nextMonthObjectives)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Button(action: { onMicTap(.nextMonthObjectives) }) {
                        Image(systemName: micIcon(.nextMonthObjectives))
                            .foregroundColor(isRecordingForField(.nextMonthObjectives) ? .red : .gray)
                            .padding(12)
                    }
                }
            }
            
            // Consultant’s Note / Recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Consultant’s Note / Recommendations")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $consultantNote)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Button(action: { onMicTap(.consultantNote) }) {
                        Image(systemName: micIcon(.consultantNote))
                            .foregroundColor(isRecordingForField(.consultantNote) ? .red : .gray)
                            .padding(12)
                    }
                }
            }
        }
    }
}

