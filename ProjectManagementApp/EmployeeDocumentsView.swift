import SwiftUI
import SafariServices
import UIKit
import UniformTypeIdentifiers
import FirebaseFirestore

struct EmployeeDocumentsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedTab: KnowledgeTab = .knowledge
    @State private var sortOption: KnowledgeSortOption = .newest
    @State private var showAddKnowledgeForm: Bool = false
    @State private var knowledgeTitle: String = ""
    @State private var knowledgeDescription: String = ""
    @StateObject private var speechHelper = SpeechRecognizerHelper()
    @State private var activeSpeechField: KnowledgeSpeechField?
    @State private var knowledgeItems: [KnowledgeItem] = []
    @State private var editingKnowledgeIndex: Int? = nil
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var currentPage: Int = 1
    @State private var rowsPerPage: Int = 10
    @State private var knowledgeAttachmentFileURL: URL? = nil
    @State private var knowledgeAttachmentFileName: String = "Choose File (optional)"
    @State private var isPickingKnowledgeFile: Bool = false
    @State private var knowledgeLink: String = ""

    @State private var selectedKnowledgeItem: KnowledgeItem? = nil
    @State private var previousUid: String? = nil
    var isManagerPanel: Bool = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    // Internal struct for Document display
    private struct DocumentItem: Identifiable {
        let id: String
        let projectId: String?
        let srNo: Int
        let projectName: String
        let clientName: String
        let projectManager: String
        let progress: Double
        let startDate: String
        let endDate: String
    }

    private var knowledgeAllowedContentTypes: [UTType] {
        let docType = UTType(filenameExtension: "doc") ?? .data
        let docxType = UTType(filenameExtension: "docx") ?? .data
        let xlsType = UTType(filenameExtension: "xls") ?? .data
        let xlsxType = UTType(filenameExtension: "xlsx") ?? .data
        let pptType = UTType(filenameExtension: "ppt") ?? .data
        let pptxType = UTType(filenameExtension: "pptx") ?? .data

        return [
            .pdf, .png, .jpeg, .heic, .text, .plainText,
            .rtf, .spreadsheet, .presentation, .zip, .data,
            docType, docxType, xlsType, xlsxType, pptType, pptxType
        ]
    }

    private var documents: [DocumentItem] {
        let projects = firebaseService.projects
        return projects.enumerated().map { index, project in
            let progressValue = normalizedProgress(project.progress)
            let clientName = project.clientName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let managerName = project.projectManager?.trimmingCharacters(in: .whitespacesAndNewlines)
            return DocumentItem(
                id: project.documentId ?? "p-\(project.name)",
                projectId: project.documentId,
                srNo: index + 1,
                projectName: project.name,
                clientName: (clientName?.isEmpty == false ? clientName! : "-"),
                projectManager: (managerName?.isEmpty == false ? managerName! : "-"),
                progress: progressValue,
                startDate: dateFormatter.string(from: project.startDate),
                endDate: dateFormatter.string(from: project.endDate)
            )
        }
    }

    private var filteredDocuments: [DocumentItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [DocumentItem]
        if query.isEmpty {
            base = documents
        } else {
            base = documents.filter {
                $0.projectName.localizedCaseInsensitiveContains(query) ||   
                $0.clientName.localizedCaseInsensitiveContains(query) ||
                $0.projectManager.localizedCaseInsensitiveContains(query)
            }
        }

        switch sortOption {
        case .newest, .recentlyUpdated:
            return base.sorted { $0.srNo > $1.srNo }
        case .oldest, .leastRecentlyUpdated:
            return base.sorted { $0.srNo < $1.srNo }
        case .titleAZ:
            return base.sorted { lhs, rhs in
                lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
            }
        case .titleZA:
            return base.sorted { lhs, rhs in
                lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedDescending
            }
        }
    }

    private var currentEmployeeDisplayName: String {
        if let user = authService.currentUser {
            let trimmedName = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty { return trimmedName }
            let trimmedEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedEmail.isEmpty { return trimmedEmail }
        }
        return "-"
    }

    private var totalPages: Int {
        let count = filteredDocuments.count
        guard count > 0 else { return 1 }
        return (count + rowsPerPage - 1) / rowsPerPage
    }

    private var paginatedDocuments: [DocumentItem] {
        let startIndex = (currentPage - 1) * rowsPerPage
        let endIndex = min(startIndex + rowsPerPage, filteredDocuments.count)
        if startIndex >= endIndex || startIndex < 0 {
            return []
        }
        return Array(filteredDocuments[startIndex..<endIndex])
    }

    private var filteredKnowledgeItems: [KnowledgeItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var base = knowledgeItems
        if !query.isEmpty {
            base = base.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.description.localizedCaseInsensitiveContains(query)
            }
        }

        switch sortOption {
        case .newest:
            return base.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return base.sorted { $0.createdAt < $1.createdAt }
        case .recentlyUpdated:
            return base.sorted { $0.updatedAt > $1.updatedAt }
        case .leastRecentlyUpdated:
            return base.sorted { $0.updatedAt < $1.updatedAt }
        case .titleAZ:
            return base.sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        case .titleZA:
            return base.sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        tabsSection
                        if selectedTab == .knowledge {
                            searchSection
                            knowledgeListSection
                        } else {
                            documentsTableSection
                        }
                    }
                    .padding()
                }

                if showAddKnowledgeForm {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()

                    VStack {
                        Spacer()
                        addKnowledgeForm
                        Spacer()
                    }
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle("Knowledge Management")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
            .onAppear {
                let uid = authService.currentUid
                previousUid = uid
                let email = authService.currentUser?.email
                let name = authService.currentUser?.name
                let role = authService.currentUser?.role
                let isAdmin = role == .admin || role == .superAdmin || isManagerPanel
                
                firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email, userName: name)
                firebaseService.fetchEmployees()
                firebaseService.listenKnowledge(forUserUid: uid, userEmail: email, isAdmin: isAdmin)
            }
            .onReceive(authService.$currentUser) { _ in
                let uid = authService.currentUid
                
                // Prevent duplicate fetches if UID hasn't changed
                guard uid != previousUid else { return }
                previousUid = uid
                
                let email = authService.currentUser?.email
                let name = authService.currentUser?.name
                let role = authService.currentUser?.role
                let isAdmin = role == .admin || role == .superAdmin || isManagerPanel
                
                firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email, userName: name)
                firebaseService.listenKnowledge(forUserUid: uid, userEmail: email, isAdmin: isAdmin)
            }
            .onReceive(firebaseService.$knowledgeItems) { items in
                knowledgeItems = items
            }
            .sheet(item: $selectedKnowledgeItem) { item in
                KnowledgeDetailSheet(item: item)
            }
            .fileImporter(
                isPresented: $isPickingKnowledgeFile,
                allowedContentTypes: knowledgeAllowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        knowledgeAttachmentFileURL = url
                        knowledgeAttachmentFileName = url.lastPathComponent
                    }
                case .failure(let error):
                    print("Error selecting attachment: \(error.localizedDescription)")
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome, \(currentEmployeeDisplayName)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text("Manage your knowledge base and project documentation")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var tabsSection: some View {
        HStack(spacing: 0) {
            ForEach(KnowledgeTab.allCases) { tab in
                Button(action: {
                    withAnimation { selectedTab = tab }
                }) {
                    Text(tab.rawValue)
                        .font(.custom("Inter-Medium", size: 14))
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            selectedTab == tab ?
                            Capsule().fill(Color.purple) :
                            Capsule().fill(Color.gray.opacity(0.1))
                        )
                }
            }
        }
    }

    private var searchSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search knowledge...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Menu {
                Picker("Sort", selection: $sortOption) {
                    ForEach(KnowledgeSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(.purple)
            }

            Button(action: {
                editingKnowledgeIndex = nil
                knowledgeTitle = ""
                knowledgeDescription = ""
                knowledgeAttachmentFileName = "Choose File (optional)"
                knowledgeAttachmentFileURL = nil
                withAnimation { showAddKnowledgeForm = true }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
        }
    }

    private var knowledgeListSection: some View {
        VStack(spacing: 16) {
            if filteredKnowledgeItems.isEmpty {
                 Text("No knowledge items found.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(filteredKnowledgeItems) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.title)
                                .font(.headline)
                                .fontWeight(.medium)
                            Spacer()
                            if let name = item.attachmentName {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperclip")
                                    Text(name).lineLimit(1)
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        Text(item.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            Text(dateFormatter.string(from: item.createdAt))
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Button(action: {
                                selectedKnowledgeItem = item
                            }) {
                                Text("View")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                            }
                            
                            // Edit/Delete for Creator logic (implied or allowed)
                            // Assuming manager has rights or creator
                            if isManagerPanel || item.id.isEmpty == false /* Simplified check */ {
                                Menu {
                                    Button(role: .destructive) {
                                        firebaseService.deleteKnowledge(documentId: item.id) { _ in }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        // Edit
                                        if let idx = knowledgeItems.firstIndex(where: { $0.id == item.id }) {
                                            editingKnowledgeIndex = idx
                                            knowledgeTitle = item.title
                                            knowledgeDescription = item.description
                                            knowledgeLink = item.link ?? ""
                                            knowledgeAttachmentFileName = item.attachmentName ?? "Choose File (optional)"
                                            withAnimation { showAddKnowledgeForm = true }
                                        }
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.gray)
                                        .padding(8)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    private var addKnowledgeForm: some View {
        VStack(spacing: 20) {
            HStack {
                Text(editingKnowledgeIndex == nil ? "Add Knowledge" : "Edit Knowledge")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(action: closeForm) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Title *").font(.caption).foregroundColor(.gray)
                HStack {
                    TextField("Title", text: $knowledgeTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: { toggleSpeech(for: .title) }) {
                        Image(systemName: speechIcon(for: .title))
                            .foregroundColor(.purple)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description *").font(.caption).foregroundColor(.gray)
                HStack(alignment: .top) {
                    TextEditor(text: $knowledgeDescription)
                        .frame(height: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    Button(action: { toggleSpeech(for: .description) }) {
                        Image(systemName: speechIcon(for: .description))
                            .foregroundColor(.purple)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Links *").font(.caption).foregroundColor(.gray)
                TextField("https://linkname.com", text: $knowledgeLink)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                if !knowledgeLink.isEmpty && !knowledgeLink.hasPrefix("https://") {
                    Text("Link must start with https://")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Attachment").font(.caption).foregroundColor(.gray)
                Button(action: { isPickingKnowledgeFile = true }) {
                    HStack {
                        Text(knowledgeAttachmentFileName)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "paperclip")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Button(action: handleAddKnowledge) {
                Text(editingKnowledgeIndex == nil ? "Submit" : "Update")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmitKnowledge ? Color.purple : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!canSubmitKnowledge)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
    }

    private var documentsTableSection: some View {
        VStack(alignment: .leading) {
            
            // Search Bar for Documents
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search documents...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.bottom, 10)
            
            // Pagination
            HStack {
                Spacer()
                Button(action: { if currentPage > 1 { currentPage -= 1 } }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPage <= 1)
                
                Text("\(currentPage) / \(totalPages)")
                    .font(.caption)
                
                Button(action: { if currentPage < totalPages { currentPage += 1 } }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage >= totalPages)
            }
            .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 16) {
                        Text("#").frame(width: 40, alignment: .leading)
                        Text("Project").frame(width: 150, alignment: .leading)
                        Text("Client").frame(width: 120, alignment: .leading)
                        Text("Manager").frame(width: 120, alignment: .leading)
                        Text("Progress").frame(width: 80, alignment: .leading)
                        Text("Start Date").frame(width: 100, alignment: .leading)
                        Text("End Date").frame(width: 100, alignment: .leading)
                        Text("Action").frame(width: 80, alignment: .leading)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // Rows
                    ForEach(paginatedDocuments) { doc in
                        HStack(spacing: 16) {
                            Text("\(doc.srNo)").frame(width: 40, alignment: .leading)
                            Text(doc.projectName).frame(width: 150, alignment: .leading).lineLimit(1)
                            Text(doc.clientName).frame(width: 120, alignment: .leading).lineLimit(1)
                            Text(doc.projectManager).frame(width: 120, alignment: .leading).lineLimit(1)
                            
                            HStack(spacing: 4) {
                                Text("\(Int(doc.progress * 100))%")
                                Circle()
                                    .trim(from: 0, to: CGFloat(doc.progress))
                                    .stroke(Color.green, lineWidth: 2)
                                    .frame(width: 12, height: 12)
                            }
                            .frame(width: 80, alignment: .leading)
                            
                            Text(doc.startDate).frame(width: 100, alignment: .leading)
                            Text(doc.endDate).frame(width: 100, alignment: .leading)
                            
                            // ACTION: Navigate to ProjectDocumentsView
                            NavigationLink(destination: ProjectDocumentsView(
                                projectName: doc.projectName,
                                projectId: doc.projectId,
                                isManagerPanel: isManagerPanel
                            ).id(doc.id)) {
                                Text("View")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 10)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .frame(width: 80, alignment: .leading)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 12)
                        Divider()
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func normalizedProgress(_ progress: Double) -> Double {
        if progress > 1 { return min(max(progress / 100.0, 0.0), 1.0) }
        return min(max(progress, 0.0), 1.0)
    }

    private var canSubmitKnowledge: Bool {
        let trimmedTitle = knowledgeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = knowledgeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = knowledgeLink.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !trimmedTitle.isEmpty && 
               !trimmedDescription.isEmpty && 
               !trimmedLink.isEmpty && 
               trimmedLink.hasPrefix("https://")
    }

    private func toggleSpeech(for field: KnowledgeSpeechField) {
        // Speech recognition temporarily disabled due to access level
        // TODO: Implement public speech recognition interface
    }

    private func speechIcon(for field: KnowledgeSpeechField) -> String {
        "mic"
    }

    private func closeForm() {
        withAnimation { showAddKnowledgeForm = false }
        knowledgeTitle = ""
        knowledgeDescription = ""
        knowledgeLink = ""
        editingKnowledgeIndex = nil
        knowledgeAttachmentFileURL = nil
        knowledgeAttachmentFileName = "Choose File (optional)"
        isPickingKnowledgeFile = false
    }

    private func handleAddKnowledge() {
        let title = knowledgeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = knowledgeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else { return }

        if let index = editingKnowledgeIndex {
            // Update
            let item = knowledgeItems[index]
            
            func doUpdate(url: String?) {
                firebaseService.updateKnowledge(
                    documentId: item.id,
                    title: title,
                    bodyText: body,
                    attachmentName: knowledgeAttachmentFileURL != nil ? knowledgeAttachmentFileName : nil,
                    attachmentURL: url,
                    link: knowledgeLink.trimmingCharacters(in: .whitespacesAndNewlines)
                ) { error in
                    if error == nil {
                        closeForm()
                    }
                }
            }
            
            if let fileURL = knowledgeAttachmentFileURL {
                let needsRelease = fileURL.startAccessingSecurityScopedResource()
                defer { if needsRelease { fileURL.stopAccessingSecurityScopedResource() } }
                firebaseService.uploadExpenseReceipt(fileURL: fileURL, forUserUid: authService.currentUid) { result in
                    switch result {
                    case .success(let url): doUpdate(url: url)
                    case .failure(let err): print("Upload failed: \(err)")
                    }
                }
            } else {
                doUpdate(url: nil)
            }
        } else {
            // Create
            func doCreate(url: String?) {
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                firebaseService.saveKnowledge(
                    userUid: uid,
                    userEmail: email,
                    title: title,
                    bodyText: body,
                    attachmentName: url != nil ? knowledgeAttachmentFileName : nil,
                    attachmentURL: url,
                    link: knowledgeLink.trimmingCharacters(in: .whitespacesAndNewlines)
                ) { result in
                    switch result {
                    case .success(_): closeForm()
                    case .failure(let err): print("Create failed: \(err)")
                    }
                }
            }

            if let fileURL = knowledgeAttachmentFileURL {
                let needsRelease = fileURL.startAccessingSecurityScopedResource()
                defer { if needsRelease { fileURL.stopAccessingSecurityScopedResource() } }
                firebaseService.uploadExpenseReceipt(fileURL: fileURL, forUserUid: authService.currentUid) { result in
                    switch result {
                    case .success(let url): doCreate(url: url)
                    case .failure(let err): print("Upload failed: \(err)")
                    }
                }
            } else {
                doCreate(url: nil)
            }
        }
    }
}

struct KnowledgeDetailSheet: View {
    let item: KnowledgeItem
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let attName = item.attachmentName, let attURL = item.attachmentURL, let url = URL(string: attURL) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "paperclip")
                                Text(attName)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    if let linkString = item.link, let url = URL(string: linkString) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Link")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link")
                                    Text(linkString)
                                        .lineLimit(1)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    Text(item.description)
                        .font(.body)
                        .padding(.top, 8)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Details")
            .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button("Close") { dismiss() }
                 }
            }
        }
    }
}

struct ProjectDocumentsView: View {
    let projectName: String
    let projectId: String? 
    var isManagerPanel: Bool = false 
    @State private var searchText: String = ""
    @State private var isShowingAddSheet: Bool = false
    @State private var showManageFolders: Bool = false
    @State private var documents: [ProjectDocumentRow] = []
    @State private var editingDocument: ProjectDocumentRow? = nil
    @State private var viewingURL: URL? = nil
    @State private var isShowingViewer: Bool = false
    @State private var exportURL: URL? = nil
    @State private var isShowingExportSheet: Bool = false
    @StateObject private var authService = FirebaseAuthService.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var listener: ListenerRegistration? = nil
    @State private var currentPage: Int = 1
    @State private var rowsPerPage: Int = 10

    struct ProjectDocumentRow: Identifiable {
        var id: String { documentId }
        let documentId: String
        let srNo: Int
        let name: String
        let uploadedBy: String
        let uploadedOn: String
        let fileURL: String?
    }

    private var totalPages: Int {
        max(1, (filteredDocuments.count + rowsPerPage - 1) / rowsPerPage)
    }

    private var paginatedDocuments: [ProjectDocumentRow] {
        let startIndex = (currentPage - 1) * rowsPerPage
        let endIndex = min(startIndex + rowsPerPage, filteredDocuments.count)

        if startIndex >= endIndex {
            return []
        }

        return Array(filteredDocuments[startIndex..<endIndex])
    }

    private var filteredDocuments: [ProjectDocumentRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return documents }
        return documents.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                searchAndActionsSection
                documentListSection
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle(projectName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingAddSheet) {
            AddProjectDocumentSheet(
                projectName: projectName,
                projectId: projectId,
                authService: authService,
                firebaseService: firebaseService
            )
            .interactiveDismissDisabled()
        }
        .background(
            EmptyView()
                .sheet(item: $editingDocument) { doc in
                    EditProjectDocumentSheet(document: doc) { updatedName, updatedURL in
                        if let idx = documents.firstIndex(where: { $0.documentId == doc.documentId }) {
                            let old = documents[idx]
                            documents[idx] = ProjectDocumentRow(
                                documentId: old.documentId,
                                srNo: old.srNo,
                                name: updatedName,
                                uploadedBy: old.uploadedBy,
                                uploadedOn: old.uploadedOn,
                                fileURL: updatedURL ?? old.fileURL
                            )
                        }
                        editingDocument = nil
                    }
                }
        )
        .background(
            EmptyView()
                .sheet(isPresented: $isShowingViewer, onDismiss: {
                    viewingURL = nil
                }) {
                    if let url = viewingURL {
                        DocumentWebView(url: url)
                    } else {
                        Text("Unable to load document")
                    }
                }
        )
        .background(
            EmptyView()
                .sheet(isPresented: $isShowingExportSheet, onDismiss: {
                    exportURL = nil
                }) {
                    if let url = exportURL {
                        ReportShareSheet(activityItems: [url])
                    } else {
                        Text("Preparing document...")
                    }
                }
        )
        .fullScreenCover(isPresented: $showManageFolders) {
            ManageFoldersView(projectId: projectId ?? "", isPresented: $showManageFolders)
        }
        .onAppear {
            if listener == nil {
                startListeningDocuments()
            }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private var searchAndActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search & Actions")
                .font(.headline)
                .fontWeight(.semibold)

            // Unified Layout - with search bar, Add Document, and Add Folder buttons for all users
            VStack(spacing: 12) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search by name, location or tag", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(999)
                .shadow(color: .gray.opacity(0.08), radius: 4, x: 0, y: 2)
                
                // Action Buttons Row
                HStack(spacing: 12) {

                    
                    // Add Folder Button
                    Button(action: {
                        showManageFolders = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Add Folder")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.35, green: 0.25, blue: 0.95))
                        .cornerRadius(20)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.08), radius: 5, x: 0, y: 3)
    }

    private var paginationControls: some View {
        HStack(spacing: 16) {
            HStack {
                Text("Rows per page")
                    .font(.caption)

                Picker("Rows per page", selection: $rowsPerPage) {
                    Text("10").tag(10)
                    Text("25").tag(25)
                    Text("50").tag(50)
                }
                .pickerStyle(.menu)
                .onChange(of: rowsPerPage) { _ in
                    currentPage = 1
                }
            }

            Text("\(currentPage) of \(totalPages)")
                .font(.caption)

            HStack {
                Button(action: {
                    if currentPage > 1 {
                        currentPage -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPage == 1)

                Button(action: {
                    if currentPage < totalPages {
                        currentPage += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage == totalPages)
            }
        }
        .foregroundColor(.primary)
    }

    private var documentListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Document List")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Spacer()
                paginationControls
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text("SR. NO.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 70, alignment: .leading)

                        Text("Document Name")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 180, alignment: .leading)

                        Text("Uploaded By")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 140, alignment: .leading)

                        Text("Uploaded On")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 130, alignment: .leading)

                        Text("ACTIONS")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 100, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.06))

                    Divider()

                    if filteredDocuments.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.system(size: 32))
                                .foregroundColor(.gray.opacity(0.6))

                            Text("No Projects Found")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("No projects match the selected filters. Adjust your search or try resetting filters.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(filteredDocuments) { doc in
                            HStack(spacing: 8) {
                                Text("\(doc.srNo)")
                                    .font(.subheadline)
                                    .frame(width: 70, alignment: .leading)

                                Text(doc.name)
                                    .font(.subheadline)
                                    .frame(width: 180, alignment: .leading)
                                    .lineLimit(1)

                                Text(doc.uploadedBy)
                                    .font(.subheadline)
                                    .frame(width: 140, alignment: .leading)
                                    .lineLimit(1)

                                Text(doc.uploadedOn)
                                    .font(.subheadline)
                                    .frame(width: 130, alignment: .leading)

                                HStack(spacing: 10) {
                                    Button(action: {
                                        if let urlString = doc.fileURL, let url = URL(string: urlString) {
                                            viewingURL = url
                                            isShowingViewer = true
                                        } else {
                                            print("No file URL available for viewing")
                                        }
                                    }) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .foregroundColor(.blue)
                                    }

                                    Button(action: {
                                        if let urlString = doc.fileURL, let url = URL(string: urlString) {
                                            downloadAndExport(url: url)
                                        } else {
                                            print("No file URL available for download")
                                        }
                                    }) {
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundColor(.green)
                                    }

                                    Button(action: {
                                        editingDocument = doc
                                    }) {
                                        Image(systemName: "square.and.pencil")
                                            .foregroundColor(.orange)
                                    }

                                    Button(action: {
                            // FIXED COLLECTION: documents
                                        Firestore.firestore()
                                            .collection("documents")
                                            .document(doc.documentId)
                                            .delete { error in
                                                if let error = error {
                                                    print("Error deleting document: \(error.localizedDescription)")
                                                } else {
                                                    documents.removeAll { $0.documentId == doc.documentId }
                                                }
                                            }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .font(.caption)
                                .frame(width: 100, alignment: .leading)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .frame(minWidth: 700, alignment: .leading)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.08), radius: 3, x: 0, y: 2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.08), radius: 5, x: 0, y: 3)
    }

    private func startListeningDocuments() {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        listener?.remove()
        
        var query = Firestore.firestore().collection("documents")
            .whereField("projectId", isEqualTo: projectId ?? "")
        
        if projectId == nil || projectId?.isEmpty == true {
             query = Firestore.firestore().collection("documents").whereField("projectName", isEqualTo: projectName)
        }
        
        listener = query.addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents ?? []
                let currentUserEmail = authService.currentUser?.email ?? ""
                let currentUserUid = authService.currentUid
            
                let filteredDocs = docs.filter { doc in
                    let data = doc.data()
                    
                    // Admin / Manager Always Allowed
                    let role = self.authService.currentUser?.role
                    let isAdmin = role == .admin || role == .superAdmin || self.isManagerPanel
                    if isAdmin { return true }

                    // --- Robust Creator Check ---
                    var isCreator = false
                    if let uid = currentUserUid {
                       let creatorKeys = ["userUid", "userId", "creatorId", "uploadedByUid", "ownerUid", "createdByUid", "createdById"]
                       if creatorKeys.contains(where: { (data[$0] as? String) == uid }) { isCreator = true }
                    }
                    if !isCreator { // Check Email
                       let creatorEmailKeys = ["uploadedBy", "userEmail", "creatorEmail", "uploadedByEmail"]
                       if creatorEmailKeys.contains(where: { (data[$0] as? String) == currentUserEmail }) { isCreator = true }
                    }
                    if isCreator { return true }
                    
                    // --- Robust Assignment Check ---
                    // UID Check
                    if let uid = currentUserUid {
                         // Arrays
                        let uidArrayKeys = ["allowedUserIds", "allowedUsers", "assignedUserIds", "assignedEmployees", "employeeIds", "memberIds", "assignees", "allowedIds"]
                         for key in uidArrayKeys {
                             if let arr = data[key] as? [String], arr.contains(uid) { return true }
                         }
                         // Singles
                         let uidSingleKeys = ["assignedToUid", "assignedToId", "employeeId", "targetUserId", "assignedId"]
                         for key in uidSingleKeys {
                             if let val = data[key] as? String, val == uid { return true }
                         }
                    }
                    
                    // Email Check
                    if !currentUserEmail.isEmpty {
                        // Arrays
                        let emailArrayKeys = ["allowedEmails", "allowedUserEmails", "assignedEmails", "assignedEmployeeEmails", "employeeEmails", "memberEmails", "allowedUserEmail"]
                        for key in emailArrayKeys {
                             if let arr = data[key] as? [String], arr.contains(currentUserEmail) { return true }
                        }
                        // Singles
                        let emailSingleKeys = ["assignedToEmail", "employeeEmail", "targetUserEmail", "assignedEmail"]
                        for key in emailSingleKeys {
                             if let val = data[key] as? String, val == currentUserEmail { return true }
                        }
                    }
                    
                    // Strict Mode: No global access
                    return false
                }
            
                let rows: [ProjectDocumentRow] = filteredDocs.enumerated().map { idx, doc in
                    let data = doc.data()
                    let name = (data["title"] as? String)
                        ?? (data["documentName"] as? String)
                        ?? (data["name"] as? String)
                        ?? "Untitled"
                    
                    // Resolve Uploader Name
                    let uploadedByEmail = (data["uploadedBy"] as? String) ?? (data["uploadedByEmail"] as? String) ?? ""
                    let uploadedByName = (data["uploadedByName"] as? String) ?? (data["createdByName"] as? String)
                    
                    var finalUploader = "Unknown"
                    if let name = uploadedByName, !name.isEmpty {
                        finalUploader = name
                    } else if !uploadedByEmail.isEmpty {
                        if let emp = self.firebaseService.employees.first(where: { $0.email == uploadedByEmail }) {
                            finalUploader = emp.name
                        } else {
                            finalUploader = uploadedByEmail
                        }
                    } else if let creatorUid = data["createdByUid"] as? String {
                         if let emp = self.firebaseService.employees.first(where: { $0.id == creatorUid }) {
                             finalUploader = emp.name
                         }
                    } else if let creatorUid = data["uploadedByUid"] as? String {
                         if let emp = self.firebaseService.employees.first(where: { $0.id == creatorUid }) {
                             finalUploader = emp.name
                         }
                    }
                    
                    // Fallback to Unknown if still not found
                    let uploadedBy = finalUploader == "Unknown" ? "Unknown" : finalUploader

                    let uploadedOn: String = {
                        if let ts = data["uploadedAt"] as? Timestamp {
                            return df.string(from: ts.dateValue())
                        }
                        return df.string(from: Date())
                    }()
                    
                    let fileURL = (data["fileURL"] as? String)
                        ?? (data["url"] as? String)
                        ?? (data["downloadURL"] as? String)
                        
                    let documentId = doc.documentID
                    
                    return ProjectDocumentRow(
                        documentId: documentId,
                        srNo: idx + 1,
                        name: name,
                        uploadedBy: uploadedBy,
                        uploadedOn: uploadedOn,
                        fileURL: fileURL
                    )
                }
                self.documents = rows
            }
    }
    
    private func downloadAndExport(url: URL) {
        let task = URLSession.shared.downloadTask(with: url) { tempLocalURL, response, error in
            if let error = error {
                print("Error downloading document: \(error.localizedDescription)")
                return
            }
            guard let tempLocalURL = tempLocalURL else {
                print("No temporary file URL from download task")
                return
            }

            let fileManager = FileManager.default
            let tmpDir = FileManager.default.temporaryDirectory
            let suggestedName = response?.suggestedFilename ?? url.lastPathComponent
            let fileName = suggestedName.isEmpty ? "Document.pdf" : suggestedName
            let destinationURL = tmpDir.appendingPathComponent(fileName)

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempLocalURL, to: destinationURL)
                DispatchQueue.main.async {
                    exportURL = destinationURL
                    isShowingExportSheet = true
                }
            } catch {
                print("Error preparing file for export: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
}

struct DocumentWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct AddProjectDocumentSheet: View {

    let projectName: String
    let projectId: String? 
    @ObservedObject var authService: FirebaseAuthService
    @ObservedObject var firebaseService: FirebaseService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var documentName: String = ""
    @State private var selectedFolder = ""
    @State private var selectedFileURL: URL? = nil
    @State private var selectedFileName: String = "no file selected"
    @State private var isPickingFile: Bool = false
    @State private var isSaving = false
    
    // Folder dropdown
    @State private var showFolderDropdown = false
    @State private var projectFolders: [ProjectFolder] = []
    
    // Access Control
    @State private var selectedAdminIds: Set<String> = []
    @State private var selectedMemberIds: Set<String> = []

    private var allowedContentTypes: [UTType] {
        let docType = UTType(filenameExtension: "doc") ?? .data
        let docxType = UTType(filenameExtension: "docx") ?? .data
        let xlsType = UTType(filenameExtension: "xls") ?? .data
        let xlsxType = UTType(filenameExtension: "xlsx") ?? .data
        let pptType = UTType(filenameExtension: "ppt") ?? .data
        let pptxType = UTType(filenameExtension: "pptx") ?? .data

        return [
            .pdf, .png, .jpeg, .heic, .text, .plainText,
            .rtf, .spreadsheet, .presentation, .zip, .data,
            docType, docxType, xlsType, xlsxType, pptType, pptxType
        ]
    }
    
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

    private var canSubmit: Bool {
        !documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !selectedFolder.isEmpty && 
        selectedFileURL != nil &&
        !isSaving
    }

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
                                        ForEach(Array(allFolders.enumerated()), id: \.element.id) { index, folder in
                                            Button(action: {
                                                selectedFolder = folder.name
                                                withAnimation {
                                                    showFolderDropdown = false
                                                }
                                            }) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: selectedFolder == folder.name ? "checkmark" : "")
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .frame(width: 20)
                                                    Text(folder.name)
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 14)
                                                .background(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.25))
                                                .cornerRadius(index == 0 ? 10 : 0, corners: index == 0 ? [.topLeft, .topRight] : [])
                                                .cornerRadius(index == allFolders.count - 1 ? 10 : 0, corners: index == allFolders.count - 1 ? [.bottomLeft, .bottomRight] : [])
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
                        .padding(.bottom, showFolderDropdown ? CGFloat(allFolders.count * 50) : 0)
                        
                        // Access Control Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.4))
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
                                isPickingFile = true
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
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveDocument()
                    }
                    .disabled(!canSubmit)
                }
            }
            .fileImporter(
                isPresented: $isPickingFile,
                allowedContentTypes: allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedFileURL = url
                        selectedFileName = url.lastPathComponent
                    }
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
            .onAppear {
                fetchProjectFolders()
            }
        }
    }
    
    private func fetchProjectFolders() {
        guard let projectId = projectId else { return }
        let db = Firestore.firestore()
        
        // Fetch Global/Default Folders
        db.collection("documents").document("folders")
            .getDocument { snapshot, error in
                var globalFolders: [ProjectFolder] = []
                if let data = snapshot?.data(),
                   let foldersArray = data["folders"] as? [[String: Any]] {
                    globalFolders = foldersArray.compactMap { dict -> ProjectFolder? in
                        let name = dict["name"] as? String ?? ""
                        let color = dict["color"] as? String ?? "#000000"
                        return ProjectFolder(id: "global_\(name)", name: name, colorHex: color, createdAt: nil)
                    }
                }
                
                // Fetch Project Specific Folders
                db.collection("projects").document(projectId)
                    .getDocument { projectSnapshot, projectError in
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
    
    private func saveDocument() {
        guard !documentName.isEmpty, !selectedFolder.isEmpty, let fileURL = selectedFileURL else { return }
        
        isSaving = true
        
        // Resolve selected IDs to Emails
        let allEmployees = firebaseService.employees
        let selectedEmployees = allEmployees.filter { 
            selectedAdminIds.contains($0.id) || selectedMemberIds.contains($0.id) 
        }
        let allowedUserIds = Array(selectedAdminIds.union(selectedMemberIds))
        let allowedEmails = selectedEmployees.map { $0.email }
        
        let currentUserEmail = authService.currentUser?.email ?? "Unknown"
        
        // Upload file first
        let needsRelease = fileURL.startAccessingSecurityScopedResource()
        defer { if needsRelease { fileURL.stopAccessingSecurityScopedResource() } }
        
        firebaseService.uploadExpenseReceipt(fileURL: fileURL, forUserUid: authService.currentUid) { result in
            switch result {
            case .success(let downloadURL):
                // Create document data
                let documentData: [String: Any] = [
                    "documentName": documentName,
                    "title": documentName,
                    "folderName": selectedFolder,
                    "folderType": selectedFolder,
                    "projectId": projectId ?? "",
                    "projectName": projectName,
                    "uploadedBy": currentUserEmail,
                    "uploadedByName": authService.currentUser?.name ?? "Unknown",
                    "uploadedAt": Timestamp(date: Date()),
                    "fileName": selectedFileName,
                    "fileURL": downloadURL,
                    "allowedUserIds": allowedUserIds,
                    "allowedEmails": allowedEmails
                ]
                
                // Save to Firebase
                let db = Firestore.firestore()
                db.collection("documents").addDocument(data: documentData) { error in
                    isSaving = false
                    if let error = error {
                        print("❌ Error saving document: \(error.localizedDescription)")
                    } else {
                        print("✅ Document saved successfully!")
                        dismiss()
                    }
                }
                
            case .failure(let error):
                isSaving = false
                print("Error uploading document: \(error.localizedDescription)")
            }
        }
    }
}

struct EditProjectDocumentSheet: View {

    let document: ProjectDocumentsView.ProjectDocumentRow
    var onSaved: ((_ updatedName: String, _ updatedURL: String?) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var documentName: String
    @State private var selectedFileURL: URL? = nil
    @State private var selectedFileName: String = "Choose File (optional)"
    @State private var isPickingFile: Bool = false
    @ObservedObject private var authService = FirebaseAuthService.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var isSaving: Bool = false
    @State private var saveSucceeded: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    init(document: ProjectDocumentsView.ProjectDocumentRow, onSaved: ((_ updatedName: String, _ updatedURL: String?) -> Void)? = nil) {
        self.document = document
        self.onSaved = onSaved
        _documentName = State(initialValue: document.name)
        _selectedFileName = State(initialValue: "Choose File (optional)")
    }

    private var canSubmit: Bool {
        !documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var allowedContentTypes: [UTType] {
        let docType = UTType(filenameExtension: "doc") ?? .data
        let docxType = UTType(filenameExtension: "docx") ?? .data
        let xlsType = UTType(filenameExtension: "xls") ?? .data
        let xlsxType = UTType(filenameExtension: "xlsx") ?? .data
        let pptType = UTType(filenameExtension: "ppt") ?? .data
        let pptxType = UTType(filenameExtension: "pptx") ?? .data

        return [
            .pdf, .png, .jpeg, .heic, .text, .plainText,
            .rtf, .spreadsheet, .presentation, .zip, .data,
            docType, docxType, xlsType, xlsxType, pptType, pptxType
        ]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Edit Document")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 10, height: 10)
                            )
                        Text("Document Details")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name of document *")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("e.g. Project Requirements", text: $documentName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Upload document (optional)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button(action: { isPickingFile = true }) {
                            HStack {
                                Text(selectedFileName)
                                    .font(.subheadline)
                                    .foregroundColor(selectedFileURL == nil ? .gray : .primary)
                                Spacer()
                                Image(systemName: "paperclip")
                                    .foregroundColor(.purple)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)

                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        guard !isSaving else { return }
                        let trimmed = documentName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { isSaving = false; return }
                        isSaving = true
                        saveSucceeded = false

                        func performUpdate(with downloadURL: String?) {
                            func doUpdate() {
                                var update: [String: Any] = [
                                    "name": trimmed,
                                    "updatedAt": Timestamp(date: Date())
                                ]
                                if let url = downloadURL { update["fileURL"] = url }
                        // FIXED COLLECTION: documents
                                Firestore.firestore()
                                    .collection("documents")
                                    .document(document.documentId)
                                    .updateData(update) { error in
                                        if let error = error {
                                            isSaving = false
                                            errorMessage = error.localizedDescription
                                            showError = true
                                        } else {
                                            isSaving = false
                                            saveSucceeded = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                saveSucceeded = false
                                                onSaved?(trimmed, downloadURL)
                                            }
                                        }
                                    }
                            }
                            doUpdate()
                        }

                        if let fileURL = selectedFileURL {
                            let needsRelease = fileURL.startAccessingSecurityScopedResource()
                            defer { if needsRelease { fileURL.stopAccessingSecurityScopedResource() } }
                            firebaseService.uploadExpenseReceipt(fileURL: fileURL, forUserUid: authService.currentUid) { result in
                                switch result {
                                case .success(let newURL):
                                    performUpdate(with: newURL)
                                case .failure(let error):
                                    errorMessage = error.localizedDescription
                                    showError = true
                                    isSaving = false
                                }
                            }
                        } else {
                            performUpdate(with: nil)
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isSaving { ProgressView().scaleEffect(0.8) }
                            Text(saveSucceeded ? "Saved" : "Save")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background((canSubmit && !isSaving) ? Color.purple : Color.gray.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .disabled(!canSubmit || isSaving)
                }
                .font(.subheadline)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .padding(.horizontal, 24)
        }
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFileURL = url
                    selectedFileName = url.lastPathComponent
                }
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                showError = false
            }
        } message: {
            Text(errorMessage.isEmpty ? "Something went wrong. Please try again." : errorMessage)
        }
    }
}

enum KnowledgeSpeechField {
    case title
    case description
}

enum KnowledgeSortOption: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case recentlyUpdated = "Recently Updated"
    case leastRecentlyUpdated = "Least Recently Updated"
    case titleAZ = "Title A→Z"
    case titleZA = "Title Z→A"

    var id: String { rawValue }
}
 
