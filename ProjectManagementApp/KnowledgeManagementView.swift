import SwiftUI
import UniformTypeIdentifiers
import FirebaseFirestore
import UIKit

struct KnowledgeManagementView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab: String = "Knowledge"
    @State private var searchText = ""
    @State private var sortOption = "Newest"
    @State private var showAddSheet = false
    @State private var selectedProject: Project? = nil
    
    // Pagination
    @State private var currentPage = 1
    @State private var itemsPerPage = 6
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Knowledge Management")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("View, create and manage organizational knowledge and documentation.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                
                // Tabs
                HStack(spacing: 16) {
                    KnowledgeTabButton(title: "Knowledge", icon: "book.fill", isSelected: selectedTab == "Knowledge") {
                        selectedTab = "Knowledge"
                    }
                    
                    KnowledgeTabButton(title: "Documentation", icon: "doc.text.fill", isSelected: selectedTab == "Documentation") {
                        selectedTab = "Documentation"
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Content
                if selectedTab == "Knowledge" {
                    KnowledgeContent(
                        searchText: $searchText,
                        sortOption: $sortOption,
                        showAddSheet: $showAddSheet,
                        currentPage: $currentPage,
                        itemsPerPage: $itemsPerPage
                    )
                } else {
                    DocumentationContent(
                        searchText: $searchText,
                        currentPage: $currentPage,
                        itemsPerPage: $itemsPerPage,
                        selectedProject: $selectedProject
                    )
                }
                
                Spacer()
            }
        }
        .environmentObject(authService)
        .onAppear {
            firebaseService.fetchAdminKnowledge()
            firebaseService.fetchEmployees()
            if firebaseService.projects.isEmpty {
                firebaseService.fetchProjects()
            }
            if firebaseService.clients.isEmpty {
                firebaseService.fetchClients()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            KnowledgeFormView(itemToEdit: nil)
                .environmentObject(authService)
        }
    }
}

// ... other structs ...

struct KnowledgeFormView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var firebaseService = FirebaseService.shared
    
    var itemToEdit: AdminKnowledgeItem?
    
    @State private var title = ""
    @State private var description = ""
    @State private var showFileImporter = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedUserIds: Set<String> = []
    @State private var showUserSelection = false
    @State private var links: [String] = []
    @State private var newLink: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Title Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title *")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("e.g. What I learned", text: $title)
                                .font(.system(size: 16))
                            Image(systemName: "mic")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Description Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description *")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Write what you learned from this project...")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                            }
                            
                            TextEditor(text: $description)
                                .font(.system(size: 16))
                                .frame(minHeight: 120)
                                .padding(4)
                                .background(Color.clear)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "mic")
                                .foregroundColor(.gray)
                                .padding()
                            , alignment: .bottomTrailing
                        )
                    }
                    
                    // Documents Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Documents (Optional)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: { showFileImporter = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(red: 0.35, green: 0.25, blue: 0.95))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Button(action: { showFileImporter = true }) {
                            VStack(spacing: 12) {
                                if let name = selectedFileName {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                                    Text(name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Text("Tap to change")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("Click + to add documents")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                    .foregroundColor(Color.gray.opacity(0.4))
                            )
                        }
                    }
                    
                    // Links Section (Optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Links (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("e.g. https://linkname.com", text: $newLink)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .font(.system(size: 16))
                            
                            Button(action: {
                                var trimmed = newLink.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
                                        trimmed = "https://" + trimmed
                                    }
                                    links.append(trimmed)
                                    newLink = ""
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                            }
                            .disabled(newLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        
                        if !links.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(links, id: \.self) { link in
                                    HStack {
                                        Image(systemName: "link")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                        Text(link)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(action: {
                                            if let index = links.firstIndex(of: link) {
                                                links.remove(at: index)
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Manage Resource (Access)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manage Resource (Access)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Button(action: { 
                            withAnimation { showUserSelection.toggle() }
                        }) {
                            HStack {
                                Text(selectedUserIds.isEmpty ? "Accessible to All" : "Accessible to \(selectedUserIds.count) Users")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(showUserSelection ? 90 : 0))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        if showUserSelection {
                            VStack(spacing: 0) {
                                if firebaseService.employees.isEmpty {
                                    Text("No users found")
                                        .padding()
                                        .foregroundColor(.gray)
                                } else {
                                    ForEach(firebaseService.employees) { employee in
                                        Button(action: {
                                            if selectedUserIds.contains(employee.id) {
                                                selectedUserIds.remove(employee.id)
                                            } else {
                                                selectedUserIds.insert(employee.id)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: selectedUserIds.contains(employee.id) ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(selectedUserIds.contains(employee.id) ? Color(red: 0.35, green: 0.25, blue: 0.95) : .gray)
                                                    .font(.system(size: 20))
                                                
                                                Text(employee.name)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                
                                                Text(employee.roleType ?? "Employee")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding()
                                            .background(Color(.secondarySystemGroupedBackground))
                                        }
                                        Divider()
                                    }
                                }
                            }
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(itemToEdit == nil ? "Add Knowledge" : "Edit Knowledge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveKnowledge) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSaving)
                }
            }
            .onAppear {
                if firebaseService.employees.isEmpty {
                    firebaseService.fetchEmployees()
                }
                // Pre-fill if editing
                if let item = itemToEdit, title.isEmpty {
                    title = item.title
                    description = item.description
                    selectedFileName = item.attachmentName
                    if let ids = item.allowedUserIds {
                        selectedUserIds = Set(ids)
                    }
                    if let itemLinks = item.links {
                        links = itemLinks
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let gotAccess = url.startAccessingSecurityScopedResource()
                        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
                        
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            self.selectedFileURL = tempURL
                            self.selectedFileName = url.lastPathComponent
                        } catch {
                            print("Error copying file: \(error.localizedDescription)")
                            self.errorMessage = "Failed to select file: \(error.localizedDescription)"
                        }
                    }
                case .failure(let error):
                    print("File selection error: \(error.localizedDescription)")
                    self.errorMessage = "Error selecting file: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveKnowledge() {
        isSaving = true
        errorMessage = nil
        
        let completionHandler: (Result<String, Error>) -> Void = { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success(_):
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    self.errorMessage = "Error saving: \(error.localizedDescription)"
                }
            }
        }
        
        let savedUserIds = Array(selectedUserIds)
        let savedEmails = firebaseService.employees
            .filter { selectedUserIds.contains($0.id) }
            .compactMap { $0.email }
        
        if let fileURL = selectedFileURL {
            // Upload new file then save/update
            firebaseService.uploadDocument(fileURL: fileURL) { result in
                switch result {
                case .success(let downloadURL):
                    performSaveOrUpdate(attachmentURL: downloadURL, attachmentName: selectedFileName, userIds: savedUserIds, emails: savedEmails, completion: completionHandler)
                case .failure(let error):
                    DispatchQueue.main.async {
                        isSaving = false
                        self.errorMessage = "Failed to upload document: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // No new file, use existing if editing
            let existingURL = itemToEdit?.attachmentURL
            let existingName = selectedFileName // Use current input/state
            performSaveOrUpdate(attachmentURL: existingURL, attachmentName: existingName, userIds: savedUserIds, emails: savedEmails, completion: completionHandler)
        }
    }
    
    private func performSaveOrUpdate(attachmentURL: String?, attachmentName: String?, userIds: [String], emails: [String], completion: @escaping (Result<String, Error>) -> Void) {
        if let item = itemToEdit {
            // Generate Change Log
            var changes: [String] = []
            
            if item.title != title {
                changes.append("Edited title")
            }
            if item.description != description {
                changes.append("Edited description")
            }
            if item.attachmentName != attachmentName {
                if attachmentName != nil && item.attachmentName == nil {
                     changes.append("Added document")
                } else if attachmentName == nil && item.attachmentName != nil {
                     changes.append("Removed document")
                } else {
                     changes.append("Edited document")
                }
            }
            
            let oldUserIds = Set(item.allowedUserIds ?? [])
            let newUserIds = Set(userIds)
            if oldUserIds != newUserIds {
                let addedCount = newUserIds.subtracting(oldUserIds).count
                let removedCount = oldUserIds.subtracting(newUserIds).count
                if addedCount > 0 && removedCount > 0 {
                    changes.append("Reassigned access")
                } else if addedCount > 0 {
                    changes.append("Granted access to \(addedCount) new user(s)")
                } else if removedCount > 0 {
                    changes.append("Revoked access from \(removedCount) user(s)")
                } else {
                    changes.append("Edited access permissions")
                }
            }
            
            let oldLinks = Set(item.links ?? [])
            let newLinks = Set(links)
            if oldLinks != newLinks {
                 changes.append("Edited links")
            }
            
            let changeLog = changes.isEmpty ? "Edited details" : changes.joined(separator: ", ")
            
            firebaseService.updateAdminKnowledge(
                documentId: item.id,
                title: title,
                bodyText: description,
                attachmentName: attachmentName,
                attachmentURL: attachmentURL,
                allowedUserIds: userIds,
                allowedEmails: emails,
                links: links,
                changeLog: changeLog
            ) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(item.id))
                }
            }
        } else {
            firebaseService.saveAdminKnowledge(
                userUid: authService.currentUid,
                userEmail: authService.currentUser?.email,
                userName: authService.currentUser?.name ?? "Super Admin",
                title: title,
                bodyText: description,
                attachmentName: attachmentName,
                attachmentURL: attachmentURL,
                allowedUserIds: userIds,
                allowedEmails: emails,
                links: links,
                completion: completion
            )
        }
    }
}



struct KnowledgeTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color(.systemBackground) : Color.clear)
            .foregroundColor(isSelected ? .purple : .gray)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color(uiColor: .separator) : Color.clear, lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.black.opacity(0.05) : Color.clear, radius: 2, x: 0, y: 1)
        }
    }
}

struct AdminKnowledgeItem: Identifiable {
    let id: String
    var title: String
    var description: String
    var createdAt: Date
    var updatedAt: Date
    var attachmentName: String?
    var attachmentURL: String?
    var createdBy: String?
    var allowedUserIds: [String]?

    var allowedEmails: [String]?
    var links: [String]?
}

struct KnowledgeContent: View {
    @Binding var searchText: String
    @Binding var sortOption: String
    @Binding var showAddSheet: Bool
    @Binding var currentPage: Int
    @Binding var itemsPerPage: Int
    @State private var selectedItem: AdminKnowledgeItem? = nil
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    var filteredItems: [AdminKnowledgeItem] {
        let items = firebaseService.adminKnowledgeItems
        let filtered: [AdminKnowledgeItem]
        if searchText.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if sortOption == "Oldest" {
            return filtered.sorted { $0.createdAt < $1.createdAt }
        } else {
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    var paginatedItems: [AdminKnowledgeItem] {
        let start = (currentPage - 1) * itemsPerPage
        let end = min(start + itemsPerPage, filteredItems.count)
        guard start < end else { return [] }
        return Array(filteredItems[start..<end])
    }
    
    var totalPages: Int {
        max(1, Int(ceil(Double(filteredItems.count) / Double(itemsPerPage))))
    }
    
    var body: some View {
        ZStack {
            if let item = selectedItem {
                KnowledgeDetailView(item: item) {
                    withAnimation { selectedItem = nil }
                }
                .transition(.move(edge: .trailing))
                .zIndex(1)
            } else {
                VStack(spacing: 16) {
                    // Search & Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Search & Actions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            // Search Bar with Add Button
                            HStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                    TextField("Search by title or description", text: $searchText)
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray, lineWidth: 2)
                                )
                                
                                // Circular Add Button
                                Button(action: { showAddSheet = true }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(red: 0.6, green: 0.2, blue: 0.9), Color(red: 0.5, green: 0.15, blue: 0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .clipShape(Circle())
                                        .shadow(color: Color(red: 0.6, green: 0.2, blue: 0.9).opacity(0.4), radius: 8, x: 0, y: 4)
                                }
                            }
                            
                            // Filter and Sort Row
                            HStack(spacing: 12) {
                                // Filter Button
                                Button(action: {
                                    // Filter action - can be implemented later
                                }) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(red: 0.6, green: 0.2, blue: 0.9), Color(red: 0.5, green: 0.15, blue: 0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .clipShape(Circle())
                                        .shadow(color: Color(red: 0.6, green: 0.2, blue: 0.9).opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                                
                                // Sort Dropdown
                                Menu {
                                    Picker("", selection: $sortOption) {
                                        Text("Newest").tag("Newest")
                                        Text("Oldest").tag("Oldest")
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("Sort by")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        HStack(spacing: 4) {
                                            Text(sortOption)
                                                .font(.subheadline)
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    .padding(.horizontal)
                    
                    // Knowledge Grid
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            PaginationControls(
                                currentPage: $currentPage,
                                itemsPerPage: $itemsPerPage,
                                totalPages: totalPages
                            )
                            .padding(.horizontal)
                            
                            HStack {
                                Text("All Knowledge")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)
        
                            LazyVStack(spacing: 16) {
                                ForEach(paginatedItems) { item in
                                    KnowledgeCard(item: item)
                                        .onTapGesture {
                                            withAnimation { selectedItem = item }
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80)
                        }
                    }
                }
                .transition(.move(edge: .leading))
            }
        }
    }
}

struct KnowledgeCard: View {
    let item: AdminKnowledgeItem
    @State private var showEditSheet = false
    @ObservedObject private var firebaseService = FirebaseService.shared
    @EnvironmentObject var authService: FirebaseAuthService
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M/yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                }
                
                // Title
                Text(item.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: { showEditSheet = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    
                    Button(role: .destructive, action: {
                        firebaseService.deleteAdminKnowledge(documentId: item.id)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            // Body
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(5)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            if let attachmentName = item.attachmentName,
               !attachmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "paperclip")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text(attachmentName)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(6)
            }
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            // Footer
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Created
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                            .font(.system(size: 11))
                        Text("Created")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(dateFormatter.string(from: item.createdAt))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    // By Author
                    if let author = item.createdBy {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 11))
                            Text("By")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(author)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Updated
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 11))
                        Text("Updated")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(dateFormatter.string(from: item.updatedAt))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 20)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showEditSheet) {
            KnowledgeFormView(itemToEdit: item)
                .environmentObject(authService)
        }
    }
}

struct DocumentationContent: View {
    @Binding var searchText: String
    @Binding var currentPage: Int
    @Binding var itemsPerPage: Int
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedProject: Project?
    
    var filteredProjects: [Project] {
        let items = firebaseService.projects
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { project in
                let matchName = project.name.localizedCaseInsensitiveContains(searchText)
                let matchClient = (project.clientName ?? "").localizedCaseInsensitiveContains(searchText)
                let matchManager = (project.projectManager ?? "").localizedCaseInsensitiveContains(searchText)
                return matchName || matchClient || matchManager
            }
        }
    }
    
    var paginatedProjects: [Project] {
        let start = (currentPage - 1) * itemsPerPage
        let end = min(start + itemsPerPage, filteredProjects.count)
        guard start < end else { return [] }
        return Array(filteredProjects[start..<end])
    }
    
    var totalPages: Int {
        max(1, Int(ceil(Double(filteredProjects.count) / Double(itemsPerPage))))
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            if let project = selectedProject {
                ProjectDocumentsDetailView(project: project, onBack: {
                    selectedProject = nil
                })
                .transition(.move(edge: .trailing))
            } else {
                VStack(spacing: 0) {
                    // Search Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Search")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                            TextField("Search projects...", text: $searchText)
                                .font(.system(size: 14))
                        }
                        .padding(12)
                        .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(white: 0.1) : Color(.systemGroupedBackground))
                    
                    // Cards Section
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(paginatedProjects.enumerated()), id: \.element.documentId) { index, project in
                                let globalIndex = (currentPage - 1) * itemsPerPage + index + 1
                                
                                Button(action: {
                                    withAnimation {
                                        selectedProject = project
                                    }
                                }) {
                                    ProjectDocumentationCard(
                                        index: globalIndex,
                                        project: project,
                                        dateFormatter: dateFormatter
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 80)
                    }
                }
                .background(colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
                .transition(.move(edge: .leading))
            }
        }
    }
}

// MARK: - Project Document Model
struct ProjectDocument: Identifiable {
    let id: String
    let documentName: String
    let folderName: String
    let folderType: String
    let fileName: String
    let fileURL: String
    let uploadedBy: String
    let uploadedAt: Date
    let allowedUserIds: [String]? // List of user IDs who have access
    let allowedEmails: [String]? // List of user Emails who have access
}

struct ProjectDocumentsDetailView: View {
    let project: Project
    let onBack: () -> Void
    @State private var localSearchText = ""
    @Environment(\.colorScheme) var colorScheme
    @State private var showAddDocumentForm = false
    @State private var showManageFolders = false
    @State private var documents: [ProjectDocument] = []
    @State private var projectFolders: [ProjectFolder] = []
    @State private var editingDocument: ProjectDocument?
    @State private var selectedDetailDocument: ProjectDocument?
    
    // Real-time updates management
    @State private var listeners: [ListenerRegistration] = []
    @State private var folderDocumentsMap: [String: [ProjectDocument]] = [:]
    
    var allFolders: [ProjectFolder] {
        let defaults = [
            ProjectFolder(id: "default_daily", name: "Daily Report", colorHex: "00FF00", createdAt: Date()),
            ProjectFolder(id: "default_moms", name: "MOMs", colorHex: "800080", createdAt: Date())
        ]
        
        let customFolders = projectFolders.filter { custom in
            !defaults.contains { def in 
                def.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == 
                custom.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        }
        
        return defaults + customFolders
    }
    
    var filteredDocuments: [ProjectDocument] {
        if localSearchText.isEmpty {
            return documents
        } else {
            return documents.filter { doc in
                doc.documentName.localizedCaseInsensitiveContains(localSearchText) ||
                doc.folderName.localizedCaseInsensitiveContains(localSearchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar (Breadcrumb)
            HStack(spacing: 8) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.gray)
                }
                
                Text("/")
                    .foregroundColor(.gray)
                
                Text(project.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                
                Spacer()
                
                // Refresh button removed as per request - Real-time updates implemented
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(colorScheme == .dark ? Color(white: 0.15) : Color.gray.opacity(0.1)),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Search & Actions Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Search & Actions")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 10) {
                            // Search Bar
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                                TextField("Search...", text: $localSearchText)
                                    .font(.system(size: 12))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            
                            // Action Buttons Row
                            HStack(spacing: 8) {
                                // Add Document Button
                                Button(action: {
                                    showAddDocumentForm = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Add Document")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.35, green: 0.25, blue: 0.95))
                                    .cornerRadius(8)
                                }
                                
                                // Add Folder Button
                                Button(action: {
                                    showManageFolders = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Add Folder")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.35, green: 0.25, blue: 0.95))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.98))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color(white: 0.2) : Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    
                    // Documents Sections
                    if !documents.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            ForEach(allFolders) { folder in
                                let folderDocs = filteredDocuments.filter { doc in
                                    if folder.name == "Daily Report" {
                                        return isCategory(["Daily Report", "daily", "employeeDailyReports"], target: doc.folderType)
                                    } else if folder.name == "MOMs" {
                                        return isCategory(["MOMs", "MOM", "minutes", "meeting"], target: doc.folderType)
                                    } else {
                                        return doc.folderType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                                               folder.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    }
                                }
                                
                                if !folderDocs.isEmpty {
                                    DocumentSection(
                                        title: folder.name.uppercased(),
                                        count: folderDocs.count,
                                        color: folder.color,
                                        documents: folderDocs,
                                        onEdit: { doc in editingDocument = doc },
                                        onDelete: { doc in deleteDocument(doc) },
                                        onView: { doc in selectedDetailDocument = doc }
                                    )
                                }
                            }
                            
                            // Others / Uncategorized Section
                            let others = filteredDocuments.filter { doc in
                                !allFolders.contains { folder in
                                    if folder.name == "Daily Report" {
                                        return isCategory(["Daily Report", "daily", "employeeDailyReports"], target: doc.folderType)
                                    } else if folder.name == "MOMs" {
                                        return isCategory(["MOMs", "MOM", "minutes", "meeting"], target: doc.folderType)
                                    } else {
                                        return doc.folderType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                                               folder.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    }
                                }
                            }
                            
                            if !others.isEmpty {
                                DocumentSection(
                                    title: "OTHER DOCUMENTS",
                                    count: others.count,
                                    color: .orange,
                                    documents: others,
                                    onEdit: { doc in editingDocument = doc },
                                    onDelete: { doc in deleteDocument(doc) },
                                    onView: { doc in selectedDetailDocument = doc }
                                )
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No documents yet")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            Text("Add your first document using the button above")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .sheet(isPresented: $showAddDocumentForm) {
            AddDocumentFormView(project: project)
                .interactiveDismissDisabled()
        }
        .onAppear {
            fetchDocuments()
            fetchProjectFolders()
        }
        .sheet(isPresented: $showManageFolders) {
            ManageFoldersView(projectId: project.documentId ?? "", isPresented: $showManageFolders)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingDocument) { doc in
            EditDocumentView(document: doc, projectId: project.documentId ?? "", availableFolders: allFolders.map { $0.name })
        }
        .sheet(item: $selectedDetailDocument) { doc in
            DocumentDetailSheet(document: doc, projectId: project.documentId ?? "")
                .onDisappear {
                    cleanupListeners()
                }
        }
    }
    
    private func fetchProjectFolders() {
        guard let projectId = project.documentId else { return }
        let db = Firestore.firestore()
        
        // 1. Fetch Global/Default Folders
        db.collection("documents").document("folders")
            .addSnapshotListener { snapshot, error in
                var globalFolders: [ProjectFolder] = []
                if let data = snapshot?.data(),
                   let foldersArray = data["folders"] as? [[String: Any]] {
                    globalFolders = foldersArray.compactMap { dict -> ProjectFolder? in
                        let name = dict["name"] as? String ?? ""
                        let color = dict["color"] as? String ?? "#000000"
                        return ProjectFolder(id: "global_\(name)", name: name, colorHex: color, createdAt: nil)
                    }
                }
                
                // 2. Fetch Project Specific Folders
                db.collection("projects").document(projectId)
                    .addSnapshotListener { projectSnapshot, projectError in
                        var projectFoldersArray: [ProjectFolder] = []
                        if let data = projectSnapshot?.data(),
                           let foldersArray = data["folders"] as? [[String: Any]] {
                            projectFoldersArray = foldersArray.compactMap { dict -> ProjectFolder? in
                                let name = dict["name"] as? String ?? ""
                                let color = dict["color"] as? String ?? "#000000"
                                return ProjectFolder(id: UUID().uuidString, name: name, colorHex: color, createdAt: nil)
                            }
                        }
                        
                        // Merge
                        let allFolders = globalFolders + projectFoldersArray
                        var uniqueFolders: [ProjectFolder] = []
                        var seenNames = Set<String>()
                        
                        for folder in allFolders {
                            if !seenNames.contains(folder.name.lowercased()) {
                                uniqueFolders.append(folder)
                                seenNames.insert(folder.name.lowercased())
                            }
                        }
                        
                        self.projectFolders = uniqueFolders
                    }
            }
    }
    
    private func deleteDocument(_ document: ProjectDocument) {
        let db = Firestore.firestore()
        
        // Strategy: Try to delete from sub-collection first (preferred structure)
        // If we have a projectId and folderType, we can construct the path.
        if let projectId = project.documentId, !document.folderType.isEmpty {
           let docRef = db.collection("documents").document(projectId).collection(document.folderType).document(document.id)
            
           docRef.delete { error in
               if let error = error {
                   print("⚠️ Error removing from sub-collection: \(error.localizedDescription)")
                   // Fallback: Try root collection just in case it's a legacy doc
                   self.deleteLegacyDocument(document)
               } else {
                   print("✅ Document deleted from folder: \(document.folderType)")
               }
           }
        } else {
            // Fallback for legacy docs
            deleteLegacyDocument(document)
        }
    }
    
    private func deleteLegacyDocument(_ document: ProjectDocument) {
        let db = Firestore.firestore()
        db.collection("documents").document(document.id).delete { error in
             if let error = error {
                 print("Error removing legacy document: \(error)")
             } else {
                 print("✅ Legacy document deleted")
             }
         }
    }

    private func fetchDocuments() {
        // 1. Clean up existing listeners if any
        cleanupListeners()
        
        let db = Firestore.firestore()
        guard let projectId = project.documentId, !projectId.isEmpty else {
            print("⚠️ No project ID available!")
            return
        }
        
        print("📄 Setting up REAL-TIME listeners for project: \(project.name)")
        
        // 2. Listener for Legacy/Root Documents
        let legacyListener = db.collection("documents")
            .whereField("projectId", isEqualTo: projectId)
            .addSnapshotListener { snapshot, error in
                if let docs = snapshot?.documents {
                    let mapped = docs.compactMap { self.mapDocument($0) }
                    self.folderDocumentsMap["_legacy"] = mapped
                    self.rebuildDocumentsList()
                }
            }
        listeners.append(legacyListener)
            
        // 3. Listeners for Sub-collections (Folders)
        // We listen to known default folders + dynamic project folders
        let foldersToFetch = ["Daily Report", "MOMs"] + projectFolders.map { $0.name }
        let uniqueFolders = Array(Set(foldersToFetch))
        
        for folderName in uniqueFolders {
            let listener = db.collection("documents").document(projectId).collection(folderName)
                .addSnapshotListener { snapshot, error in
                    if let docs = snapshot?.documents {
                         let mapped = docs.compactMap { self.mapDocument($0, folderNameOverride: folderName) }
                         self.folderDocumentsMap[folderName] = mapped
                         self.rebuildDocumentsList()
                    }
                }
            listeners.append(listener)
        }
    }
    
    private func rebuildDocumentsList() {
        // Aggregate all documents from the map
        let allDocs = folderDocumentsMap.values.flatMap { $0 }
        
        let currentUserEmail = FirebaseAuthService.shared.currentUser?.email ?? ""
        let currentUserUid = FirebaseAuthService.shared.currentUid ?? ""
        
        let filtered = allDocs.filter { doc in
             // 1. Uploader always has access
            if doc.uploadedBy == currentUserEmail { return true }
            
             // 2. Check User IDs
            if let allowed = doc.allowedUserIds, !allowed.isEmpty {
                 if allowed.contains(currentUserUid) { return true }
            }
            
            // 3. Check Emails
            if let allowedEmails = doc.allowedEmails, !allowedEmails.isEmpty {
                if allowedEmails.contains(currentUserEmail) { return true }
            }
            
            // 4. Fallback (Legacy public/unrestricted)
            if (doc.allowedUserIds == nil || doc.allowedUserIds!.isEmpty) &&
               (doc.allowedEmails == nil || doc.allowedEmails!.isEmpty) {
                return true
            }
            return false
        }.sorted(by: { $0.uploadedAt > $1.uploadedAt })
        
        // Update main state
        DispatchQueue.main.async {
            self.documents = filtered
            print("📊 Real-time update: \(self.documents.count) documents total")
        }
    }
    
    private func cleanupListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        folderDocumentsMap.removeAll()
    }
    
    private func mapDocument(_ doc: QueryDocumentSnapshot, folderNameOverride: String? = nil) -> ProjectDocument? {
        let data = doc.data()
        
        let documentName = data["title"] as? String ?? data["documentName"] as? String ?? data["filename"] as? String ?? data["name"] as? String ?? "Untitled"
        let folderName = folderNameOverride ?? data["folderName"] as? String ?? data["folder"] as? String ?? "Documents"
        let folderType = data["folderType"] as? String ?? data["folder"] as? String ?? folderName
        
        let fileName = data["fileName"] as? String ?? data["filename"] as? String ?? "Unknown File"
        let fileURL = data["fileURL"] as? String ?? data["url"] as? String ?? ""
        let uploadedBy = data["uploadedBy"] as? String ?? "Unknown"
        let uploadedAt: Date
        if let timestamp = data["uploadedAt"] as? Timestamp {
            uploadedAt = timestamp.dateValue()
        } else if let date = data["uploadedAt"] as? Date {
            uploadedAt = date
        } else {
            uploadedAt = Date()
        }
        
        let allowedUserIds = data["allowedUserIds"] as? [String]
        let allowedEmails = data["allowedEmails"] as? [String]
        
        return ProjectDocument(
            id: doc.documentID,
            documentName: documentName,
            folderName: folderName,
            folderType: folderType,
            fileName: fileName,
            fileURL: fileURL,
            uploadedBy: uploadedBy,
            uploadedAt: uploadedAt,
            allowedUserIds: allowedUserIds,
            allowedEmails: allowedEmails
        )
    }
    private func isCategory(_ types: [String], target: String) -> Bool {
        let t = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return types.contains { t.contains($0.lowercased()) }
    }
}

// MARK: - Document Section
struct DocumentSection: View {
    let title: String
    let count: Int
    let color: Color
    let documents: [ProjectDocument]
    var onEdit: (ProjectDocument) -> Void
    var onDelete: (ProjectDocument) -> Void
    var onView: (ProjectDocument) -> Void = { _ in } // Default empty
    @State private var isExpanded: Bool = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // Section Title Badge
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Expand/Collapse Icon
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Documents List
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(documents) { document in
                        DocumentCard(
                            document: document,
                            onEdit: { onEdit(document) },
                            onDelete: { onDelete(document) },
                            onView: { onView(document) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Document Card
struct DocumentCard: View {
    let document: ProjectDocument
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onView: () -> Void = {}
    @Environment(\.colorScheme) var colorScheme
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Document Icon
                Image(systemName: "doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.documentName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    
                    Text(document.fileName)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Folder Type Badge
                Text(document.folderType)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(document.folderType == "MOMs" ? Color.purple : Color.green) // This logic will be overridden by folder color locally if passed, but good fallback
                    .cornerRadius(8)
                
                // Actions Menu
                Menu {
                    Button(action: {
                        onView()
                    }) {
                        Label("View", systemImage: "eye")
                    }
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .foregroundColor(.gray)
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
            
            // Bottom Info
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Uploaded by:")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.8))
                    Text(document.uploadedBy)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: document.uploadedAt))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 12)
    }
}

// MARK: - Project Documentation Card
struct ProjectDocumentationCard: View {
    let index: Int
    let project: Project
    let dateFormatter: DateFormatter
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Header with Index and Project Name
            HStack(spacing: 10) {
                // Smaller Index Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.6, green: 0.2, blue: 0.9),
                                    Color(red: 0.75, green: 0.35, blue: 1.0)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text("\(index)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let client = project.clientName {
                        HStack(spacing: 3) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.purple.opacity(0.6))
                            Text(client)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Progress Circle Badge
                ZStack {
                    Circle()
                        .stroke(
                            colorScheme == .dark ? Color(white: 0.2) : Color.gray.opacity(0.15),
                            lineWidth: 3
                        )
                        .frame(width: 42, height: 42)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(project.progress / 100.0))
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.6, green: 0.2, blue: 0.9),
                                    Color(red: 0.8, green: 0.4, blue: 1.0)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 42, height: 42)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(project.progress))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: colorScheme == .dark 
                            ? [Color(white: 0.16), Color(white: 0.14)]
                            : [Color(white: 0.99), Color(white: 0.97)]
                        ),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Subtle top highlight
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.08),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            
            // Thin Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.3),
                            Color.purple.opacity(0.1),
                            Color.purple.opacity(0.3)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            // Compact Body - Project Details
            VStack(spacing: 10) {
                // Project Manager Row
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Manager")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(project.projectManager ?? "Unassigned")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                
                // Timeline Row
                HStack(spacing: 12) {
                    // Start Date
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Start")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(dateFormatter.string(from: project.startDate))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    // End Date
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("End")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(dateFormatter.string(from: project.endDate))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(colorScheme == .dark ? Color(white: 0.11) : Color.white)
        }
        .background(
            ZStack {
                // Base background
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(white: 0.11) : Color.white)
                
                // Glassmorphism effect
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.purple.opacity(0.03),
                                Color.clear,
                                Color.purple.opacity(0.02)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .cornerRadius(14)
        .shadow(
            color: colorScheme == .dark 
                ? Color.purple.opacity(0.2)
                : Color.black.opacity(0.06),
            radius: 10,
            x: 0,
            y: 3
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.purple.opacity(0.4), location: 0),
                            .init(color: Color.purple.opacity(0.1), location: 0.5),
                            .init(color: Color.purple.opacity(0.4), location: 1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            
            // Label and Value
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Modern Table Components
struct ModernTableHeaderCell: View {
    let text: String
    let width: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
            .frame(width: width, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark 
                        ? [Color(white: 0.2), Color(white: 0.18)]
                        : [Color(white: 0.96), Color(white: 0.94)]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Rectangle()
                    .stroke(colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.88), lineWidth: 0.5)
            )
    }
}

struct ModernTableRow: View {
    let index: Int
    let project: Project
    let isEven: Bool
    let dateFormatter: DateFormatter
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // SR. NO.
            ModernTableCell(text: "\(index)", width: 70)
            
            // Project Name
            ModernTableCell(text: project.name, width: 150, isBold: true)
            
            // Client Name
            ModernTableCell(text: project.clientName ?? "-", width: 150)
            
            // Project Manager
            ModernTableCell(text: project.projectManager ?? "-", width: 150)
            
            // Progress with Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color(white: 0.2) : Color.gray.opacity(0.15))
                                .frame(height: 10)
                            
                            // Progress Fill
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.6, green: 0.2, blue: 0.9),
                                            Color(red: 0.7, green: 0.3, blue: 1.0)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(project.progress / 100.0), height: 10)
                        }
                    }
                    .frame(height: 10)
                    
                    // Percentage Text
                    Text("\(Int(project.progress))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .frame(width: 180)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(isEven 
                ? (colorScheme == .dark ? Color(white: 0.12) : Color.white)
                : (colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97))
            )
            .overlay(
                Rectangle()
                    .stroke(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.92), lineWidth: 0.5)
            )
            
            // Start Date
            ModernTableCell(text: dateFormatter.string(from: project.startDate), width: 110)
            
            // End Date
            ModernTableCell(text: dateFormatter.string(from: project.endDate), width: 110)
        }
        .background(isEven 
            ? (colorScheme == .dark ? Color(white: 0.12) : Color.white)
            : (colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97))
        )
    }
}

struct ModernTableCell: View {
    let text: String
    let width: CGFloat
    var isBold: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: isBold ? .semibold : .regular))
            .foregroundColor(colorScheme == .dark ? Color(white: 0.9) : Color.black)
            .lineLimit(2)
            .frame(width: width, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .overlay(
                Rectangle()
                    .stroke(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.92), lineWidth: 0.5)
            )
    }
}

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .opacity(0.1)
                .foregroundColor(.purple)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .foregroundColor(.purple)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.purple)
        }
    }
}

struct EditKnowledgeSheet: View {
    let item: AdminKnowledgeItem
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String
    @State private var description: String
    @StateObject private var firebaseService = FirebaseService.shared
    
    init(item: AdminKnowledgeItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _description = State(initialValue: item.description)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Knowledge")) {
                    TextField("Title", text: $title)
                    TextEditor(text: $description)
                        .frame(height: 150)
                }
            }
            .navigationTitle("Edit Knowledge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        firebaseService.updateAdminKnowledge(
                            documentId: item.id,
                            title: title,
                            bodyText: description,
                            attachmentName: item.attachmentName,
                            attachmentURL: item.attachmentURL
                        ) { _ in
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Document Form View
struct AddDocumentFormView: View {
    let project: Project
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    @State private var documentName = ""
    @State private var selectedFolder = ""
    
    // Access Control
    @State private var selectedAdminIds: Set<String> = []
    @State private var selectedMemberIds: Set<String> = []
    @State private var showFolderDropdown = false
    @State private var showFilePicker = false
    @State private var selectedFileName = "no file selected"
    @State private var selectedFileURL: URL?
    @State private var isSaving = false
    
    // Sample folders - you can fetch these from Firebase
    let availableFolders = ["Daily Report", "MOMs"]
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                            Text("Document Details")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 8)
                        
                        // Name of document
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name of document *")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("e.g. Project Requirements", text: $documentName)
                                .font(.system(size: 14))
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                    // Folder Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Folder Name *")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        ZStack {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showFolderDropdown.toggle()
                                }
                            }) {
                                HStack {
                                    Text(selectedFolder.isEmpty ? "Select a folder" : selectedFolder)
                                        .font(.system(size: 14))
                                        .foregroundColor(selectedFolder.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(12)
                                .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            // Dropdown Menu
                            if showFolderDropdown {
                                VStack(spacing: 1) {
                                    ForEach(Array(availableFolders.enumerated()), id: \.element) { index, folder in
                                        Button(action: {
                                            selectedFolder = folder
                                            withAnimation {
                                                showFolderDropdown = false
                                            }
                                        }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: selectedFolder == folder ? "checkmark" : "")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 20)
                                                Text(folder)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.white)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 14)
                                            .background(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.25))
                                            .cornerRadius(index == 0 ? 10 : 0, corners: index == 0 ? [.topLeft, .topRight] : [])
                                            .cornerRadius(index == availableFolders.count - 1 ? 10 : 0, corners: index == availableFolders.count - 1 ? [.bottomLeft, .bottomRight] : [])
                                        }
                                    }
                                }
                                .background(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.25))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                )
                                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)
                                .offset(y: 52)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                                .zIndex(1000)
                            }
                        }
                    }
                    .zIndex(showFolderDropdown ? 1000 : 0)
                    .padding(.bottom, showFolderDropdown ? 100 : 0)
                    
                    // Access Control Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.4)) // Greenish
                                .padding(6)
                                .background(Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Access")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        HStack(spacing: 16) {
                            // Admin Users
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ADMIN USERS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                
                                Menu {
                                    ForEach(firebaseService.employees.filter { ($0.roleType ?? "").lowercased().contains("admin") }) { employee in
                                        Button(action: {
                                            if selectedAdminIds.contains(employee.id) {
                                                selectedAdminIds.remove(employee.id)
                                            } else {
                                                selectedAdminIds.insert(employee.id)
                                            }
                                        }) {
                                            HStack {
                                                Text(employee.name)
                                                if selectedAdminIds.contains(employee.id) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if selectedAdminIds.isEmpty {
                                            Text("No admin users")
                                                .foregroundColor(.gray)
                                        } else {
                                            Text("\(selectedAdminIds.count) selected")
                                                .foregroundColor(.primary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(10)
                                    .frame(height: 40)
                                    .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            
                            // Member Users
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MEMBER USERS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                
                                Menu {
                                    ForEach(firebaseService.employees.filter { !($0.roleType ?? "").lowercased().contains("admin") }) { employee in
                                        Button(action: {
                                            if selectedMemberIds.contains(employee.id) {
                                                selectedMemberIds.remove(employee.id)
                                            } else {
                                                selectedMemberIds.insert(employee.id)
                                            }
                                        }) {
                                            HStack {
                                                Text(employee.name)
                                                if selectedMemberIds.contains(employee.id) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if selectedMemberIds.isEmpty {
                                            Text("No member users")
                                                .foregroundColor(.gray)
                                        } else {
                                            Text("\(selectedMemberIds.count) selected")
                                                .foregroundColor(.primary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(10)
                                    .frame(height: 40)
                                    .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    // Upload document
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Upload document *")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                        }
                        
                        Button(action: {
                            showFilePicker = true
                        }) {
                            HStack {
                                Text("Choose File")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(selectedFileName)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(12)
                            .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            }
            .background(colorScheme == .dark ? Color.black : Color(white: 0.98))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveDocument()
                    }
                    .disabled(documentName.isEmpty || selectedFolder.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(selectedFileURL: $selectedFileURL, selectedFileName: $selectedFileName)
            }
        }
    }
    
    private func saveDocument() {
        guard !documentName.isEmpty, !selectedFolder.isEmpty else { return }
        
        isSaving = true
        
        // Resolve selected IDs to Emails
        let allEmployees = firebaseService.employees
        let selectedEmployees = allEmployees.filter { 
            selectedAdminIds.contains($0.id) || selectedMemberIds.contains($0.id) 
        }
        let allowedUserIds = Array(selectedAdminIds.union(selectedMemberIds))
        let allowedEmails = selectedEmployees.map { $0.email }
        
        // Get current user email from auth service
        let authService = FirebaseAuthService.shared
        let currentUserEmail = authService.currentUser?.email ?? "Unknown"
        
        print("💾 Saving document...")
        print("📄 Document Name: \(documentName)")
        print("📁 Folder Type: \(selectedFolder)")
        print("📦 Project: \(project.name)")
        print("🆔 Project ID: \(project.documentId ?? "nil")")
        
        // Create document data
        let documentData: [String: Any] = [
            "documentName": documentName,
            "title": documentName,
            "folderName": selectedFolder,
            "folderType": selectedFolder, // "MOMs" or "Daily Report"
            "projectId": project.documentId ?? "",
            "projectName": project.name,
            "uploadedBy": currentUserEmail,
            "uploadedAt": Date(),
            "fileName": selectedFileName,
            "fileURL": selectedFileURL?.absoluteString ?? "",
            "allowedUserIds": allowedUserIds,
            "allowedEmails": allowedEmails
        ]
        
        // Save to Firebase using local Firestore instance - STORE IN SUB-COLLECTION
        let db = Firestore.firestore()
        
        let targetCollection: CollectionReference
        if let projectId = project.documentId {
            // Structure: documents -> {projectId} -> {FolderName} -> {Document}
            // This groups documents by Project AND Folder, which is much cleaner and matches User's screenshot structure
            targetCollection = db.collection("documents").document(projectId).collection(selectedFolder)
        } else {
            // Fallback for some reason if no project ID (shouldn't happen for project docs)
            targetCollection = db.collection("documents")
        }
        
        var docRef: DocumentReference? = nil
        docRef = targetCollection.addDocument(data: documentData) { error in
            isSaving = false
            if let error = error {
                print("❌ Error saving document: \(error.localizedDescription)")
            } else {
                print("✅ Document saved successfully to folder: \(selectedFolder)")
                
                // Log Activity
                if let pid = project.documentId, let newDocId = docRef?.documentID {
                    FirebaseService.shared.logDocumentActivity(
                        projectId: pid,
                        folderName: selectedFolder,
                        documentId: newDocId,
                        description: "Created document",
                        user: FirebaseAuthService.shared.currentUser?.name ?? currentUserEmail
                    )
                }
                
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileURL: URL?
    @Binding var selectedFileName: String
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .text, .data])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedFileURL = url
            parent.selectedFileName = url.lastPathComponent
        }
    }
}

// MARK: - Edit Document View
struct EditDocumentView: View {
    let document: ProjectDocument
    let projectId: String
    let availableFolders: [String]
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    @State private var documentName: String
    @State private var selectedFolder: String
    @State private var showFolderDropdown = false
    @State private var showFilePicker = false
    @State private var selectedFileName: String
    @State private var selectedFileURL: URL?
    @State private var isSaving = false
    
    init(document: ProjectDocument, projectId: String, availableFolders: [String]) {
        self.document = document
        self.projectId = projectId
        self.availableFolders = availableFolders.isEmpty ? ["Daily Report", "MOMs"] : availableFolders
        
        _documentName = State(initialValue: document.documentName)
        _selectedFolder = State(initialValue: document.folderType)
        _selectedFileName = State(initialValue: document.fileName)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack(spacing: 12) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                            Text("Edit Document")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 8)
                        
                        // Name of document
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name of document *")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("e.g. Project Requirements", text: $documentName)
                                .font(.system(size: 14))
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Folder Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Folder Name *")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            ZStack {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showFolderDropdown.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text(selectedFolder.isEmpty ? "Select a folder" : selectedFolder)
                                            .font(.system(size: 14))
                                            .foregroundColor(selectedFolder.isEmpty ? .gray : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(12)
                                    .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                // Dropdown Menu
                                if showFolderDropdown {
                                    VStack(spacing: 1) {
                                        ForEach(Array(availableFolders.enumerated()), id: \.element) { index, folder in
                                            Button(action: {
                                                selectedFolder = folder
                                                withAnimation {
                                                    showFolderDropdown = false
                                                }
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: selectedFolder == folder ? "checkmark" : "")
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .frame(width: 20)
                                                    Text(folder)
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 14)
                                                .background(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.25))
                                            }
                                        }
                                    }
                                    .background(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.25))
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)
                                    .offset(y: 52)
                                    .zIndex(1000)
                                }
                            }
                        }
                        .zIndex(showFolderDropdown ? 1000 : 0)
                        
                        // Upload document (Optional update)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Text("Update document (Optional)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                            }
                            
                            Button(action: {
                                showFilePicker = true
                            }) {
                                HStack {
                                    Text("Choose New File")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(selectedFileURL != nil ? selectedFileName : "Keep: " + selectedFileName)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                                .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                }
            }
            .background(colorScheme == .dark ? Color.black : Color(white: 0.98))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Updating..." : "Update") {
                        updateDocument()
                    }
                    .disabled(documentName.isEmpty || selectedFolder.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(selectedFileURL: $selectedFileURL, selectedFileName: $selectedFileName)
            }
        }
    }
    
    private func updateDocument() {
        isSaving = true
        let db = Firestore.firestore()
        
        var data: [String: Any] = [
            "documentName": documentName,
            "title": documentName,
            "folderName": selectedFolder,
            "folderType": selectedFolder
        ]
        
        var changes: [String] = []
        if documentName != document.documentName { changes.append("Renamed document") }
        if selectedFolder != document.folderType { changes.append("Changed folder") }
        
        if let fileURL = selectedFileURL {
            data["fileURL"] = fileURL.absoluteString
            data["fileName"] = selectedFileName
            if selectedFileName != document.fileName { changes.append("Updated file") }
        }
        
        // Robust update logic: Check sub-collection first, then fallback to root
        let subCollectionRef = db.collection("documents").document(projectId).collection(document.folderType)
        let docInSub = subCollectionRef.document(document.id)
        
        // We need to act based on where it ACTUALLY is
        docInSub.getDocument { snapshot, error in
            if let snapshot = snapshot, snapshot.exists {
                // It IS in the sub-collection
                docInSub.updateData(data) { error in
                    self.handleCompletion(error: error, changes: changes, folderName: self.document.folderType)
                }
            } else {
                // Not found in sub-collection, try Root (Legacy)
                let rootDoc = db.collection("documents").document(document.id)
                rootDoc.updateData(data) { error in
                     // For legacy, pass "documents" so logging knows to use root logic
                    self.handleCompletion(error: error, changes: changes, folderName: "documents")
                }
            }
        }
    }
    
    private func handleCompletion(error: Error?, changes: [String], folderName: String) {
        isSaving = false
        if let error = error {
            print("Error updating document: \(error.localizedDescription)")
        } else {
            let currentUser = FirebaseAuthService.shared.currentUser?.name ?? "Unknown User"
            if !changes.isEmpty {
                FirebaseService.shared.logDocumentActivity(
                    projectId: projectId,
                    folderName: folderName,
                    documentId: document.id,
                    description: changes.joined(separator: ", "),
                    user: currentUser
                )
            }
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Detail & Info Views

struct KnowledgeDetailView: View {
    let item: AdminKnowledgeItem
    let onBack: () -> Void
    @State private var showInfoModal = false
    @State private var activities: [FirebaseService.KnowledgeActivity] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.gray)
                }
                
                Text("/")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                Spacer()
                
                // Info / Eye Button
                Button(action: { showInfoModal = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20)) // Attractive size
                        .foregroundColor(.purple)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.1)),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Title Banner
                    VStack(spacing: 8) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95)) // Custom purple
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
                    
                    // Description Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(item.description)
                            .font(.body)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
                    
                    // Documents Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Documents")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let name = item.attachmentName, !name.isEmpty {
                            if let urlStr = item.attachmentURL, let url = URL(string: urlStr) {
                                Link(destination: url) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.title2)
                                            .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            Text("Tap to view")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .cornerRadius(12)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.3))
                                Text("No documents attached to this knowledge")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
                    
                    // Links Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Links")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let links = item.links, !links.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(links, id: \.self) { linkStr in
                                    if let url = URL(string: linkStr) {
                                        Link(destination: url) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "link.circle.fill")
                                                    .font(.title2)
                                                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                                                
                                                Text(linkStr)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "arrow.up.right")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                            .background(Color(.tertiarySystemGroupedBackground))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "link")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.3))
                                Text("No links attached")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
                    
                    // Activity Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !activities.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(activities) { activity in
                                    KnowledgeActivityRow(activity: activity)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.3))
                                Text("No activity recorded yet")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            FirebaseService.shared.fetchKnowledgeActivities(knowledgeId: item.id) { fetched in
                self.activities = fetched
            }
        }
        .fullScreenCover(isPresented: $showInfoModal) {
            KnowledgeInfoModal(item: item, isPresented: $showInfoModal)
        }
    }
}

struct KnowledgeInfoModal: View {
    let item: AdminKnowledgeItem
    @Binding var isPresented: Bool
    @State private var activities: [FirebaseService.KnowledgeActivity] = []
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4) // Dim background
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 24) {
                // Avatar & Name
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.85, blue: 1.0)) // Light purple
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                        )
                    
                    Text("Super Adminnn")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Creator") 
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                // Details List
                VStack(spacing: 16) {
                    KnowledgeInfoRow(label: "Created On", value: item.createdAt.formatted(date: .long, time: .omitted))
                    Divider()
                    KnowledgeInfoRow(label: "Updated On", value: item.updatedAt.formatted(date: .long, time: .omitted))
                    Divider()
                    KnowledgeInfoRow(label: "Updated By", value: "Super Adminnn")
                    Divider()
                    KnowledgeInfoRow(label: "Total Documents", value: item.attachmentName != nil ? "1" : "0")
                    Divider()
                    KnowledgeInfoRow(label: "Admin Access", value: "\(item.allowedUserIds?.count ?? 0) admin(s)")
                    
                    Divider()
                    
                    Text("Activity Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            if activities.isEmpty {
                                Text("No activities.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(activities) { activity in
                                    KnowledgeActivityRow(activity: activity, isSmall: true)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
                
                Spacer()
            }
            .overlay(
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .padding(),
                alignment: .topTrailing
            )
            .padding(24)
            .frame(width: 340, height: 600)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(radius: 20)
        }
        .background(ClearBackground())
        .onAppear {
            FirebaseService.shared.fetchKnowledgeActivities(knowledgeId: item.id) { fetched in
                self.activities = fetched
            }
        }
    }
}



struct KnowledgeInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct DocumentDetailSheet: View {
    let document: ProjectDocument
    let projectId: String
    @State private var activities: [FirebaseService.KnowledgeActivity] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    presentationMode.wrappedValue.dismiss()
                }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Details")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Icon & Title
                        VStack(spacing: 16) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.95))
                                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            VStack(spacing: 4) {
                                Text(document.documentName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text(document.fileName)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 20)
                        
                        Divider()
                        
                        // Info Grid
                        VStack(spacing: 16) {
                            InfoRow(icon: "folder", label: "Folder", value: document.folderType, iconColor: .orange)
                            InfoRow(icon: "person", label: "Uploaded by", value: document.uploadedBy, iconColor: .blue)
                            InfoRow(icon: "calendar", label: "Date", value: document.uploadedAt.formatted(date: .long, time: .shortened), iconColor: .green)
                            if let ids = document.allowedUserIds {
                                InfoRow(icon: "lock.shield", label: "Access", value: "\(ids.count) Users", iconColor: .red)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Action Button
                        if let url = URL(string: document.fileURL) {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "eye.fill")
                                    Text("View File")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider()
                        
                        // Activity Log
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Activity")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if activities.isEmpty {
                                Text("No activity recorded")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            } else {
                                ForEach(activities) { activity in
                                    KnowledgeActivityRow(activity: activity, isSmall: true)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: 350, height: 650)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(radius: 20)
        }
        .background(ClearBackground())
        .onAppear {
            fetchActivities()
        }
    }
    
    private func fetchActivities() {
        FirebaseService.shared.fetchDocumentActivities(projectId: projectId, folderName: document.folderType, documentId: document.id) { fetched in
            self.activities = fetched
        }
    }
}

struct KnowledgeActivityRow: View {
    let activity: FirebaseService.KnowledgeActivity
    var isSmall: Bool = false
    
    private var iconName: String {
        let d = activity.description.lowercased()
        if d.contains("created") { return "sparkles" }
        if d.contains("title") { return "pencil.line" }
        if d.contains("description") { return "text.alignleft" }
        if d.contains("document") { return "doc.paperclip" }
        if d.contains("link") { return "link" }
        if d.contains("access") || d.contains("granted") || d.contains("revoked") || d.contains("reassigned") { return "person.2.badge.gearshape.fill" }
        return "pencil.and.list.clipboard"
    }
    
    private var iconColor: Color {
        let d = activity.description.lowercased()
        if d.contains("created") { return .green }
        if d.contains("title") { return .blue }
        if d.contains("description") { return .purple }
        if d.contains("document") { return .orange }
        if d.contains("access") || d.contains("granted") || d.contains("revoked") { return .red }
        return .gray
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: isSmall ? 8 : 12) {
            Circle()
                .fill(iconColor.opacity(0.1))
                .frame(width: isSmall ? 24 : 32, height: isSmall ? 24 : 32)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: isSmall ? 10 : 14))
                        .foregroundColor(iconColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.description)
                    .font(isSmall ? .caption : .subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    Text(activity.performedBy)
                        .font(isSmall ? .caption2 : .caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("•")
                        .font(isSmall ? .caption2 : .caption)
                        .foregroundColor(.gray)
                    Text(activity.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(isSmall ? .caption2 : .caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(isSmall ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSmall ? Color.clear : Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}
