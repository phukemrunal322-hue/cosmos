import SwiftUI
import Combine

// Feedback Model
struct ProjectFeedback: Identifiable, Codable {
    let id: UUID
    var projectId: UUID
    var rating: Int
    var category: String
    var feedbackText: String
    var date: Date
    
    init(id: UUID = UUID(), projectId: UUID, rating: Int, category: String, feedbackText: String, date: Date = Date()) {
        self.id = id
        self.projectId = projectId
        self.rating = rating
        self.category = category
        self.feedbackText = feedbackText
        self.date = date
    }
}

// Feedback Manager
class FeedbackManager: ObservableObject {
    @Published var feedbacks: [ProjectFeedback] = []
    
    func addFeedback(_ feedback: ProjectFeedback) {
        feedbacks.append(feedback)
    }
    
    func updateFeedback(_ feedback: ProjectFeedback) {
        if let index = feedbacks.firstIndex(where: { $0.id == feedback.id }) {
            feedbacks[index] = feedback
        }
    }
    
    func getFeedback(for projectId: UUID) -> ProjectFeedback? {
        return feedbacks.first(where: { $0.projectId == projectId })
    }
}

struct ClientProjectsView: View {
    @State private var searchText: String = ""
    @Binding var showCompletedOnly: Bool
    @StateObject private var feedbackManager = FeedbackManager()
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    @State private var showingProjectDetail: Project? = nil
    @State private var showingFeedback: Project? = nil
    
    var filteredProjects: [Project] {
        var projects = firebaseService.projects
        // Eye toggle: when ON (View), only show completed (100%); when OFF (Hide), show incomplete
        projects = projects.filter { proj in
            let p = proj.progress
            let isDone = p > 1 ? p >= 100 : p >= 1.0
            return showCompletedOnly ? isDone : !isDone
        }
        if searchText.isEmpty { return projects }
        return projects.filter { project in
            project.name.localizedCaseInsensitiveContains(searchText) ||
            project.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var eyeToggle: some View {
        Button(action: {
            withAnimation(.easeInOut) { showCompletedOnly.toggle() }
        }) {
            HStack(spacing: 6) {
                Text(showCompletedOnly ? "View" : "Hide")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Image(systemName: showCompletedOnly ? "eye.fill" : "eye.slash.fill")
                    .font(.subheadline)
                    .foregroundColor(showCompletedOnly ? .blue : .gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Eye toggle row
            HStack {
                eyeToggle
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .background(.background)

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(.background)
            .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredProjects) { project in
                        ClientProjectCard(
                            project: project,
                            feedbackManager: feedbackManager,
                            onViewDetails: {
                                showingProjectDetail = project
                            },
                            onGiveFeedback: {
                                showingFeedback = project
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
        }
        .navigationTitle("My Projects")
        .sheet(item: $showingProjectDetail) { project in
            ProjectDetailView(project: project, feedbackManager: feedbackManager)
        }
        .sheet(item: $showingFeedback) { project in
            FeedbackView(project: project, feedbackManager: feedbackManager)
        }
        .onAppear {
            firebaseService.fetchProjectsForClient(
                userUid: authService.currentUid,
                userEmail: authService.currentUser?.email,
                clientName: authService.currentUser?.name
            )
        }
        .refreshable {
            firebaseService.fetchProjectsForClient(
                userUid: authService.currentUid,
                userEmail: authService.currentUser?.email,
                clientName: authService.currentUser?.name
            )
        }
    }
}

struct ClientProjectCard: View {
    let project: Project
    @ObservedObject var feedbackManager: FeedbackManager
    var onViewDetails: (() -> Void)? = nil
    var onGiveFeedback: (() -> Void)? = nil
    
    var progressColor: Color {
        let normalized = normalizedProgress(project.progress)
        if normalized > 0.7 { return .green }
        else if normalized > 0.4 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let manager = project.projectManager, !manager.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Project Manager: \(manager)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(10)
            .background(headerColor)
            .cornerRadius(8)
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(normalizedProgressPercentage(project.progress))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(progressColor)
                }
                
                ProgressView(value: normalizedProgress(project.progress))
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
            }
            
            // Project Timeline
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Date")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(project.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("End Date")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(project.endDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            // Feedback Display (if exists)
            if let feedback = feedbackManager.getFeedback(for: project.id) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your Feedback")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: {
                            onGiveFeedback?()
                        }) {
                            Text("Edit")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= feedback.rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= feedback.rating ? .yellow : .gray)
                        }
                        Text("\(feedback.rating)/5")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text(feedback.category)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                        
                        Spacer()
                    }
                    
                    if !feedback.feedbackText.isEmpty {
                        Text(feedback.feedbackText)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    
                    Text("Submitted: \(feedback.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("View Details") {
                    onViewDetails?()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
                
                Button("Give Feedback") {
                    onGiveFeedback?()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(8)
                
                Spacer()
            }
        }
        .padding()
        .background(.background)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var headerColor: Color {
        let palette: [Color] = [
            Color.blue.opacity(0.16),
            Color.green.opacity(0.16),
            Color.purple.opacity(0.16),
            Color.orange.opacity(0.16),
            Color.pink.opacity(0.16),
            Color.teal.opacity(0.16),
            Color.indigo.opacity(0.16),
            Color.cyan.opacity(0.16)
        ]
        let hash = abs(project.name.hashValue)
        let index = hash % palette.count
        return palette[index]
    }

    // Helper functions to normalize progress values
    private func normalizedProgress(_ progress: Double) -> Double {
        // If progress is > 1, assume it's already in percentage format (e.g., 29, 75)
        // Convert to decimal (0.29, 0.75)
        if progress > 1 {
            return progress / 100.0
        }
        return progress
    }
    
    private func normalizedProgressPercentage(_ progress: Double) -> Int {
        // If progress is > 1, assume it's already in percentage format
        if progress > 1 {
            return Int(progress)
        }
        // Otherwise convert from decimal to percentage
        return Int(progress * 100)
    }
}

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var feedbackManager: FeedbackManager
    @Environment(\.presentationMode) var presentationMode
    
    var progressColor: Color {
        let normalized = normalizedProgress(project.progress)
        if normalized > 0.7 { return .green }
        else if normalized > 0.4 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(project.name)
                            .onAppear {
                                print("ProjectDetailView - Project ID: \(project.id)")
                                print("ProjectDetailView - Total feedbacks: \(feedbackManager.feedbacks.count)")
                                if let fb = feedbackManager.getFeedback(for: project.id) {
                                    print("Found feedback with rating: \(fb.rating)")
                                } else {
                                    print("No feedback found for this project")
                                }
                            }
                            .font(.system(size: 22, weight: .bold))
                        
                        Text(project.description)
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Progress Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Project Progress")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Completion")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(normalizedProgressPercentage(project.progress))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(progressColor)
                            }
                            
                            ProgressView(value: normalizedProgress(project.progress))
                                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                        }
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Timeline Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Project Timeline")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                        .foregroundColor(.green)
                                    Text("Start Date")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Text(project.startDate.formatted(date: .complete, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                HStack {
                                    Text("End Date")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.blue)
                                }
                                Text(project.endDate.formatted(date: .complete, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Time remaining
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("Time remaining: \(project.endDate, style: .relative)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // OKRs Section
                    if !project.objectives.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("OKRs (Objectives & Key Results)")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            ForEach(Array(project.objectives.enumerated()), id: \.element.id) { index, objective in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(index + 1). \(objective.title)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(objective.keyResults) { keyResult in
                                            BulletPointText(text: keyResult.description)
                                        }
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                        }
                        .padding()
                        .background(.background)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OKRs (Objectives & Key Results)")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("No objectives defined for this project yet.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .italic()
                        }
                        .padding()
                        .background(.background)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                    }
                }
                .padding()
            }
            .navigationBarTitle("Project Details", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    // Helper functions to normalize progress values
    private func normalizedProgress(_ progress: Double) -> Double {
        // If progress is > 1, assume it's already in percentage format (e.g., 29, 75)
        // Convert to decimal (0.29, 0.75)
        if progress > 1 {
            return progress / 100.0
        }
        return progress
    }
    
    private func normalizedProgressPercentage(_ progress: Double) -> Int {
        // If progress is > 1, assume it's already in percentage format
        if progress > 1 {
            return Int(progress)
        }
        // Otherwise convert from decimal to percentage
        return Int(progress * 100)
    }
}

struct FeedbackView: View {
    let project: Project
    @ObservedObject var feedbackManager: FeedbackManager
    @Environment(\.presentationMode) var presentationMode
    @State private var rating: Int = 0
    @State private var feedbackText: String = ""
    @State private var selectedCategory: String = "General"
    @State private var showConfirmation = false
    @State private var existingFeedback: ProjectFeedback?
    
    let categories = ["General", "Design", "Development", "Communication", "Timeline", "Quality"]
    
    init(project: Project, feedbackManager: FeedbackManager) {
        self.project = project
        self.feedbackManager = feedbackManager
        
        // Load existing feedback if available
        if let existing = feedbackManager.getFeedback(for: project.id) {
            _existingFeedback = State(initialValue: existing)
            _rating = State(initialValue: existing.rating)
            _feedbackText = State(initialValue: existing.feedbackText)
            _selectedCategory = State(initialValue: existing.category)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Share your feedback to help us improve")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Rating Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Rate this project")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(star <= rating ? .yellow : .gray)
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            rating = star
                                        }
                                    }
                            }
                            
                            Spacer()
                            
                            Text(rating == 0 ? "Tap to rate" : "\(rating)/5")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Feedback Category")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    withAnimation {
                                        selectedCategory = category
                                    }
                                }) {
                                    Text(category)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedCategory == category ? Color.green : Color.gray.opacity(0.1))
                                        .foregroundColor(selectedCategory == category ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Feedback Text
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Your Feedback")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextEditor(text: $feedbackText)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("Share your thoughts, suggestions, or concerns about the project")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Submit Button
                    Button(action: submitFeedback) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Submit Feedback")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(rating > 0 ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(rating == 0)
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarTitle("Give Feedback", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Submit") {
                    submitFeedback()
                }
                .disabled(rating == 0)
            )
            .alert("Feedback Submitted", isPresented: $showConfirmation) {
                Button("OK", role: .cancel) {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Thank you for your feedback! We appreciate your input.")
            }
        }
    }
    
    private func submitFeedback() {
        if let existing = existingFeedback {
            // Update existing feedback
            let updatedFeedback = ProjectFeedback(
                id: existing.id,
                projectId: project.id,
                rating: rating,
                category: selectedCategory,
                feedbackText: feedbackText,
                date: Date()
            )
            feedbackManager.updateFeedback(updatedFeedback)
            print("Updated feedback for project: \(project.id)")
        } else {
            // Create new feedback
            let newFeedback = ProjectFeedback(
                projectId: project.id,
                rating: rating,
                category: selectedCategory,
                feedbackText: feedbackText
            )
            feedbackManager.addFeedback(newFeedback)
            print("Added new feedback for project: \(project.id)")
        }
        
        print("Total feedbacks: \(feedbackManager.feedbacks.count)")
        showConfirmation = true
    }
}
