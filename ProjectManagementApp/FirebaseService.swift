import Foundation
import Combine
import UIKit
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

struct ProjectLevelItem: Identifiable, Codable, Hashable {
    var id: String
    var level: String
    var name: String
}

struct HierarchyRole: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var role: String
}

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var hierarchyRoles: [HierarchyRole] = []
    
    @Published var projects: [Project] = []
    @Published var tasks: [Task] = []
    @Published var events: [Meeting] = []
    @Published var clients: [Client] = []
    @Published var leads: [Lead] = []
    @Published var leadProducts: [String] = []
    @Published var leadSectors: [String] = []
    @Published var leadSources: [String] = []
    @Published var leadCategories: [String] = []
    @Published var leadPriorities: [String] = []
    @Published var employees: [EmployeeProfile] = []
    @Published var dailyReports: [EmployeeDailyReport] = []
    @Published var reminders: [SavedReminder] = []
    @Published var notes: [SavedNote] = []
    @Published var knowledgeItems: [KnowledgeItem] = []
    @Published var adminKnowledgeItems: [AdminKnowledgeItem] = []
    
    struct KnowledgeActivity: Identifiable, Codable {
        var id: String
        var description: String
        var performedBy: String
        var timestamp: Date
    }
    
    @Published var taskStatusOptions: [String] = [
        "All",
        "Today's Task",
        "TODO",
        "In Progress",
        "Stuck",
        "Waiting For",
        "Hold by Client",
        "Need Help",
        "Done",
        "Recurring Task"
    ]
    @Published var taskPriorityOptions: [String] = [
        "All Priorities",
        "High",
        "Medium",
        "Low"
    ]
    @Published var taskStatusColors: [String: String] = [:]
    @Published var taskRawStatusByKey: [String: String] = [:]
    @Published var projectLevels: [ProjectLevelItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var archivedTasks: [Task] = []
    @Published var expenses: [Expense] = []
    
    private init() {
        fetchArchivedTasks()
    }
    
    // MARK: - Fetch Projects
    func fetchProjects() {
        isLoading = true
        errorMessage = nil
        
        db.collection("projects").addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching projects: \(error.localizedDescription)"
                    return
                }
                guard let documents = querySnapshot?.documents else { return }
                
                print("📁 fetchProjects -> total docs from Firestore: \(documents.count)")
                
                self.projects = documents.compactMap { document -> Project? in
                    let data = document.data()
                    let documentId = document.documentID
                    
                    let name = data["name"] as? String
                    ?? data["projectName"] as? String
                    ?? data["title"] as? String
                    ?? data["clientName"] as? String
                    ?? "Project \(documentId.prefix(8))"
                    
                    let description = data["description"] as? String
                    ?? data["goals"] as? String
                    ?? data["objective"] as? String
                    ?? "No description available"
                    
                    let progress = data["progress"] as? Double ?? 0.0
                    let assignedEmployees = (data["assignedEmployees"] as? [String])
                    ?? (data["assigneeNames"] as? [String])
                    ?? []
                    let projectManager = data["projectManagerName"] as? String
                    ?? data["projectManager"] as? String
                    let clientName = (data["clientName"] as? String)
                    ?? (data["ClientName"] as? String)
                    ?? (data["cLientName"] as? String)
                    ?? (data["customerName"] as? String)
                    
                    let startDate: Date
                    if let ts = data["startDate"] as? Timestamp {
                        startDate = ts.dateValue()
                    } else if let ts = data["createdAt"] as? Timestamp {
                        startDate = ts.dateValue()
                    } else {
                        startDate = Date()
                    }
                    
                    let endDate: Date
                    if let ts = data["endDate"] as? Timestamp {
                        endDate = ts.dateValue()
                    } else if let ts = data["deadline"] as? Timestamp {
                        endDate = ts.dateValue()
                    } else {
                        endDate = Date().addingTimeInterval(86400 * 30)
                    }
                    
                    let departmentName = data["department"] as? String
                    let department = Department.sampleDepartments.first { $0.name == departmentName }
                    
                    var objectives: [Objective] = []
                    if let okrsData = data["okrs"] as? [[String: Any]] ?? data["objectives"] as? [[String: Any]] {
                        objectives = okrsData.compactMap { obj -> Objective? in
                            guard let title = obj["title"] as? String ?? obj["objective"] as? String else { return nil }
                            var keyResults: [KeyResult] = []
                            if let keyResultsData = obj["keyResults"] as? [[String: Any]] {
                                keyResults = keyResultsData.compactMap { kr in
                                    guard let desc = kr["description"] as? String else { return nil }
                                    return KeyResult(description: desc)
                                }
                            } else if let keyResultsArray = obj["keyResults"] as? [String] {
                                keyResults = keyResultsArray.map { KeyResult(description: $0) }
                            }
                            return Objective(title: title, keyResults: keyResults)
                        }
                    }
                    
                    return Project(
                        documentId: documentId,
                        name: name,
                        description: description,
                        progress: progress,
                        startDate: startDate,
                        endDate: endDate,
                        tasks: [],
                        assignedEmployees: assignedEmployees,
                        department: department,
                        objectives: objectives,
                        projectManager: projectManager,
                        clientName: clientName
                    )
                }
            }
        }
    }
    
    // MARK: - Fetch Project Name
    func fetchProjectName(projectId: String, completion: @escaping (String?) -> Void) {
        db.collection("projects").document(projectId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                let name = data["projectName"] as? String
                ?? data["name"] as? String
                ?? data["title"] as? String
                DispatchQueue.main.async { completion(name) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    func createProject(
        name: String,
        clientName: String?,
        clientId: String? = nil,
        projectManager: String?,
        projectManagerId: String? = nil,
        assignedEmployees: [String],
        assigneeIds: [String] = [],
        startDate: Date,
        endDate: Date,
        objectives: [Objective],
        completion: ((Error?) -> Void)? = nil
    ) {
        var data: [String: Any] = [
            "name": name,
            "projectName": name,
            "progress": 0.0,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "assignedEmployees": assignedEmployees,
            "assigneeNames": assignedEmployees,
            "assigneeIds": assigneeIds,
            "createdAt": Timestamp(date: Date()),
            "pipelineStage": "Diagnose",
            "pipelineSubstages": [:] as [String: Any]
        ]
        
        if let client = clientName?.trimmingCharacters(in: .whitespacesAndNewlines), !client.isEmpty {
            data["clientName"] = client
        }
        if let cid = clientId {
            data["clientId"] = cid
        }
        
        if let manager = projectManager?.trimmingCharacters(in: .whitespacesAndNewlines), !manager.isEmpty {
            data["projectManager"] = manager
            data["projectManagerName"] = manager
        }
        if let pmid = projectManagerId {
            data["projectManagerId"] = pmid
        }
        if !objectives.isEmpty {
            let okrsPayload: [[String: Any]] = objectives.map { objective in
                var obj: [String: Any] = [
                    "title": objective.title
                ]
                if !objective.keyResults.isEmpty {
                    obj["keyResults"] = objective.keyResults.map { ["description": $0.description] }
                }
                return obj
            }
            data["okrs"] = okrsPayload
        }
        
        db.collection("projects").addDocument(data: data) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    func updateProject(
        documentId: String,
        name: String,
        clientName: String?,
        clientId: String? = nil,
        projectManager: String?,
        projectManagerId: String? = nil,
        assignedEmployees: [String],
        assigneeIds: [String] = [],
        startDate: Date,
        endDate: Date,
        objectives: [Objective],
        completion: ((Error?) -> Void)? = nil
    ) {
        var data: [String: Any] = [
            "name": name,
            "projectName": name,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "assignedEmployees": assignedEmployees,
            "assigneeNames": assignedEmployees,
            "updatedAt": Timestamp(date: Date())
        ]
        
        if !assigneeIds.isEmpty {
            data["assigneeIds"] = assigneeIds
        }
        
        if let client = clientName?.trimmingCharacters(in: .whitespacesAndNewlines), !client.isEmpty {
            data["clientName"] = client
        }
        if let cid = clientId {
            data["clientId"] = cid
        }
        
        if let manager = projectManager?.trimmingCharacters(in: .whitespacesAndNewlines), !manager.isEmpty {
            data["projectManager"] = manager
            data["projectManagerName"] = manager
        }
        if let pmid = projectManagerId {
            data["projectManagerId"] = pmid
        }
        if !objectives.isEmpty {
            let okrsPayload: [[String: Any]] = objectives.map { objective in
                var obj: [String: Any] = [
                    "title": objective.title
                ]
                if !objective.keyResults.isEmpty {
                    obj["keyResults"] = objective.keyResults.map { ["description": $0.description] }
                }
                return obj
            }
            data["okrs"] = okrsPayload
        }
        
        db.collection("projects").document(documentId).updateData(data) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    func deleteProject(documentId: String, completion: ((Error?) -> Void)? = nil) {
        db.collection("projects").document(documentId).delete { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    @Published var resourceRoles: [String] = ["Select role", "Senior Developer", "Junior Developer", "Project Manager", "UI/UX Designer", "QA Engineer"]
    @Published var employmentTypes: [String] = ["Full-time", "Part-time", "Contract", "Intern"]
    @Published var resourceTypes: [String] = ["In-house", "Outsourced"]
    @Published var resourceStatuses: [String] = ["Active", "Inactive"]
    
    // MARK: - Fetch Resource Metadata
    func fetchResourceMetaData() {
        // Fetch General Resource Settings
        db.collection("settings").document("resources").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                // Note: Roles are now fetched from 'hierarchy' document
                if let empTypes = data["employmentTypes"] as? [String] { self.employmentTypes = empTypes }
                if let resTypes = data["resourceTypes"] as? [String] { self.resourceTypes = resTypes }
                if let statuses = data["statuses"] as? [String] { self.resourceStatuses = statuses }
            }
        }
        
        // Fetch Hierarchy for Roles
        db.collection("settings").document("hierarchy").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            
            var roleNames: [String] = []
            
            // Check if 'roles' field exists
            // Case 1: 'roles' is an Array of Objects (Most likely based on screenshot)
            if let rolesArray = data["roles"] as? [[String: Any]] {
                roleNames = rolesArray.compactMap { $0["name"] as? String }
                
            } else if let rolesMap = data["roles"] as? [String: Any] {
                // Case 2: 'roles' is a Map with numeric keys (e.g. "0", "1")
                let sortedKeys = rolesMap.keys.compactMap { Int($0) }.sorted()
                
                for key in sortedKeys {
                    if let roleData = rolesMap[String(key)] as? [String: Any],
                       let name = roleData["name"] as? String {
                        roleNames.append(name)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if !roleNames.isEmpty {
                    var finalRoles = ["Select role"]
                    finalRoles.append(contentsOf: roleNames)
                    self.resourceRoles = finalRoles
                    print("✅ Fetched and updated \(roleNames.count) roles from hierarchy")
                } else {
                    print("⚠️ No roles found in hierarchy document")
                }
            }
        }
    }
    
    // MARK: - Upload Image to Storage
    func uploadImage(image: UIImage, path: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            completion(.failure(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])))
            return
        }
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            storageRef.downloadURL { url, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else if let downloadURL = url?.absoluteString {
                        completion(.success(downloadURL))
                    }
                }
            }
        }
    }
    
    // MARK: - Get Download URL from Path
    func getDownloadURL(path: String, completion: @escaping (Result<String, Error>) -> Void) {
        let storageRef = storage.reference().child(path)
        storageRef.downloadURL { url, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if let downloadURL = url?.absoluteString {
                    completion(.success(downloadURL))
                }
            }
        }
    }
    
    // MARK: - Create Employee
    func createEmployee(data: [String: Any], completion: @escaping (Error?) -> Void) {
        var mutableData = data
        mutableData["createdAt"] = Timestamp(date: Date())
        
        db.collection("users").addDocument(data: mutableData) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    // MARK: - Update Employee
    func updateEmployee(id: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("users").document(id).updateData(data) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    // MARK: - Delete Employee
    func deleteEmployee(id: String, completion: @escaping (Error?) -> Void) {
        db.collection("users").document(id).delete() { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    // MARK: - Fetch Employees (users collection)
    func fetchEmployees() {
        db.collection("users").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching employees: \(error.localizedDescription)")
                    self.employees = []
                    return
                }
                guard let documents = snapshot?.documents else {
                    self.employees = []
                    return
                }
                self.employees = documents.map { doc in
                    self.profileFromData(id: doc.documentID, data: doc.data())
                }
            }
        }
    }
    
    // MARK: - Fetch Projects for Employee (filters by uid/email and assigned arrays)
    func fetchProjectsForEmployee(userUid uid: String?, userEmail email: String?, userName: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        db.collection("projects").addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching projects: \(error.localizedDescription)"
                    return
                }
                guard let documents = querySnapshot?.documents else {
                    self.projects = []
                    return
                }
                
                print("📁 fetchProjectsForEmployee -> total docs from Firestore: \(documents.count), uid: \(uid ?? "nil"), email: \(email ?? "nil"), name: \(userName ?? "nil")")
                
                // First, apply strict login-wise filtering by uid/email/name
                let filtered: [Project] = documents.compactMap { document -> Project? in
                    let data = document.data()
                    
                    func matchStringArray(_ any: Any?, equals target: String, caseInsensitive: Bool = false) -> Bool {
                        guard let any = any else { return false }
                        if let arr = any as? [String] {
                            return arr.contains { caseInsensitive ? $0.lowercased() == target.lowercased() : $0 == target }
                        }
                        if let arr = any as? [Any] {
                            for el in arr {
                                if let s = el as? String {
                                    if caseInsensitive ? s.lowercased() == target.lowercased() : s == target { return true }
                                } else if let d = el as? [String: Any] {
                                    for k in ["uid","id","userId","userID","userUid","userUID","employeeId","employeeID","employeeUid","employeeUID","email","userEmail","employeeEmail"] {
                                        if let v = d[k] as? String {
                                            if caseInsensitive ? v.lowercased() == target.lowercased() : v == target { return true }
                                        }
                                    }
                                }
                            }
                        }
                        return false
                    }
                    
                    var checkPerformed = false
                    var matched = false
                    
                    // 1. Check UID
                    if let uid = uid, !uid.isEmpty {
                        checkPerformed = true
                        let uidKeys = ["assignedId", "assignedUID", "assignedUid", "employeeId", "ownerUid", "createdByUid", "managerUid", "leadUid", "employeeUid", "assigneeId"]
                        let matchUidField = uidKeys.contains { (data[$0] as? String) == uid }
                        let uidArrayKeys = ["assignedEmployees", "assignedEmployeeIds", "assignedUids", "members", "teamMembers", "employeeUids", "employeeIds", "assignees", "participants", "employees", "assigneeIds"]
                        let matchUidArray = uidArrayKeys.contains { key in matchStringArray(data[key], equals: uid) }
                        if matchUidField || matchUidArray { matched = true }
                    }
                    
                    // 2. Check Email
                    if let email = email, !email.isEmpty {
                        checkPerformed = true
                        let emailLower = email.lowercased()
                        let emailKeys = ["assignedEmail", "ownerEmail", "createdByEmail", "managerEmail", "leadEmail", "employeeEmail", "assigneeEmail"]
                        let matchEmailField = emailKeys.contains { ((data[$0] as? String)?.lowercased() ?? "") == emailLower }
                        let emailArrayKeys = ["assignedEmployeeEmails", "assignedEmails", "members", "teamMembers", "employees", "assignees", "participants", "emails", "assignedEmployees"]
                        let matchEmailArray = emailArrayKeys.contains { key in matchStringArray(data[key], equals: emailLower, caseInsensitive: true) }
                        if matchEmailField || matchEmailArray { matched = true }
                    }
                    
                    // 3. Check Name (User Name / Display Name) - Important for Managers assigned by name
                    if let name = userName, !name.isEmpty {
                        checkPerformed = true
                        let nameLower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let nameKeys = ["projectManager", "projectManagerName", "manager", "managerName", "lead", "leadName"]
                        let matchNameField = nameKeys.contains { key in
                            guard let val = data[key] as? String else { return false }
                            return val.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == nameLower
                        }
                        // Also check if name is in assignedEmployees if they stored names there
                        // Added "assigneeNames" to the keys to check
                        let nameArrayKeys = ["assignedEmployees", "assigneeNames", "members", "teamMembers", "employees", "assignees"]
                        let matchNameArray = nameArrayKeys.contains { key in matchStringArray(data[key], equals: nameLower, caseInsensitive: true) }
                        
                        // Debug print for tracing matches
                        if matchNameField || matchNameArray {
                             print("✅ Matched project \(data["projectName"] ?? "") for user \(name)")
                             matched = true 
                        }
                    }
                    
                    if checkPerformed && !matched { return nil }
                    
                    let documentId = document.documentID
                    let name = data["name"] as? String
                    ?? data["projectName"] as? String
                    ?? data["title"] as? String
                    ?? data["clientName"] as? String
                    ?? "Project \(documentId.prefix(8))"
                    
                    let description = data["description"] as? String
                    ?? data["goals"] as? String
                    ?? data["objective"] as? String
                    ?? "No description available"
                    
                    let progress = data["progress"] as? Double ?? 0.0
                    let assignedEmployees = data["assignedEmployees"] as? [String] ?? []
                    let projectManager = data["projectManagerName"] as? String
                    ?? data["projectManager"] as? String
                    let clientName = (data["clientName"] as? String)
                    ?? (data["ClientName"] as? String)
                    ?? (data["cLientName"] as? String)
                    ?? (data["customerName"] as? String)
                    
                    let startDate: Date
                    if let ts = data["startDate"] as? Timestamp {
                        startDate = ts.dateValue()
                    } else if let ts = data["createdAt"] as? Timestamp {
                        startDate = ts.dateValue()
                    } else {
                        startDate = Date()
                    }
                    
                    let endDate: Date
                    if let ts = data["endDate"] as? Timestamp {
                        endDate = ts.dateValue()
                    } else if let ts = data["deadline"] as? Timestamp {
                        endDate = ts.dateValue()
                    } else {
                        endDate = Date().addingTimeInterval(86400 * 30)
                    }
                    
                    let departmentName = data["department"] as? String
                    let department = Department.sampleDepartments.first { $0.name == departmentName }
                    
                    var objectives: [Objective] = []
                    if let okrsData = data["okrs"] as? [[String: Any]] ?? data["objectives"] as? [[String: Any]] {
                        objectives = okrsData.compactMap { obj -> Objective? in
                            guard let title = obj["title"] as? String ?? obj["objective"] as? String else { return nil }
                            var keyResults: [KeyResult] = []
                            if let keyResultsData = obj["keyResults"] as? [[String: Any]] {
                                keyResults = keyResultsData.compactMap { kr in
                                    guard let desc = kr["description"] as? String else { return nil }
                                    return KeyResult(description: desc)
                                }
                            } else if let keyResultsArray = obj["keyResults"] as? [String] {
                                keyResults = keyResultsArray.map { KeyResult(description: $0) }
                            }
                            return Objective(title: title, keyResults: keyResults)
                        }
                    }
                    
                    return Project(
                        documentId: documentId,
                        name: name,
                        description: description,
                        progress: progress,
                        startDate: startDate,
                        endDate: endDate,
                        tasks: [],
                        assignedEmployees: assignedEmployees,
                        department: department,
                        objectives: objectives,
                        projectManager: projectManager,
                        clientName: clientName
                    )
                }
                
                print("📁 fetchProjectsForEmployee -> filtered projects for user: \(filtered.count)")
                // Always use only the projects that match the logged-in employee.
                // If there is no match, the employee will see an empty projects list.
                self.projects = filtered
            }
        }
    }
    
    // MARK: - Task Progress (Two-way Sync)
    func updateTaskProgress(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, to newProgress: Int, completion: ((Int) -> Void)? = nil) {
        let clamped = max(0, min(100, newProgress))
        var query: Query = self.db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { query = query.whereField("projectId", isEqualTo: pid) }
        
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "clientId", "clientUid", "clientUID"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail", "clientEmail"]
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            var updated = 0
            let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                let data = doc.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty { uidMatched = uidKeys.contains { (data[$0] as? String) == uid } }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty { emailMatched = emailKeys.contains { (data[$0] as? String) == email } }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) { return uidMatched || emailMatched }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            let group = DispatchGroup()
            for d in filtered {
                group.enter()
                d.reference.updateData(["progress": clamped, "updatedAt": Timestamp(date: Date())]) { _ in
                    updated += 1
                    group.leave()
                }
            }
            group.notify(queue: .main) { completion?(updated) }
        }
    }
    
    func observeTaskProgress(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, onChange: @escaping (Int) -> Void) {
        var query: Query = self.db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { query = query.whereField("projectId", isEqualTo: pid) }
        
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "clientId", "clientUid", "clientUID"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail", "clientEmail"]
        query.addSnapshotListener { snapshot, _ in
            let docs = snapshot?.documents ?? []
            let filtered = docs.filter { d in
                let data = d.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty { uidMatched = uidKeys.contains { (data[$0] as? String) == uid } }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty { emailMatched = emailKeys.contains { (data[$0] as? String) == email } }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) { return uidMatched || emailMatched }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            var latest = 0
            for d in filtered {
                let p = (d.data()["progress"] as? Int) ?? (d.data()["progress"] as? Double).map { Int($0) } ?? 0
                latest = max(latest, p)
            }
            DispatchQueue.main.async { onChange(latest) }
        }
    }
    
    // MARK: - Self Task Progress (Two-way Sync)
    func updateSelfTaskProgress(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, to newProgress: Int, completion: ((Int) -> Void)? = nil) {
        let clamped = max(0, min(100, newProgress))
        var query: Query = self.db.collection("selfTasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { query = query.whereField("projectId", isEqualTo: pid) }
        
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "clientId", "clientUid", "clientUID", "userUid", "userUID"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail", "clientEmail", "userEmail"]
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            var updated = 0
            let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                let data = doc.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty { uidMatched = uidKeys.contains { (data[$0] as? String) == uid } }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty { emailMatched = emailKeys.contains { (data[$0] as? String) == email } }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) { return uidMatched || emailMatched }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            let group = DispatchGroup()
            for d in filtered {
                group.enter()
                d.reference.updateData(["progress": clamped, "updatedAt": Timestamp(date: Date())]) { _ in
                    updated += 1
                    group.leave()
                }
            }
            group.notify(queue: .main) { completion?(updated) }
        }
    }
    
    func observeSelfTaskProgress(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, onChange: @escaping (Int) -> Void) {
        var query: Query = self.db.collection("selfTasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { query = query.whereField("projectId", isEqualTo: pid) }
        
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "clientId", "clientUid", "clientUID", "userUid", "userUID"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail", "clientEmail", "userEmail"]
        query.addSnapshotListener { snapshot, _ in
            let docs = snapshot?.documents ?? []
            let filtered = docs.filter { d in
                let data = d.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty { uidMatched = uidKeys.contains { (data[$0] as? String) == uid } }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty { emailMatched = emailKeys.contains { (data[$0] as? String) == email } }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) { return uidMatched || emailMatched }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            var latest = 0
            for d in filtered {
                let p = (d.data()["progress"] as? Int) ?? (d.data()["progress"] as? Double).map { Int($0) } ?? 0
                latest = max(latest, p)
            }
            DispatchQueue.main.async { onChange(latest) }
        }
    }
    
    func fetchProjectsForClient(userUid uid: String?, userEmail email: String?, clientName: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        db.collection("projects").addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching projects: \(error.localizedDescription)"
                    return
                }
                guard let documents = querySnapshot?.documents else {
                    self.projects = []
                    return
                }
                
                self.projects = documents.compactMap { document -> Project? in
                    let data = document.data()
                    
                    var allowed = true
                    if let uid = uid, !uid.isEmpty {
                        let uidKeys = ["clientUid", "clientUID", "clientId", "customerUid", "customerUID", "customerId"]
                        let matchUid = uidKeys.contains { (data[$0] as? String) == uid }
                        allowed = allowed && matchUid
                    }
                    if let email = email, !email.isEmpty {
                        let emailKeys = ["clientEmail", "customerEmail"]
                        let matchEmail = emailKeys.contains { (data[$0] as? String) == email }
                        if uid == nil || uid!.isEmpty {
                            allowed = allowed && matchEmail
                        } else {
                            allowed = allowed || matchEmail
                        }
                    }
                    if let cName = clientName, !cName.isEmpty {
                        let nameKeys = ["clientName", "ClientName", "cLientName", "customerName"]
                        let matchName = nameKeys.contains { (data[$0] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                        if (uid == nil || uid!.isEmpty) && (email == nil || email!.isEmpty) {
                            allowed = allowed && matchName
                        } else {
                            allowed = allowed || matchName
                        }
                    }
                    if (uid != nil && !(uid!.isEmpty)) || (email != nil && !(email!.isEmpty)) || (clientName != nil && !(clientName!.isEmpty)) {
                        if !allowed { return nil }
                    }
                    
                    let documentId = document.documentID
                    let name = data["name"] as? String
                    ?? data["projectName"] as? String
                    ?? data["title"] as? String
                    ?? data["clientName"] as? String
                    ?? "Project \(documentId.prefix(8))"
                    
                    let description = data["description"] as? String
                    ?? data["goals"] as? String
                    ?? data["objective"] as? String
                    ?? "No description available"
                    
                    let progress = data["progress"] as? Double ?? 0.0
                    let assignedEmployees = data["assignedEmployees"] as? [String] ?? []
                    let projectManager = data["projectManagerName"] as? String
                    ?? data["projectManager"] as? String
                    
                    let startDate: Date
                    if let ts = data["startDate"] as? Timestamp {
                        startDate = ts.dateValue()
                    } else if let ts = data["createdAt"] as? Timestamp {
                        startDate = ts.dateValue()
                    } else {
                        startDate = Date()
                    }
                    
                    let endDate: Date
                    if let ts = data["endDate"] as? Timestamp {
                        endDate = ts.dateValue()
                    } else if let ts = data["deadline"] as? Timestamp {
                        endDate = ts.dateValue()
                    } else {
                        endDate = Date().addingTimeInterval(86400 * 30)
                    }
                    
                    let departmentName = data["department"] as? String
                    let department = Department.sampleDepartments.first { $0.name == departmentName }
                    
                    var objectives: [Objective] = []
                    if let okrsData = data["okrs"] as? [[String: Any]] ?? data["objectives"] as? [[String: Any]] {
                        objectives = okrsData.compactMap { obj -> Objective? in
                            guard let title = obj["title"] as? String ?? obj["objective"] as? String else { return nil }
                            var keyResults: [KeyResult] = []
                            if let keyResultsData = obj["keyResults"] as? [[String: Any]] {
                                keyResults = keyResultsData.compactMap { kr in
                                    guard let desc = kr["description"] as? String else { return nil }
                                    return KeyResult(description: desc)
                                }
                            } else if let keyResultsArray = obj["keyResults"] as? [String] {
                                keyResults = keyResultsArray.map { KeyResult(description: $0) }
                            }
                            return Objective(title: title, keyResults: keyResults)
                        }
                    }
                    
                    return Project(
                        documentId: documentId,
                        name: name,
                        description: description,
                        progress: progress,
                        startDate: startDate,
                        endDate: endDate,
                        tasks: [],
                        assignedEmployees: assignedEmployees,
                        department: department,
                        objectives: objectives,
                        projectManager: projectManager,
                        clientName: nil // Client view doesn't necessarily need to see client name field populated as it is them? Or should it? 
                        // Actually 'name' variable in fetchProjectsForClient (line 713) is used as project name.
                        // clientName variable was NOT extracted in fetchProjectsForClient?
                        // Let's check fetchProjectsForClient extraction code first.

                    )
                }
            }
        }
    }
    
    func fetchClients() {
        isLoading = true
        errorMessage = nil
        
        db.collection("clients").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching clients: \(error.localizedDescription)"
                    return
                }
                let documents = snapshot?.documents ?? []
                self.clients = documents.compactMap { document in
                    let data = document.data()
                    let name = data["clientName"] as? String
                    ?? data["name"] as? String
                    ?? "Client \(document.documentID.prefix(8))"
                    
                    return Client(
                        documentId: document.documentID,
                        name: name,
                        companyName: data["companyName"] as? String,
                        email: data["email"] as? String,
                        phone: data["phone"] as? String ?? data["contactNo"] as? String,
                        businessType: data["businessType"] as? String,
                        employeeCount: data["employeeCount"] as? String,
                        address: data["address"] as? String,
                        logoURL: data["logoURL"] as? String
                    )
                }
            }
        }
    }
    
    func createClient(data: [String: Any], completion: @escaping (Error?) -> Void) {
        var mutableData = data
        mutableData["createdAt"] = Timestamp(date: Date())
        
        db.collection("clients").addDocument(data: mutableData) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    func updateClient(documentId: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("clients").document(documentId).updateData(data) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    func deleteClient(documentId: String, completion: @escaping (Error?) -> Void) {
        db.collection("clients").document(documentId).delete() { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    // MARK: - Lead Management Methods
    @Published var leadStatuses: [String] = []

    // MARK: - Lead Management Methods
    func fetchLeadSettings() {
        db.collection("leadSettings").document("config").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                self.leadProducts = data["products"] as? [String] ?? []
                self.leadSectors = data["sectors"] as? [String] ?? []
                self.leadSources = data["sources"] as? [String] ?? []
                self.leadCategories = data["productCategories"] as? [String] ?? []
                self.leadPriorities = data["priorities"] as? [String] ?? []
                self.leadStatuses = data["statuses"] as? [String] ?? []
                
                // Fallback for sectors if empty (per user request)
                if self.leadSectors.isEmpty {
                    self.leadSectors = ["Foundry", "Automobile", "Manufacturing", "Pharma", "Food & Beverage", "Logistics", "Construction", "Other"]
                }
                
                // Fallback for categories if empty (per user request)
                if self.leadCategories.isEmpty {
                    self.leadCategories = ["End User", "Dealer", "Distributor", "OEM", "Contractor", "Other"]
                }
            }
        }
    }

    func fetchLeads() {
        isLoading = true
        errorMessage = nil
        
        db.collection("leads").order(by: "createdAt", descending: true).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching leads: \(error.localizedDescription)"
                    return
                }
                let documents = snapshot?.documents ?? []
                self.leads = documents.compactMap { document in
                    let data = document.data()
                    let name = data["customerName"] as? String ?? data["name"] as? String ?? "Lead \(document.documentID.prefix(8))"
                    let status = data["status"] as? String ?? "New"
                    let dateTimestamp = data["createdAt"] as? Timestamp
                    let createdAt = dateTimestamp?.dateValue() ?? Date()
                    
                    // Handle followUpDate as Timestamp or String
                    var followUpDate: Date? = nil
                    if let timestamp = data["followUpDate"] as? Timestamp {
                        followUpDate = timestamp.dateValue()
                    } else if let dateString = data["followUpDate"] as? String {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        if let date = formatter.date(from: dateString) {
                            followUpDate = date
                        } else {
                            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Try fallback format
                            followUpDate = formatter.date(from: dateString)
                        }
                    }
                    
                    // Potential Value Parsing
                    var potentialValue: Double? = nil
                    if let val = data["potentialValue"] as? Double {
                        potentialValue = val
                    } else if let valStr = data["potentialValue"] as? String {
                        potentialValue = Double(valStr)
                    }

                    // Phone Parsing
                    // Phone Parsing
                    var phone: String? = data["phone"] as? String
                    if phone == nil { phone = data["contactNumber"] as? String }
                    if phone == nil { phone = data["mobile"] as? String }
                    if phone == nil { phone = data["mobileNumber"] as? String }
                    if phone == nil { phone = data["phoneNumber"] as? String }
                    
                    if phone == nil {
                        if let val = data["phone"] as? Int { phone = String(val) }
                        else if let val = data["contactNumber"] as? Int { phone = String(val) }
                        else if let val = data["mobile"] as? Int { phone = String(val) }
                        else if let val = data["phone"] as? Int64 { phone = String(val) }
                        else if let val = data["phone"] as? Double { phone = String(Int(val)) }
                    }
                    
                    // Source Parsing
                    let source = data["source"] as? String ?? data["sourceOfLead"] as? String

                    return Lead(
                        documentId: document.documentID,
                        name: name,
                        companyName: data["companyName"] as? String,
                        email: data["email"] as? String,
                        phone: phone,
                        source: source,
                        status: status,
                        followUpDate: followUpDate,
                        notes: data["notes"] as? String,
                        createdAt: createdAt,
                        potentialValue: potentialValue,
                        address: data["address"] as? String,
                        productOfInterest: data["productOfInterest"] as? String,
                        sector: data["sector"] as? String,
                        productCategory: data["productCategory"] as? String,
                        priority: data["priority"] as? String // Handle priority from String
                    )
                }
            }
        }
    }
    
    func createLead(data: [String: Any], completion: @escaping (Error?) -> Void) {
        var mutableData = data
        mutableData["createdAt"] = Timestamp(date: Date())
        
        db.collection("leads").addDocument(data: mutableData) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    func updateLead(documentId: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        var mutableData = data
        mutableData["updatedAt"] = Timestamp(date: Date())
        
        db.collection("leads").document(documentId).updateData(mutableData) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    func deleteLead(documentId: String, completion: @escaping (Error?) -> Void) {
        db.collection("leads").document(documentId).delete() { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    func saveEmployeeDailyReport(employeeUid: String?, employeeEmail: String?, employeeName: String, projectName: String, date: Date, tasksDone: String, reportText: String, status: String?, dailyHours: String?, objective: String?, obstacles: String?, nextActionPlan: String?, comments: String?, reportType: String?, completion: ((Error?) -> Void)? = nil) {
        var data: [String: Any] = [
            "employeeName": employeeName,
            "projectName": projectName,
            "date": Timestamp(date: date),
            "tasksDone": tasksDone,
            "reportText": reportText,
            "createdAt": Timestamp(date: Date())
        ]
        if let uid = employeeUid, !uid.isEmpty {
            data["employeeUid"] = uid
        }
        if let email = employeeEmail, !email.isEmpty {
            data["employeeEmail"] = email
        }
        if let trimmedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedStatus.isEmpty {
            data["status"] = trimmedStatus
        }
        if let v = dailyHours?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { data["dailyHours"] = v }
        if let v = objective?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { data["objective"] = v }
        if let v = obstacles?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { data["obstacles"] = v }
        if let v = nextActionPlan?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { data["nextActionPlan"] = v }
        if let v = comments?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { data["comments"] = v }
        if let t = reportType?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            data["reportType"] = t
        }
        db.collection("employeeDailyReports").addDocument(data: data) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    func saveReminder(userUid: String?, userEmail: String?, title: String, details: String, date: Date, priority: String, repeats: String, notifyEnabled: Bool, notifyMinutesBefore: Int, completion: ((Error?) -> Void)? = nil) {
        var data: [String: Any] = [
            "title": title,
            "details": details,
            "date": Timestamp(date: date),
            "priority": priority,
            "repeats": repeats,
            "notifyEnabled": notifyEnabled,
            "notifyMinutesBefore": notifyMinutesBefore,
            "createdAt": Timestamp(date: Date())
        ]
        if let uid = userUid, !uid.isEmpty {
            data["userUid"] = uid
        }
        if let email = userEmail, !email.isEmpty {
            data["userEmail"] = email
        }
        db.collection("reminders").document("reminders").collection("reminders").addDocument(data: data) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    func updateReminder(documentId: String, title: String, details: String, date: Date, priority: String, repeats: String, notifyEnabled: Bool, notifyMinutesBefore: Int, completion: ((Error?) -> Void)? = nil) {
        var data: [String: Any] = [
            "title": title,
            "details": details,
            "date": Timestamp(date: date),
            "priority": priority,
            "repeats": repeats,
            "notifyEnabled": notifyEnabled,
            "notifyMinutesBefore": notifyMinutesBefore,
            "updatedAt": Timestamp(date: Date())
        ]
        db.collection("reminders").document("reminders").collection("reminders").document(documentId).updateData(data) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    func listenTaskStatusOptions() {
        db.collection("settings").document("task-statuses").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching task status options: \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data() else { return }
                
                var labels: [String] = []
                var colors: [String: String] = [:]
                
                if let statusesArray = data["statuses"] as? [Any] {
                    for item in statusesArray {
                        if let dict = item as? [String: Any] {
                            let raw = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            if !raw.isEmpty {
                                labels.append(raw)
                                if let colorHex = dict["color"] as? String {
                                    colors[raw] = colorHex
                                }
                            }
                        } else if let raw = item as? String {
                            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { labels.append(trimmed) }
                        }
                    }
                } else {
                    for value in data.values {
                        if let dict = value as? [String: Any] {
                            let raw = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            if !raw.isEmpty {
                                labels.append(raw)
                                if let colorHex = dict["color"] as? String {
                                    colors[raw] = colorHex
                                }
                            }
                        }
                    }
                }
                
                if !labels.isEmpty {
                    // Filter out duplicates
                    labels = Array(Set(labels))
                    
                    // Specific order for common statuses, others appended
                    let order = ["Today's Task", "TODO", "In Progress", "Stuck", "Waiting For", "Hold by Client", "Need Help", "Done", "Recurring Task", "Canceled"]
                    
                    labels.sort { a, b in
                        let idxA = order.firstIndex(of: a) ?? Int.max
                        let idxB = order.firstIndex(of: b) ?? Int.max
                        if idxA != idxB { return idxA < idxB }
                        return a < b
                    }
                    
                    if !labels.contains("All") {
                        labels.insert("All", at: 0)
                    } else {
                        labels.removeAll { $0 == "All" }
                        labels.insert("All", at: 0)
                    }
                    
                    self.taskStatusOptions = labels
                    self.taskStatusColors = colors
                    print("✅ Updated taskStatusOptions from Firestore: \(labels)")
                }
            }
        }
    }
    
    func addTaskStatus(_ status: String, color: String, completion: @escaping (Error?) -> Void) {
        let trimmedName = status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let docRef = db.collection("settings").document("task-statuses")
        
        let newEntry: [String: String] = ["name": trimmedName, "color": color]
        
        docRef.updateData([
            "statuses": FieldValue.arrayUnion([newEntry])
        ]) { error in
            if let error = error {
                // If doc doesn't exist, create it
                docRef.setData([
                    "statuses": [newEntry]
                ]) { err in
                    DispatchQueue.main.async { completion(err) }
                }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    func removeTaskStatus(_ status: String, completion: @escaping (Error?) -> Void) {
        let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let docRef = db.collection("settings").document("task-statuses")
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                try doc = transaction.getDocument(docRef)
            } catch let fetchError {
                errorPointer?.pointee = fetchError as NSError
                return nil
            }
            
            guard let data = doc.data(), let statusesArray = data["statuses"] as? [Any] else { return nil }
            
            let newStatuses = statusesArray.filter { item in
                if let str = item as? String {
                    return str != trimmed
                }
                if let dict = item as? [String: Any], let name = dict["name"] as? String {
                    return name != trimmed
                }
                return true
            }
            
            transaction.updateData(["statuses": newStatuses], forDocument: docRef)
            return nil
        }) { _, error in
            DispatchQueue.main.async { completion(error) }
        }
    }
    
    func updateTaskStatus(oldName: String, newName: String, newColor: String, completion: @escaping (Error?) -> Void) {
        let trimmedOld = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOld.isEmpty, !trimmedNew.isEmpty else { return }
        
        let docRef = db.collection("settings").document("task-statuses")
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                try doc = transaction.getDocument(docRef)
            } catch let fetchError {
                errorPointer?.pointee = fetchError as NSError
                return nil
            }
            
            guard let data = doc.data(), let statusesArray = data["statuses"] as? [Any] else { return nil }
            
            var newStatuses: [Any] = []
            var found = false
            
            for item in statusesArray {
                if let str = item as? String {
                    if str == trimmedOld {
                        newStatuses.append(["name": trimmedNew, "color": newColor])
                        found = true
                    } else {
                        newStatuses.append(str)
                    }
                } else if let dict = item as? [String: Any], let name = dict["name"] as? String {
                    if name == trimmedOld {
                        newStatuses.append(["name": trimmedNew, "color": newColor])
                        found = true
                    } else {
                        newStatuses.append(dict)
                    }
                } else {
                    newStatuses.append(item)
                }
            }
            
            if !found {
                // Should not happen if UI is consistent, but handle gracefully
                return nil
            }
            
            transaction.updateData(["statuses": newStatuses], forDocument: docRef)
            return nil
        }) { _, error in
            DispatchQueue.main.async { completion(error) }
        }
    }
    
    func listenTaskPriorityOptions() {
        db.collection("settings").document("task-priorities").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching task priority options: \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data() else { return }
                
                var labels: [String] = []
                
                // Try common keys for priorities
                let priorityKeys = ["priorities", "labels", "options", "list"]
                var found = false
                
                for key in priorityKeys {
                    if let array = data[key] as? [Any] {
                        for item in array {
                            if let dict = item as? [String: Any] {
                                let raw = (dict["name"] as? String ?? dict["label"] as? String ?? dict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                if !raw.isEmpty { labels.append(raw) }
                            } else if let raw = item as? String {
                                labels.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                        }
                        if !labels.isEmpty {
                            found = true
                            break
                        }
                    }
                }
                
                if !found {
                    // Fallback to all document values if they are strings or "name" fields
                    for value in data.values {
                        if let dict = value as? [String: Any] {
                            let raw = (dict["name"] as? String ?? dict["label"] as? String ?? dict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            if !raw.isEmpty { labels.append(raw) }
                        } else if let raw = value as? String {
                            labels.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                }
                
                if !labels.isEmpty {
                    // Map P1->High, P2->Medium, P3->Low
                    labels = labels.map { label in
                        let upper = label.uppercased()
                        if upper.contains("P1") { return "High" }
                        if upper.contains("P2") { return "Medium" }
                        if upper.contains("P3") { return "Low" }
                        return label
                    }
                    
                    // Deduplicate
                    labels = Array(Set(labels))
                    
                    // Sort: High < Medium < Low < Others
                    labels.sort { a, b in
                        let order = ["High": 0, "Medium": 1, "Low": 2]
                        let indexA = order[a] ?? Int.max
                        let indexB = order[b] ?? Int.max
                        if indexA != indexB {
                            return indexA < indexB
                        }
                        return a < b
                    }
                    
                    if !labels.contains("All Priorities") {
                        labels.insert("All Priorities", at: 0)
                    } else {
                        // Ensure "All Priorities" is at index 0
                        labels.removeAll(where: { $0 == "All Priorities" })
                        labels.insert("All Priorities", at: 0)
                    }
                    self.taskPriorityOptions = labels
                    print("✅ Updated taskPriorityOptions from Firestore: \(labels)")
                }
            }
        }
    }
    
    // MARK: - Project Levels
    // MARK: - Project Levels (Dynamic)
    func listenProjectLevels() {
        let docRef = db.collection("settings").document("project-levels")
        docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error listening for project levels: \(error)")
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                print("⚠️ Project Levels document missing. Seeding defaults.")
                self.seedDefaultProjectLevels()
                return
            }
            
            var fetchedLevels: [ProjectLevelItem] = []
            
            // Strategy 1: Check for 'levels' array field (Standard)
            if let levelsArray = data["levels"] as? [[String: Any]] {
                for dict in levelsArray {
                    if let level = dict["level"] as? String,
                       let name = dict["name"] as? String {
                        let id = dict["id"] as? String ?? UUID().uuidString
                        fetchedLevels.append(ProjectLevelItem(id: id, level: level, name: name))
                    }
                }
            }
            
            // Strategy 2: If array empty, check for Map/Dictionary structure
            // (Where fields are keys "0", "1" or IDs, and values are the level objects)
            if fetchedLevels.isEmpty {
                for (key, value) in data {
                    if let dict = value as? [String: Any],
                       let level = dict["level"] as? String,
                       let name = dict["name"] as? String {
                        let id = dict["id"] as? String ?? key
                        fetchedLevels.append(ProjectLevelItem(id: id, level: level, name: name))
                    }
                }
            }
            
            // If still empty after parsing, seed defaults
            if fetchedLevels.isEmpty {
                if data.isEmpty {
                    self.seedDefaultProjectLevels()
                    return
                }
            }
            
            self.projectLevels = fetchedLevels.sorted {
                if let l1 = Int($0.level), let l2 = Int($1.level) {
                    return l1 < l2
                }
                return $0.level < $1.level
            }
            print("✅ Fetched \(fetchedLevels.count) project levels from Firestore.")
        }
    }
    
    private func seedDefaultProjectLevels() {
        let defaults: [[String: String]] = [
            ["id": UUID().uuidString, "level": "1", "name": "Diagnose"],
            ["id": UUID().uuidString, "level": "2", "name": "Design Solution"],
            ["id": UUID().uuidString, "level": "3", "name": "Roadmap"],
            ["id": UUID().uuidString, "level": "4", "name": "System Design"],
            ["id": UUID().uuidString, "level": "5", "name": "Implementation"],
            ["id": UUID().uuidString, "level": "6", "name": "Monitor and Review and Optimize"],
            ["id": UUID().uuidString, "level": "7", "name": "Closure or Continuity"]
        ]
        
        db.collection("settings").document("project-levels").setData(["levels": defaults], merge: true) { error in
            if let error = error {
                print("Error seeding default project levels: \(error)")
            } else {
                print("Seeded default project levels successfully")
            }
        }
    }
    
    func addProjectLevel(level: String, name: String, completion: @escaping (Error?) -> Void) {
        let newItem: [String: String] = [
            "id": UUID().uuidString,
            "level": level,
            "name": name
        ]
        
        let docRef = db.collection("settings").document("project-levels")
        docRef.updateData([
            "levels": FieldValue.arrayUnion([newItem])
        ]) { error in
            if let error = error {
                docRef.setData(["levels": [newItem]], merge: true, completion: completion)
            } else {
                completion(nil)
            }
        }
    }
    
    func updateProjectLevel(item: ProjectLevelItem, completion: @escaping (Error?) -> Void) {
        let docRef = db.collection("settings").document("project-levels")
        
        docRef.getDocument { snapshot, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(nil)
                return
            }
            
            // Strategy 1: Update in Array (Standard)
            if var levelsArray = data["levels"] as? [[String: String]] {
                var indexToUpdate: Int?
                
                // Find by ID
                if let idx = levelsArray.firstIndex(where: { $0["id"] == item.id }) {
                    indexToUpdate = idx
                } else if let idx = levelsArray.firstIndex(where: { $0["level"] == item.level }) {
                    // Fallback find by level (for legacy items without IDs or wrong IDs)
                    indexToUpdate = idx
                } // Find by name as last resort
                else if let idx = levelsArray.firstIndex(where: { $0["name"] == item.name }) {
                    indexToUpdate = idx
                }
                
                if let idx = indexToUpdate {
                    levelsArray[idx] = ["id": item.id, "level": item.level, "name": item.name]
                    docRef.updateData(["levels": levelsArray], completion: completion)
                    return
                }
            }
            
            // Strategy 2: Update in Map/Dictionary (Fallback)
            var keyToUpdate: String?
            for (key, value) in data {
                if let dict = value as? [String: Any],
                   let id = dict["id"] as? String, id == item.id {
                    keyToUpdate = key
                    break
                }
            }
            
            if let key = keyToUpdate {
                let updatedDict: [String: Any] = ["id": item.id, "level": item.level, "name": item.name]
                docRef.updateData([key: updatedDict], completion: completion)
            } else {
                print("❌ Error: Could not find item to update with ID: \(item.id)")
                completion(nil)
            }
        }
    }
    
    func removeProjectLevel(item: ProjectLevelItem, completion: @escaping (Error?) -> Void) {
        let docRef = db.collection("settings").document("project-levels")
        
        docRef.getDocument { snapshot, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(nil)
                return
            }
            
            // Strategy 1: Remove from Array (Standard)
            if var levelsArray = data["levels"] as? [[String: String]] {
                // Try to filter out the item to be deleted
                let initialCount = levelsArray.count
                levelsArray.removeAll { dict in
                    // Match by unique ID if present
                    if let id = dict["id"], id == item.id { return true }
                    // Fallback: Match by level AND name (for legacy/seeded items)
                    if dict["level"] == item.level && dict["name"] == item.name { return true }
                    return false
                }
                
                if levelsArray.count < initialCount {
                    docRef.updateData(["levels": levelsArray], completion: completion)
                    return
                }
            }
            
            // Strategy 2: Remove from Map/Dictionary (Fallback)
            var keyToDelete: String?
            for (key, value) in data {
                if let dict = value as? [String: Any],
                   let id = dict["id"] as? String, id == item.id {
                    keyToDelete = key
                    break
                }
            }
            
            if let key = keyToDelete {
                docRef.updateData([key: FieldValue.delete()], completion: completion)
            } else {
                completion(nil) // Item not found
            }
        }
    }
    
    func listenReminders(forUserUid uid: String?, userEmail: String?) {
        var query: Query = db.collection("reminders").document("reminders").collection("reminders")
        if let uid = uid, !uid.isEmpty {
            query = query.whereField("userUid", isEqualTo: uid)
        } else if let email = userEmail, !email.isEmpty {
            query = query.whereField("userEmail", isEqualTo: email)
        }
        
        query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching reminders: \(error.localizedDescription)")
                    return
                }
                let documents = snapshot?.documents ?? []
                self.reminders = documents.compactMap { doc in
                    let data = doc.data()
                    let title = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if title.isEmpty { return nil }
                    let date: Date
                    if let ts = data["date"] as? Timestamp {
                        date = ts.dateValue()
                    } else {
                        date = Date()
                    }
                    let priority = data["priority"] as? String ?? "Medium"
                    return SavedReminder(id: doc.documentID, title: title, date: date, priority: priority)
                }.sorted { $0.date < $1.date }
            }
        }
    }
    
    func saveNote(userUid: String?, userEmail: String?, title: String, bodyText: String, category: String, isPinned: Bool, color: String, completion: ((Error?) -> Void)? = nil) {
        var data: [String: Any] = [
            "title": title,
            "bodyText": bodyText,
            "category": category,
            "isPinned": isPinned,
            "color": color,
            "createdAt": Timestamp(date: Date())
        ]
        if let uid = userUid, !uid.isEmpty {
            data["userUid"] = uid
        }
        if let email = userEmail, !email.isEmpty {
            data["userEmail"] = email
        }
        db.collection("notes").addDocument(data: data) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    func updateNote(documentId: String, title: String, bodyText: String, category: String, isPinned: Bool, color: String, completion: ((Error?) -> Void)? = nil) {
        let data: [String: Any] = [
            "title": title,
            "bodyText": bodyText,
            "category": category,
            "isPinned": isPinned,
            "color": color,
            "updatedAt": Timestamp(date: Date())
        ]
        db.collection("notes").document(documentId).updateData(data) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    func listenNotes(forUserUid uid: String?, userEmail: String?) {
        var query: Query = db.collection("notes")
        if let uid = uid, !uid.isEmpty {
            query = query.whereField("userUid", isEqualTo: uid)
        } else if let email = userEmail, !email.isEmpty {
            query = query.whereField("userEmail", isEqualTo: email)
        }
        
        query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching notes: \(error.localizedDescription)")
                    return
                }
                let documents = snapshot?.documents ?? []
                self.notes = documents.compactMap { doc in
                    let data = doc.data()
                    let title = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if title.isEmpty { return nil }
                    let category = data["category"] as? String ?? "General"
                    let isPinned = data["isPinned"] as? Bool ?? false
                    return SavedNote(id: doc.documentID, title: title, category: category, isPinned: isPinned)
                }.sorted { lhs, rhs in
                    if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                    return lhs.title < rhs.title
                }
            }
        }
    }
    
    func deleteReminder(documentId: String, completion: ((Bool) -> Void)? = nil) {
        db.collection("reminders").document("reminders").collection("reminders").document(documentId).delete { error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
        }
    }
    
    func deleteNote(documentId: String, completion: ((Bool) -> Void)? = nil) {
        db.collection("notes").document(documentId).delete { error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
        }
    }
    
    func deleteEmployeeDailyReport(documentId: String, completion: ((Bool) -> Void)? = nil) {
        db.collection("employeeDailyReports").document(documentId).delete { error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
        }
    }
    
    // MARK: - Knowledge
    
    func saveKnowledge(
        userUid: String?,
        userEmail: String?,
        title: String,
        bodyText: String,
        attachmentName: String? = nil,
        attachmentURL: String? = nil,
        link: String? = nil,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        var data: [String: Any] = [
            "title": title,
            "bodyText": bodyText,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        if let name = attachmentName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["attachmentName"] = name
        }
        if let url = attachmentURL, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["attachmentURL"] = url
        }
        if let uid = userUid, !uid.isEmpty {
            data["userUid"] = uid
        }
        if let email = userEmail, !email.isEmpty {
            data["userEmail"] = email
        }
        if let link = link, !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["link"] = link
        }
        
        let collection = db.collection("knowledge")
        let docRef = collection.document()
        docRef.setData(data) { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(.failure(error))
                } else {
                    completion?(.success(docRef.documentID))
                }
            }
        }
    }
    
    func updateKnowledge(
        documentId: String,
        title: String,
        bodyText: String,
        attachmentName: String? = nil,
        attachmentURL: String? = nil,
        link: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        var data: [String: Any] = [
            "title": title,
            "bodyText": bodyText,
            "updatedAt": Timestamp(date: Date())
        ]
        if let name = attachmentName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["attachmentName"] = name
        }
        if let url = attachmentURL, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["attachmentURL"] = url
        }
        if let link = link, !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["link"] = link
        }
        db.collection("knowledge").document(documentId).updateData(data) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    func listenKnowledge(forUserUid uid: String?, userEmail: String?, isAdmin: Bool = false) {
        // Fetch ALL knowledge items (ordered by date) to allow permission-based filtering on the client side
        db.collection("knowledge").order(by: "createdAt", descending: true).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching knowledge: \(error.localizedDescription)")
                    return
                }
                
                let documents = snapshot?.documents ?? []
                self.knowledgeItems = documents.compactMap { doc -> KnowledgeItem? in
                    let data = doc.data()
                    
                    // --- Robust Access Control Logic ---
                    
                    // 1. Check Creator (Owner)
                    var isCreator = false
                    if let uid = uid {
                        let creatorKeys = ["userUid", "userId", "creatorId", "uploadedByUid", "ownerUid", "createdByUid", "createdById"]
                        if creatorKeys.contains(where: { (data[$0] as? String) == uid }) { isCreator = true }
                    }
                    if !isCreator, let email = userEmail {
                        let creatorEmailKeys = ["userEmail", "user_email", "creatorEmail", "uploadedBy", "uploadedByEmail"]
                        if creatorEmailKeys.contains(where: { (data[$0] as? String) == email }) { isCreator = true }
                    }
                    
                    // 2. Check Assigned Access (Arrays & Singles)
                    var isAssigned = false
                    
                    if let uid = uid {
                        // Arrays
                        let uidArrayKeys = ["allowedUserIds", "allowedUsers", "assignedUserIds", "assignedEmployees", "employeeIds", "memberIds", "assignees", "allowedIds"]
                        for key in uidArrayKeys {
                            if let arr = data[key] as? [String], arr.contains(uid) { isAssigned = true; break }
                        }
                        // Singles
                        if !isAssigned {
                            let uidSingleKeys = ["assignedToUid", "assignedToId", "employeeId", "targetUserId", "assignedId"]
                            for key in uidSingleKeys {
                                if let val = data[key] as? String, val == uid { isAssigned = true; break }
                            }
                        }
                    }
                    
                    if !isAssigned, let email = userEmail {
                        // Arrays
                        let emailArrayKeys = ["allowedEmails", "allowedUserEmails", "assignedEmails", "assignedEmployeeEmails", "employeeEmails", "memberEmails", "allowedUserEmail"]
                        for key in emailArrayKeys {
                            if let arr = data[key] as? [String], arr.contains(email) { isAssigned = true; break }
                        }
                        // Singles
                        if !isAssigned {
                            let emailSingleKeys = ["assignedToEmail", "employeeEmail", "targetUserEmail", "assignedEmail"]
                            for key in emailSingleKeys {
                                if let val = data[key] as? String, val == email { isAssigned = true; break }
                            }
                        }
                    }
                    
                    // Filter: Must be Admin, OR Creator, OR Explicitly Assigned
                    guard isAdmin || isCreator || isAssigned else {
                        return nil
                    }
                    // -----------------------------
                    
                    let title = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    // Support both local 'bodyText' and admin 'description' fields
                    let bodyText = (data["description"] as? String ?? data["bodyText"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if title.isEmpty && bodyText.isEmpty { return nil }
                    
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
                    
                    let attachmentName = (data["attachmentName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let attachmentURL = (data["attachmentURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let link = (data["link"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    return KnowledgeItem(
                        id: doc.documentID,
                        title: title,
                        description: bodyText,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        attachmentName: (attachmentName?.isEmpty == false ? attachmentName : nil),
                        attachmentURL: (attachmentURL?.isEmpty == false ? attachmentURL : nil),
                        link: (link?.isEmpty == false ? link : nil)
                    )
                }
            }
        }
    }
    
    func deleteKnowledge(documentId: String, completion: ((Bool) -> Void)? = nil) {
        db.collection("knowledge").document(documentId).delete { error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
        }
    }
    
    func listenEmployeeDailyReports(forUserUid uid: String?, userEmail: String?) {
        var query: Query = db.collection("employeeDailyReports")
        if let uid = uid, !uid.isEmpty {
            query = query.whereField("employeeUid", isEqualTo: uid)
        } else if let email = userEmail, !email.isEmpty {
            query = query.whereField("employeeEmail", isEqualTo: email)
        }
        query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error fetching daily reports: \(error.localizedDescription)"
                    return
                }
                let documents = snapshot?.documents ?? []
                self.dailyReports = documents.compactMap { doc in
                    let data = doc.data()
                    let id = doc.documentID
                    let employeeName = data["employeeName"] as? String ?? "Employee"
                    let projectName = data["projectName"] as? String ?? "Project"
                    let date: Date
                    if let ts = data["date"] as? Timestamp {
                        date = ts.dateValue()
                    } else {
                        date = Date()
                    }
                    let tasksDone = data["tasksDone"] as? String ?? ""
                    let status = data["status"] as? String
                    let dailyHours = data["dailyHours"] as? String
                    let objective = (data["objective"] as? String) ?? (data["objectiveForDay"] as? String)
                    let obstacles = (data["obstacles"] as? String) ?? (data["obstaclesChallenges"] as? String)
                    let nextActionPlan = data["nextActionPlan"] as? String
                    let comments = (data["comments"] as? String) ?? (data["remarks"] as? String)
                    let reportText = data["reportText"] as? String ?? ""
                    let createdAt: Date
                    if let ts = data["createdAt"] as? Timestamp {
                        createdAt = ts.dateValue()
                    } else {
                        createdAt = Date()
                    }
                    let employeeUid = data["employeeUid"] as? String
                    let employeeEmail = data["employeeEmail"] as? String
                    let reportType = data["reportType"] as? String
                    return EmployeeDailyReport(
                        id: id,
                        employeeUid: employeeUid,
                        employeeEmail: employeeEmail,
                        employeeName: employeeName,
                        projectName: projectName,
                        date: date,
                        tasksDone: tasksDone,
                        status: status,
                        dailyHours: dailyHours,
                        objective: objective,
                        obstacles: obstacles,
                        nextActionPlan: nextActionPlan,
                        comments: comments,
                        reportText: reportText,
                        createdAt: createdAt,
                        reportType: reportType
                    )
                }.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }
    
    func fetchExpensesForEmployee(userUid uid: String?, userEmail email: String?, completion: @escaping ([ExpenseItem]) -> Void) {
        db.collection("expenses").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching expenses: \(error.localizedDescription)")
                    self.errorMessage = "Error fetching expenses: \(error.localizedDescription)"
                    completion([])
                    return
                }
                let documents = snapshot?.documents ?? []
                
                let filteredDocs = documents.filter { document in
                    let data = document.data()
                    var allowed = true
                    
                    if let uid = uid, !uid.isEmpty {
                        let uidKeys = ["employeeUid", "employeeId", "empId", "empID", "uid", "userId", "userID"]
                        let matchUidField = uidKeys.contains { (data[$0] as? String) == uid }
                        allowed = allowed && matchUidField
                    }
                    
                    if let email = email, !email.isEmpty {
                        let emailLower = email.lowercased()
                        let emailKeys = ["employeeEmail", "email", "userEmail"]
                        let matchEmailField = emailKeys.contains { ((data[$0] as? String)?.lowercased() ?? "") == emailLower }
                        if uid == nil || uid!.isEmpty {
                            allowed = allowed && matchEmailField
                        } else {
                            allowed = allowed || matchEmailField
                        }
                    }
                    
                    if (uid != nil && !(uid!.isEmpty)) || (email != nil && !(email!.isEmpty)) {
                        return allowed
                    }
                    return true
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                let items: [ExpenseItem] = filteredDocs.compactMap { doc in
                    let data = doc.data()
                    let id = doc.documentID
                    
                    let employee = (data["employee"] as? String)
                    ?? (data["employeeName"] as? String)
                    ?? (data["employeeEmail"] as? String)
                    ?? (data["empName"] as? String)
                    ?? (email ?? "")
                    
                    var dateString: String = ""
                    if let s = data["date"] as? String {
                        dateString = s
                    } else if let ts = data["date"] as? Timestamp {
                        dateString = dateFormatter.string(from: ts.dateValue())
                    } else if let s = data["expenseDate"] as? String {
                        dateString = s
                    }
                    
                    let category = (data["category"] as? String)
                    ?? (data["expenseCategory"] as? String)
                    ?? "Other"
                    
                    let amount: Double = {
                        if let d = data["amount"] as? Double { return d }
                        if let i = data["amount"] as? Int { return Double(i) }
                        if let s = data["amount"] as? String, let d = Double(s) { return d }
                        if let s = data["value"] as? String, let d = Double(s) { return d }
                        return 0.0
                    }()
                    
                    let currency = (data["currency"] as? String)
                    ?? (data["currencyCode"] as? String)
                    ?? "INR"
                    
                    let statusRawOriginal = ((data["status"] as? String)
                                             ?? (data["expenseStatus"] as? String)
                                             ?? "unpaid")
                    let statusRaw = statusRawOriginal.lowercased()
                    
                    let status: ExpenseItem.Status
                    if statusRaw.contains("draft") {
                        status = .draft
                    } else if statusRaw.contains("submit") || statusRaw.contains("pending") {
                        status = .submitted
                    } else if statusRaw.contains("reject") {
                        status = .rejected
                    } else if statusRaw.contains("approv") {
                        status = .approved
                    } else if statusRaw.contains("paid") {
                        status = .paid
                    } else {
                        status = .unpaid
                    }
                    
                    let title = (data["title"] as? String) ?? ""
                    let projectName = data["projectName"] as? String
                    let description = data["description"] as? String
                    let receiptUrl = (data["receiptUrl"] as? String)
                    ?? (data["receiptURL"] as? String)
                    
                    return ExpenseItem(
                        id: id,
                        employee: employee,
                        date: dateString,
                        category: category,
                        amount: amount,
                        currency: currency,
                        status: status,
                        title: title,
                        projectName: projectName,
                        description: description,
                        receiptUrl: receiptUrl
                    )
                }
                
                completion(items)
            }
        }
    }
    
    func uploadExpenseReceipt(fileURL: URL, forUserUid uid: String?, completion: @escaping (Result<String, Error>) -> Void) {
        let safeUid = uid?.isEmpty == false ? uid! : "unknown"
        let ext = fileURL.pathExtension.isEmpty ? "dat" : fileURL.pathExtension.lowercased()
        let fileName = UUID().uuidString + "." + ext
        let ref = storage.reference().child("expenseReceipts").child(safeUid).child(fileName)
        
        ref.putFile(from: fileURL, metadata: nil) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            ref.downloadURL { url, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else if let urlString = url?.absoluteString {
                        completion(.success(urlString))
                    } else {
                        completion(.failure(NSError(domain: "UploadExpenseReceipt", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing download URL"])))}
                }
            }
        }
    }
    
    func createExpense(forUserUid uid: String?, userEmail email: String?, title: String, date: Date, category: String, amount: Double, currency: String, description: String?, projectName: String?, receiptURL: String?, status: String, completion: @escaping (Bool) -> Void) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        
        var data: [String: Any] = [
            "title": title,
            "date": formatter.string(from: date),
            "category": category,
            "amount": amount,
            "currency": currency,
            "status": status.lowercased(),
            "createdAt": Timestamp(date: Date())
        ]
        
        if let uid = uid, !uid.isEmpty {
            data["employeeUid"] = uid
        }
        if let email = email, !email.isEmpty {
            data["employeeEmail"] = email
        }
        if let description = description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["description"] = description
        }
        if let projectName = projectName, !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["projectName"] = projectName
        }
        if let receiptURL = receiptURL, !receiptURL.isEmpty {
            data["receiptUrl"] = receiptURL
        }
        
        db.collection("expenses").addDocument(data: data) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    func updateExpense(
        documentId: String,
        forUserUid uid: String?,
        userEmail email: String?,
        title: String,
        date: Date,
        category: String,
        amount: Double,
        currency: String,
        description: String?,
        projectName: String?,
        receiptURL: String?,
        status: String,
        completion: @escaping (Bool) -> Void
    ) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        
        var data: [String: Any] = [
            "title": title,
            "date": formatter.string(from: date),
            "category": category,
            "amount": amount,
            "currency": currency,
            "status": status.lowercased(),
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let uid = uid, !uid.isEmpty {
            data["employeeUid"] = uid
        }
        if let email = email, !email.isEmpty {
            data["employeeEmail"] = email
        }
        if let description = description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["description"] = description
        }
        if let projectName = projectName, !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["projectName"] = projectName
        }
        if let receiptURL = receiptURL, !receiptURL.isEmpty {
            data["receiptUrl"] = receiptURL
        }
        
        db.collection("expenses").document(documentId).updateData(data) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    func deleteExpense(documentId: String, completion: @escaping (Bool) -> Void) {
        db.collection("expenses").document(documentId).delete { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    func updateSelfTaskStatus(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, to newStatus: TaskStatus, completion: ((Int) -> Void)? = nil) {
        let statusString = newStatus.rawValue
        
        let actorName: String = {
            if let user = Auth.auth().currentUser { return user.displayName ?? "User" }
            return "System"
        }()
        
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid"]
        let emailKeys = ["createdByEmail", "assignedEmail", "assigneeEmail"]
        
        func filterDocs(_ docs: [QueryDocumentSnapshot]) -> [QueryDocumentSnapshot] {
            return docs.filter { d in
                let data = d.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
        }
        
        let group = DispatchGroup()
        var updated = 0
        
        // Top-level '/selfTasks'
        var topQuery: Query = db.collection("selfTasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { topQuery = topQuery.whereField("projectId", isEqualTo: pid) }
        group.enter()
        topQuery.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["status": statusString, "updatedAt": Timestamp(date: Date())]) { _ in
                    let activity = ActivityItem(user: actorName, action: "changed status to", message: statusString, type: "status")
                    self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        // Nested '/selfTasks/{uid}/tasks' collectionGroup
        group.enter()
        var cgTasks: Query = db.collectionGroup("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { cgTasks = cgTasks.whereField("projectId", isEqualTo: pid) }
        cgTasks.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["status": statusString, "updatedAt": Timestamp(date: Date())]) { _ in
                    let activity = ActivityItem(user: actorName, action: "changed status to", message: statusString, type: "status")
                    self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        // Nested '/selfTasks/{uid}/selfTasks' collectionGroup
        group.enter()
        var cgSelf: Query = db.collectionGroup("selfTasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { cgSelf = cgSelf.whereField("projectId", isEqualTo: pid) }
        cgSelf.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["status": statusString, "updatedAt": Timestamp(date: Date())]) { _ in
                    let activity = ActivityItem(user: actorName, action: "changed status to", message: statusString, type: "status")
                    self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        group.notify(queue: .main) {
            completion?(updated)
        }
    }
    
    // MARK: - Subtask Status (self tasks)
    func updateSelfSubtaskStatus(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, to newStatus: TaskStatus, completion: ((Int) -> Void)? = nil) {
        let statusString: String = {
            switch newStatus {
            case .completed: return "Done"
            case .inProgress: return "In Progress"
            case .notStarted: return "To-Do"
            case .stuck: return "Stuck"
            case .waitingFor: return "Waiting For"
            case .onHoldByClient: return "Hold by Client"
            case .needHelp: return "Need Help"
            case .canceled: return "Canceled"
            }
        }()
        
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid"]
        let emailKeys = ["createdByEmail", "assignedEmail", "assigneeEmail"]
        
        func filterDocs(_ docs: [QueryDocumentSnapshot]) -> [QueryDocumentSnapshot] {
            return docs.filter { d in
                let data = d.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
        }
        
        let group = DispatchGroup()
        var updated = 0
        
        // Top-level '/selfTasks'
        var topQuery: Query = db.collection("selfTasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { topQuery = topQuery.whereField("projectId", isEqualTo: pid) }
        group.enter()
        topQuery.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["subtaskStatus": statusString, "updatedAt": Timestamp(date: Date())]) { _ in
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        // Nested '/selfTasks/{uid}/tasks' collectionGroup
        group.enter()
        var cgTasks: Query = db.collectionGroup("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { cgTasks = cgTasks.whereField("projectId", isEqualTo: pid) }
        cgTasks.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["subtaskStatus": statusString, "updatedAt": Timestamp(date: Date())]) { _ in
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        // Nested '/selfTasks/{uid}/selfTasks' collectionGroup
        group.enter()
        var cgSelf: Query = db.collectionGroup("selfTasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { cgSelf = cgSelf.whereField("projectId", isEqualTo: pid) }
        cgSelf.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["subtaskStatus": statusString, "updatedAt": Timestamp(date: Date())]) { _ in
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        group.notify(queue: .main) {
            completion?(updated)
        }
    }
    
    // Update self task status using a raw label string (preserve exact casing/spelling)
    func updateSelfTaskStatusLabel(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, toLabel label: String, completion: ((Int) -> Void)? = nil) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "clientId", "clientUid", "clientUID", "userUid", "userUID"]
        let emailKeys = ["createdByEmail", "assignedEmail", "assigneeEmail", "clientEmail"]
        
        func filterDocs(_ docs: [QueryDocumentSnapshot]) -> [QueryDocumentSnapshot] {
            return docs.filter { d in
                let data = d.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
        }
        
        let group = DispatchGroup()
        var updated = 0
        
        // Top-level '/selfTasks'
        var topQuery: Query = db.collection("selfTasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { topQuery = topQuery.whereField("projectId", isEqualTo: pid) }
        group.enter()
        topQuery.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["status": trimmed, "updatedAt": Timestamp(date: Date())]) { _ in
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        // Nested '/selfTasks/{uid}/tasks' collectionGroup
        group.enter()
        var cgTasks: Query = db.collectionGroup("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { cgTasks = cgTasks.whereField("projectId", isEqualTo: pid) }
        cgTasks.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["status": trimmed, "updatedAt": Timestamp(date: Date())]) { _ in
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        // Nested '/selfTasks/{uid}/selfTasks' collectionGroup
        group.enter()
        var cgSelf: Query = db.collectionGroup("selfTasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty { cgSelf = cgSelf.whereField("projectId", isEqualTo: pid) }
        cgSelf.getDocuments { snap, _ in
            let docs = filterDocs(snap?.documents ?? [])
            let inner = DispatchGroup()
            for d in docs {
                inner.enter()
                d.reference.updateData(["status": trimmed, "updatedAt": Timestamp(date: Date())]) { _ in
                    updated += 1
                    inner.leave()
                }
            }
            inner.notify(queue: .main) { group.leave() }
        }
        
        group.notify(queue: .main) {
            completion?(updated)
        }
    }
    
    // MARK: - Delete Single Task
    func deleteTask(_ task: Task, completion: ((Bool) -> Void)? = nil) {
        let title = task.title
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        
        if let projectId = task.project?.documentId, !projectId.isEmpty {
            query = query.whereField("projectId", isEqualTo: projectId)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error finding task to delete: \(error)")
                completion?(false)
                return
            }
            
            guard let docs = snapshot?.documents, !docs.isEmpty else {
                // If not found in 'tasks', try 'archivedTasks'
                self.deleteArchivedTask(task, completion: completion)
                return
            }
            
            let group = DispatchGroup()
            for doc in docs {
                group.enter()
                doc.reference.delete { _ in
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                print("Successfully deleted task")
                completion?(true)
            }
        }
    }
    
    private func deleteArchivedTask(_ task: Task, completion: ((Bool) -> Void)? = nil) {
        let title = task.title
        var query: Query = db.collection("archivedTasks").whereField("title", isEqualTo: title)
        
        if let projectId = task.project?.documentId, !projectId.isEmpty {
            query = query.whereField("projectId", isEqualTo: projectId)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error finding archived task to delete: \(error)")
                completion?(false)
                return
            }
            
            guard let docs = snapshot?.documents, !docs.isEmpty else {
                print("No matching task found to delete (checked tasks & archivedTasks) for: \(title)")
                completion?(false)
                return
            }
            
            let group = DispatchGroup()
            for doc in docs {
                group.enter()
                doc.reference.delete { _ in
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                print("Successfully deleted archived task")
                completion?(true)
            }
        }
    }


    // MARK: - Delete tasks by titles (from 'tasks' and 'selfTasks') for current user
    func archiveTask(_ task: Task, completion: @escaping (Bool) -> Void) {
        let title = task.title
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        
        if let projectId = task.project?.documentId, !projectId.isEmpty {
            query = query.whereField("projectId", isEqualTo: projectId)
        }
        
        query.getDocuments { snapshot, error in
            guard let doc = snapshot?.documents.first else {
                print("❌ No matching task found to archive")
                completion(false)
                return
            }
            
            let data = doc.data()
            let batch = self.db.batch()
            
            // 1. Add to archivedTasks
            let archiveRef = self.db.collection("archivedTasks").document(doc.documentID)
            var archiveData = data
            archiveData["archivedAt"] = Timestamp(date: Date())
            batch.setData(archiveData, forDocument: archiveRef)
            
            // 2. Delete from active tasks
            batch.deleteDocument(doc.reference)
            
            batch.commit { err in
                if let err = err {
                    print("❌ Error archiving task: \(err.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ Task archived successfully")
                    completion(true)
                }
            }
        }
    }
    
    func unarchiveTask(_ task: Task, completion: @escaping (Bool) -> Void) {
        let title = task.title
        var query: Query = db.collection("archivedTasks").whereField("title", isEqualTo: title)
        
        if let projectId = task.project?.documentId, !projectId.isEmpty {
            query = query.whereField("projectId", isEqualTo: projectId)
        }
        
        query.getDocuments { snapshot, error in
            guard let doc = snapshot?.documents.first else {
                print("❌ No matching archived task found to unarchive")
                completion(false)
                return
            }
            
            var data = doc.data()
            data.removeValue(forKey: "archivedAt") // Remove archive timestamp
            let batch = self.db.batch()
            
            // 1. Add back to active tasks
            let activeRef = self.db.collection("tasks").document(doc.documentID)
            batch.setData(data, forDocument: activeRef)
            
            // 2. Delete from archivedTasks
            batch.deleteDocument(doc.reference)
            
            batch.commit { err in
                if let err = err {
                    print("❌ Error unarchiving task: \(err.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ Task unarchived successfully")
                    completion(true)
                }
            }
        }
    }
    
    func deleteTasksByTitles(_ titles: [String], forUserUid uid: String?, userEmail: String?, completion: ((Int) -> Void)? = nil) {
        let collections = ["tasks", "selfTasks"]
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail"]
        
        let validTitles = titles.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if validTitles.isEmpty { completion?(0); return }
        
        let chunked = validTitles.chunked(into: 10)
        let group = DispatchGroup()
        var deletedCount = 0
        
        for chunk in chunked {
            for colName in collections {
                group.enter()
                db.collection(colName).whereField("title", in: chunk).getDocuments { snapshot, _ in
                    let docs = snapshot?.documents ?? []
                    for doc in docs {
                        let data = doc.data()
                        
                        var uidMatched = false
                        if let uid = uid, !uid.isEmpty {
                            uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                        }
                        var emailMatched = false
                        if let email = userEmail, !email.isEmpty {
                            emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                        }
                        
                        var canDelete = false
                        if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                            canDelete = uidMatched || emailMatched
                        } else if let _ = uid, !(uid!.isEmpty) {
                            canDelete = uidMatched
                        } else if let _ = userEmail, !(userEmail!.isEmpty) {
                            canDelete = emailMatched
                        } else {
                            canDelete = true
                        }
                        
                        if canDelete {
                            self.db.collection(colName).document(doc.documentID).delete { _ in
                                deletedCount += 1
                            }
                        }
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion?(deletedCount)
        }
    }
    
    // MARK: - Fetch Archived Tasks
    func fetchArchivedTasks() {
        db.collection("archivedTasks").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ Error fetching archived tasks: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            
            // Map similarly to regular tasks
            self.archivedTasks = documents.compactMap { self.mapTask(from: $0.data(), defaultType: .adminTask) }
        }
    }
    
    // MARK: - Task Commenting / Status Updates
    
    // Add activity log to task (subcollection 'activities')
    func createEvent(_ meeting: Meeting, createdByUid uid: String? = nil, createdByEmail email: String? = nil, clientName: String? = nil, completion: ((Bool) -> Void)? = nil) {
        let end = meeting.date.addingTimeInterval(TimeInterval(meeting.duration * 60))
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.timeZone = .current
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "en_US_POSIX")
        timeFmt.timeZone = .current
        timeFmt.dateFormat = "h:mm a"
        
        let statusString: String = {
            switch meeting.status {
            case .scheduled: return "scheduled"
            case .inProgress: return "in progress"
            case .completed: return "completed"
            case .cancelled: return "cancelled"
            }
        }()
        
        var data: [String: Any] = [
            "title": meeting.title,
            "agenda": meeting.agenda,
            "description": meeting.agenda,
            "meetingType": meeting.meetingType.rawValue,
            "projectName": meeting.project as Any,
            "start": Timestamp(date: meeting.date),
            "end": Timestamp(date: end),
            "date": dateFmt.string(from: meeting.date),
            "time": timeFmt.string(from: meeting.date),
            "duration": meeting.duration,
            "participants": meeting.participants,
            "attendees": meeting.participants,
            "status": statusString,
            "location": meeting.location as Any,
            "createdAt": Timestamp(date: Date())
        ]
        if let uid = uid { data["createdByUid"] = uid }
        if let email = email { data["createdByEmail"] = email }
        if let clientName = clientName, !clientName.isEmpty { data["clientName"] = clientName }
        
        db.collection("events").addDocument(data: data) { error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
        }
    }
    
    func fetchEvents() {
        isLoading = true
        errorMessage = nil
        
        db.collection("events").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching events: \(error.localizedDescription)"
                    return
                }
                let documents = snapshot?.documents ?? []
                self.events = documents.compactMap { self.mapEvent(from: $0.data()) }
            }
        }
    }
    
    func fetchEventsForEmployee(userUid uid: String?, userEmail email: String?) {
        isLoading = true
        errorMessage = nil
        
        db.collection("events").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching events: \(error.localizedDescription)"
                    return
                }
                let documents = snapshot?.documents ?? []
                let filteredDocs = documents.filter { document in
                    let data = document.data()
                    
                    var allowed = true
                    
                    if let uid = uid, !uid.isEmpty {
                        let uidKeys = [
                            "createdByUid", "ownerUid", "employeeUid", "employeeId",
                            "organizerUid", "assigneeId", "assignedUid", "assignedUID"
                        ]
                        let matchUidField = uidKeys.contains { (data[$0] as? String) == uid }
                        let uidArrays: [[String]] = [
                            data["assignedUids"] as? [String] ?? [],
                            data["members"] as? [String] ?? [],
                            data["teamMembers"] as? [String] ?? [],
                            data["attendeeIds"] as? [String] ?? []
                        ]
                        let matchUidArray = uidArrays.first { $0.contains(uid) } != nil
                        allowed = allowed && (matchUidField || matchUidArray)
                    }
                    
                    if let email = email, !email.isEmpty {
                        let emailLower = email.lowercased()
                        let emailKeys = [
                            "createdByEmail", "ownerEmail", "employeeEmail", "organizerEmail", "clientEmail"
                        ]
                        let matchEmailField = emailKeys.contains { ((data[$0] as? String)?.lowercased() ?? "") == emailLower }
                        
                        var matchEmailArray = false
                        if let arr = data["participants"] as? [String] {
                            matchEmailArray = arr.contains { $0.lowercased() == emailLower }
                        }
                        if !matchEmailArray, let arr = data["attendees"] as? [String] {
                            matchEmailArray = arr.contains { $0.lowercased() == emailLower }
                        }
                        if !matchEmailArray, let arr = data["participants"] as? [[String: Any]] {
                            matchEmailArray = arr.contains { ((($0["email"] as? String)?.lowercased() ?? "") == emailLower) }
                        }
                        if !matchEmailArray, let arr = data["attendees"] as? [[String: Any]] {
                            matchEmailArray = arr.contains { ((($0["email"] as? String)?.lowercased() ?? "") == emailLower) }
                        }
                        
                        if uid == nil || uid!.isEmpty {
                            allowed = allowed && (matchEmailField || matchEmailArray)
                        } else {
                            allowed = allowed || (matchEmailField || matchEmailArray)
                        }
                    }
                    
                    if (uid != nil && !(uid!.isEmpty)) || (email != nil && !(email!.isEmpty)) {
                        return allowed
                    }
                    return true
                }
                
                self.events = filteredDocs.compactMap { self.mapEvent(from: $0.data(), documentId: $0.documentID) }
            }
        }
    }
    
    func fetchEventsForClient(userUid uid: String?, userEmail email: String?, clientName: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        db.collection("events").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching events: \(error.localizedDescription)"
                    return
                }
                let documents = snapshot?.documents ?? []
                let filteredDocs = documents.filter { document in
                    let data = document.data()
                    
                    var allowed = true
                    
                    if let uid = uid, !uid.isEmpty {
                        let uidKeys = ["clientUid", "clientUID", "clientId", "customerUid", "customerUID", "customerId"]
                        let matchUid = uidKeys.contains { (data[$0] as? String) == uid }
                        allowed = allowed && matchUid
                    }
                    
                    if let email = email, !email.isEmpty {
                        let emailLower = email.lowercased()
                        let emailKeys = ["clientEmail", "customerEmail", "createdByEmail"]
                        let matchEmailField = emailKeys.contains { ((data[$0] as? String)?.lowercased() ?? "") == emailLower }
                        
                        var matchEmailArray = false
                        if let arr = data["participants"] as? [String] {
                            matchEmailArray = arr.contains { $0.lowercased() == emailLower }
                        }
                        if !matchEmailArray, let arr = data["attendees"] as? [String] {
                            matchEmailArray = arr.contains { $0.lowercased() == emailLower }
                        }
                        if !matchEmailArray, let arr = data["participants"] as? [[String: Any]] {
                            matchEmailArray = arr.contains { ((($0["email"] as? String)?.lowercased() ?? "") == emailLower) }
                        }
                        if !matchEmailArray, let arr = data["attendees"] as? [[String: Any]] {
                            matchEmailArray = arr.contains { ((($0["email"] as? String)?.lowercased() ?? "") == emailLower) }
                        }
                        
                        if uid == nil || uid!.isEmpty {
                            allowed = allowed && (matchEmailField || matchEmailArray)
                        } else {
                            allowed = allowed || (matchEmailField || matchEmailArray)
                        }
                    }
                    
                    if let cName = clientName, !cName.isEmpty {
                        let cn = cName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let nameKeys = ["clientName", "ClientName", "cLientName", "customerName", "client"]
                        let matchNameField = nameKeys.contains { ((data[$0] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "") == cn }
                        var matchNameArray = false
                        if let arr = data["participants"] as? [String] {
                            matchNameArray = arr.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cn }
                        }
                        if !matchNameArray, let arr = data["attendees"] as? [String] {
                            matchNameArray = arr.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cn }
                        }
                        if (uid == nil || uid!.isEmpty) && (email == nil || email!.isEmpty) {
                            allowed = allowed && (matchNameField || matchNameArray)
                        } else {
                            allowed = allowed || (matchNameField || matchNameArray)
                        }
                    }
                    
                    if (uid != nil && !(uid!.isEmpty)) || (email != nil && !(email!.isEmpty)) || (clientName != nil && !(clientName!.isEmpty)) {
                        return allowed
                    }
                    return true
                }
                
                self.events = filteredDocs.compactMap { self.mapEvent(from: $0.data(), documentId: $0.documentID) }
            }
        }
    }
    
    // MARK: - Create Task (save to '/tasks')
    func createTask(_ task: Task, assignedUid uid: String? = nil, assignedEmail email: String? = nil, subtaskItems: [SubTaskItem]? = nil, completion: ((Bool) -> Void)? = nil) {
        let statusString: String = {
            switch task.status {
            case .completed: return "Done"
            case .inProgress: return "In Progress"
            case .notStarted: return "To-Do"
            case .stuck: return "Stuck"
            case .waitingFor: return "Waiting For"
            case .onHoldByClient: return "Hold by Client"
            case .needHelp: return "Need Help"
            case .canceled: return "Canceled"
            }
        }()
        let priorityString: String = {
            switch task.priority {
            case .p1: return "High"
            case .p2: return "Medium"
            case .p3: return "Low"
            }
        }()
        var data: [String: Any] = [
            "title": task.title,
            "description": task.description,
            "status": statusString,
            "priority": priorityString,
            "startDate": Timestamp(date: task.startDate),
            "assignedDate": Timestamp(date: task.startDate),
            "dueDate": Timestamp(date: task.dueDate),
            "assignedToName": task.assignedTo,
            "taskType": {
                switch task.taskType {
                case .selfTask: return "self"
                case .adminTask: return "admin"
                case .clientAssigned: return "client"
                }
            }(),
            "createdAt": Timestamp(date: Date())
        ]
        if let docId = task.project?.documentId { data["projectId"] = docId }
        if let projName = task.project?.name { data["projectName"] = projName }
        if let uid = uid { data["assigneeId"] = uid; data["assignedUid"] = uid; data["assignedUID"] = uid }
        if let email = email { data["assignedEmail"] = email; data["createdByEmail"] = email }
        if let uid = uid { data["createdByUid"] = uid }
        
        // Backward compatibility: still save string if provided, though we prefer subtaskItems
        if let s = task.subtask?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            data["subtask"] = s
        }
        if let w = task.weightage?.trimmingCharacters(in: .whitespacesAndNewlines), !w.isEmpty {
            data["weightage"] = w
        }
        
        var ref: DocumentReference? = nil
        ref = db.collection("tasks").addDocument(data: data) { error in
            if let error = error {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            if let items = subtaskItems, !items.isEmpty, let docId = ref?.documentID {
                self.addSubtasks(to: docId, subtasks: items) { success in
                    DispatchQueue.main.async { completion?(success) }
                }
            } else {
                DispatchQueue.main.async { completion?(true) }
            }
        }
    }

    // MARK: - Subtask Management
    func addSubtasks(to taskId: String, subtasks: [SubTaskItem], completion: @escaping (Bool) -> Void) {
        let batch = db.batch()
        let subtasksRef = db.collection("tasks").document(taskId).collection("subtasks")
        
        for item in subtasks {
            let docRef = subtasksRef.document(item.id)
            let data: [String: Any] = [
                "id": item.id,
                "title": item.title,
                "description": item.description,
                "isCompleted": item.isCompleted,
                "status": item.status.rawValue,
                "priority": item.priority.rawValue,
                "createdAt": Timestamp(date: item.createdAt),
                "assignedDate": Timestamp(date: item.assignedDate),
                "dueDate": Timestamp(date: item.dueDate),
                "assignedTo": item.assignedTo ?? ""
            ]
            batch.setData(data, forDocument: docRef)
        }
        
        batch.commit { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }

    func fetchTaskLegacySubtaskString(title: String, projectId: String?, completion: @escaping (String?) -> Void) {
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        query.getDocuments { snapshot, error in
            let str = snapshot?.documents.first?.data()["subtask"] as? String
            DispatchQueue.main.async { completion(str) }
        }
    }
    
    func updateTaskLegacySubtaskString(title: String, projectId: String?, subtaskString: String?, completion: @escaping (Bool) -> Void) {
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        query.getDocuments { snapshot, error in
            guard let doc = snapshot?.documents.first else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            doc.reference.updateData(["subtask": subtaskString ?? ""]) { error in
                DispatchQueue.main.async { completion(error == nil) }
            }
        }
    }

    func fetchSubtasks(taskTitle: String, taskProjectId: String?, completion: @escaping ([SubTaskItem]) -> Void) {
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: taskTitle)
        if let pid = taskProjectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        query.getDocuments { snapshot, error in
            guard let doc = snapshot?.documents.first else {
                completion([])
                return
            }
            
            doc.reference.collection("subtasks").order(by: "createdAt").getDocuments { subSnap, subErr in
                DispatchQueue.main.async {
                    if let _ = subErr {
                        completion([])
                        return
                    }
                    
                    let items: [SubTaskItem] = subSnap?.documents.compactMap { doc in
                        let data = doc.data()
                        guard let title = data["title"] as? String else { return nil }
                        let id = data["id"] as? String ?? doc.documentID
                        let description = data["description"] as? String ?? ""
                        let isCompleted = data["isCompleted"] as? Bool ?? false
                        let statusRaw = data["status"] as? String ?? "TODO"
                        let status = TaskStatus(rawValue: statusRaw) ?? .notStarted
                        let priorityRaw = data["priority"] as? String ?? "P2"
                        let priority = Priority(rawValue: priorityRaw) ?? .p2
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        let assignedDate = (data["assignedDate"] as? Timestamp)?.dateValue() ?? Date()
                        let dueDate = (data["dueDate"] as? Timestamp)?.dateValue() ?? Date()
                        let assignedTo = data["assignedTo"] as? String
                        
                        return SubTaskItem(
                            id: id,
                            title: title,
                            description: description,
                            isCompleted: isCompleted,
                            status: status,
                            priority: priority,
                            createdAt: createdAt,
                            assignedDate: assignedDate,
                            dueDate: dueDate,
                            assignedTo: assignedTo
                        )
                    } ?? []
                    completion(items)
                }
            }
        }
    }

    func updateSubtaskStatus(taskTitle: String, taskProjectId: String?, subtaskId: String, status: TaskStatus, completion: ((Bool) -> Void)? = nil) {
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: taskTitle)
        if let pid = taskProjectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        query.getDocuments { snapshot, error in
            guard let doc = snapshot?.documents.first else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            doc.reference.collection("subtasks").document(subtaskId).updateData([
                "status": status.rawValue
            ]) { error in
                DispatchQueue.main.async {
                    completion?(error == nil)
                }
            }
        }
    }
    
    func updateSelfSubtaskStatus(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, subtaskId: String, to status: TaskStatus, completion: ((Bool) -> Void)? = nil) {
         // Logic for self tasks if they support subtasks in future.
         // currently just a placeholder or similar logic to updateSubtaskStatus but on selfTasks collection
         // Implementation depends on where selfTasks are stored.
         // Assuming self tasks also support subcollection if we want consistent behavior.
         // For now, let's assume we use the main logic for tasks, but selfTasks might be different.
         // If CreateTaskView saves self tasks via saveSelfTask, we need to check if that supports subcollections.
         // ...
         
         // For now, I'll implement a query similar to updateSubtaskStatus but targeting selfTasks collection/logic.
         // Reusing updateSelfTaskStatus logic to find the document.
         
         let clamped = status.rawValue
         var query: Query = self.db.collection("selfTasks").whereField("title", isEqualTo: title)
         if let pid = projectId, !pid.isEmpty { query = query.whereField("projectId", isEqualTo: pid) }
         
         let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "clientId", "clientUid", "clientUID", "userUid", "userUID"]
         let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail", "clientEmail", "userEmail"]
         
         query.getDocuments { snapshot, _ in
             let docs = snapshot?.documents ?? []
             let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                 let data = doc.data()
                 var uidMatched = false
                 if let uid = uid, !uid.isEmpty { uidMatched = uidKeys.contains { (data[$0] as? String) == uid } }
                 var emailMatched = false
                 if let email = userEmail, !email.isEmpty { emailMatched = emailKeys.contains { (data[$0] as? String) == email } }
                 if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) { return uidMatched || emailMatched }
                 if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                 if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                 return true
             }
             
             guard let doc = filtered.first else {
                 DispatchQueue.main.async { completion?(false) }
                 return
             }
             
             
             doc.reference.collection("subtasks").document(subtaskId).updateData(["status": clamped]) { err in
                 DispatchQueue.main.async { completion?(err == nil) }
             }
         }
    }
    
    // MARK: - Delete Subtask with Lookup
    func deleteSubtask(taskTitle: String, taskProjectId: String?, subtaskId: String, completion: ((Bool) -> Void)? = nil) {
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: taskTitle)
        if let pid = taskProjectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        query.getDocuments { snapshot, error in
            guard let doc = snapshot?.documents.first else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            doc.reference.collection("subtasks").document(subtaskId).delete { error in
                DispatchQueue.main.async {
                    completion?(error == nil)
                }
            }
        }
    }

    func deleteSelfSubtask(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, subtaskId: String, completion: ((Bool) -> Void)? = nil) {
         var query: Query = self.db.collection("selfTasks").whereField("title", isEqualTo: title)
         if let pid = projectId, !pid.isEmpty { query = query.whereField("projectId", isEqualTo: pid) }
         
         let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "clientId", "clientUid", "clientUID", "userUid", "userUID"]
         let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail", "clientEmail", "userEmail"]
         
         query.getDocuments { snapshot, _ in
             let docs = snapshot?.documents ?? []
             let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                 let data = doc.data()
                 var uidMatched = false
                 if let uid = uid, !uid.isEmpty { uidMatched = uidKeys.contains { (data[$0] as? String) == uid } }
                 var emailMatched = false
                 if let email = userEmail, !email.isEmpty { emailMatched = emailKeys.contains { (data[$0] as? String) == email } }
                 if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) { return uidMatched || emailMatched }
                 if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                 if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                 return true
             }
             
             guard let doc = filtered.first else {
                 DispatchQueue.main.async { completion?(false) }
                 return
             }
             
             doc.reference.collection("subtasks").document(subtaskId).delete { err in
                 DispatchQueue.main.async { completion?(err == nil) }
             }
         }
    }
    
    func addCommentToTask(taskTitle: String, taskProjectId: String?, message: String, user: String, completion: @escaping (Bool) -> Void) {
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: taskTitle)
        if let pid = taskProjectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        query.getDocuments { snapshot, error in
            guard let doc = snapshot?.documents.first else {
                print("❌ Task not found for commenting")
                completion(false)
                return
            }
            
            let timestamp = Timestamp(date: Date())
            let commentDict: [String: Any] = [
                "user": user,
                "message": message,
                "timestamp": timestamp
            ]
            
            let batch = self.db.batch()
            let docRef = doc.reference
            
            // 1. Add to comments array in the Task document (Display & Persistence)
            batch.updateData([
                "comments": FieldValue.arrayUnion([commentDict])
            ], forDocument: docRef)
            
            // 2. Add as a new document in 'activities' subcollection (Audit/History)
            let activityRef = docRef.collection("activities").document()
            let activityData: [String: Any] = [
                "type": "comment",
                "user": user,
                "message": message,
                "timestamp": timestamp,
                "createdAt": timestamp
            ]
            batch.setData(activityData, forDocument: activityRef)
            
            batch.commit { err in
                if let err = err {
                    print("❌ Error adding comment: \(err.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    func updateTask(oldTitle: String, oldProjectId: String?, forUserUid uid: String?, userEmail: String?, with updatedTask: Task, statusLabel: String, completion: ((Int) -> Void)? = nil) {
        let defaultStatus: String = {
            switch updatedTask.status {
            case .completed: return "Done"
            case .inProgress: return "In Progress"
            case .notStarted: return "To-Do"
            case .stuck: return "Stuck"
            case .waitingFor: return "Waiting For"
            case .onHoldByClient: return "Hold by Client"
            case .needHelp: return "Need Help"
            case .canceled: return "Canceled"
            }
        }()
        let trimmedLabel = statusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusString = trimmedLabel.isEmpty ? defaultStatus : trimmedLabel
        let priorityString: String = {
            switch updatedTask.priority {
            case .p1: return "High"
            case .p2: return "Medium"
            case .p3: return "Low"
            }
        }()
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: oldTitle)
        if let pid = oldProjectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail"]
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                let data = doc.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            let targetDocs = filtered.isEmpty ? docs : filtered
            let group = DispatchGroup()
            var updatedCount = 0
            
            // Determine actor name
            let actorName: String = {
                if let email = userEmail, !email.isEmpty { return "Super Admin" } // Or parse email? Request implies "Super admin edited"
                if let user = Auth.auth().currentUser {
                   // If user is logged in, use their name if possible, or default
                   return user.displayName ?? "Super Admin"
                }
                return "Super Admin"
            }()
            
            for d in targetDocs {
                group.enter()
                
                // --- Change Detection & Activity Logging ---
                let currentData = d.data()
                
                // Status
                if let oldStatus = currentData["status"] as? String, oldStatus != statusString {
                    let activity = ActivityItem(user: actorName, action: "changed status to", message: statusString, timestamp: Date(), type: "update")
                    self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                }
                
                // Priority
                if let oldPriority = currentData["priority"] as? String, oldPriority != priorityString {
                    let activity = ActivityItem(user: actorName, action: "changed priority to", message: priorityString, timestamp: Date(), type: "update")
                    self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                }
                
                // Assignee
                let oldAssignee = currentData["assignedToName"] as? String ?? "Unassigned"
                if oldAssignee != updatedTask.assignedTo {
                    let actionMsg = updatedTask.assignedTo == "Unassigned" ? "removed assignee" : "reassigned to"
                    let msg = updatedTask.assignedTo == "Unassigned" ? oldAssignee : updatedTask.assignedTo
                    let activity = ActivityItem(user: actorName, action: actionMsg, message: msg, timestamp: Date(), type: "update")
                    self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                }
                
                // Title
                if let oldTitleVal = currentData["title"] as? String, oldTitleVal != updatedTask.title {
                   let activity = ActivityItem(user: actorName, action: "renamed task to", message: updatedTask.title, timestamp: Date(), type: "update")
                   self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                }
                
                // Description (Optional: only log if changed significantly? or just "updated description")
                let oldDesc = currentData["description"] as? String ?? ""
                if oldDesc != updatedTask.description {
                    let activity = ActivityItem(user: actorName, action: "updated description", message: nil, timestamp: Date(), type: "update")
                    self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                }
                
                // Subtasks
                let oldSub = currentData["subtask"] as? String ?? ""
                let newSub = updatedTask.subtask ?? ""
                if oldSub != newSub {
                    // Logic to see if just checked? 
                    // For now simple log
                     let activity = ActivityItem(user: actorName, action: "updated subtasks", message: nil, timestamp: Date(), type: "update")
                     self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                }
                
                // -------------------------------------------

                var data: [String: Any] = [
                    "title": updatedTask.title,
                    "description": updatedTask.description,
                    "status": statusString,
                    "priority": priorityString,
                    "startDate": Timestamp(date: updatedTask.startDate),
                    "assignedDate": Timestamp(date: updatedTask.startDate),
                    "dueDate": Timestamp(date: updatedTask.dueDate),
                    "assignedToName": updatedTask.assignedTo,
                    "taskType": {
                        switch updatedTask.taskType {
                        case .selfTask: return "self"
                        case .adminTask: return "admin"
                        case .clientAssigned: return "client"
                        }
                    }(),
                    "updatedAt": Timestamp(date: Date())
                ]
                if let docId = updatedTask.project?.documentId { data["projectId"] = docId }
                if let projName = updatedTask.project?.name { data["projectName"] = projName }
                if let uid = uid, !uid.isEmpty {
                    data["assigneeId"] = uid
                    data["assignedUid"] = uid
                    data["assignedUID"] = uid
                    data["createdByUid"] = uid
                }
                if let email = userEmail, !email.isEmpty {
                    data["assignedEmail"] = email
                    data["createdByEmail"] = email
                }
                if let s = updatedTask.subtask?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                    data["subtask"] = s
                } else {
                     data["subtask"] = "" // Ensure cleared if empty
                }
                if let w = updatedTask.weightage?.trimmingCharacters(in: .whitespacesAndNewlines), !w.isEmpty {
                    data["weightage"] = w
                }
                
                // Note: We shouldn't necessarily overwrite comments array if we are using subcollection now,
                // but for backward compatibility we keep it. 
                // However, updatedTask.comments might be stale if we only fetched task once.
                // If we want to strictly use subcollection for new activity, maybe we stop updating this array or merge?
                // The current implementation takes `updatedTask.comments` which comes from local state.
                // Local state `Task` has comments.
                // If `TaskDetailView` adds comments locally, they are in `updatedTask`.
                // Use existing logic for now.
                
                let commentsData = updatedTask.comments.map { [
                    "user": $0.user,
                    "message": $0.message,
                    "timestamp": Timestamp(date: $0.timestamp)
                ] }
                data["comments"] = commentsData
                
                d.reference.updateData(data) { _ in
                    updatedCount += 1
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion?(updatedCount)
            }
        }
    }
    
    func updateTaskAssignee(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, toNewAssigneeEmail newEmail: String, newAssigneeName: String, completion: ((Int) -> Void)? = nil) {
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        // Strategy: find the task document(s) matching title+project
        // We generally expect unique tasks per project/title pair, but the existing code handles duplicates via loop.
        
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            let group = DispatchGroup()
            var updatedCount = 0
            
            for d in docs {
                group.enter()
                // Update all possible assignee fields to keep consistency
                d.reference.updateData([
                    "assignedEmail": newEmail,
                    "assigneeEmail": newEmail,
                    "createdByEmail": newEmail, // In some contexts, creator is treated as assignee, but be careful.
                    // For safety, let's stick to standard assignee fields as per other methods:
                    "assignedToName": newAssigneeName,
                    
                    // We might not know the new UID here unless we looked it up first, 
                    // but we can at least clear the old UID or rely on email which seems to be the primary key in some views.
                    // If we want to be thorough, we should probably look up the UID for the email.
                    // For now, let's assume Email is the source of truth for display.
                    
                    "updatedAt": Timestamp(date: Date())
                ]) { _ in
                    updatedCount += 1
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                completion?(updatedCount)
            }
        }
    }

    func updateTaskStatus(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, to newStatus: TaskStatus, comment: String? = nil, completion: ((Int) -> Void)? = nil) {
        let statusString = newStatus.rawValue
        
        let actorName: String = {
            if let user = Auth.auth().currentUser { return user.displayName ?? "User" }
            return "System"
        }()
        
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail"]
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            var updated = 0
            let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                let data = doc.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            // If no identity-based docs matched, fallback
            let targetDocs = filtered.isEmpty ? docs : filtered
            
            let group = DispatchGroup()
            for d in targetDocs {
                group.enter()
                
                var updates: [String: Any] = [
                    "status": statusString,
                    "updatedAt": Timestamp(date: Date())
                ]
                
                if let commentText = comment, !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let commentData: [String: Any] = [
                        "id": UUID().uuidString,
                        "user": actorName,
                        "message": commentText,
                        "timestamp": Timestamp(date: Date())
                    ]
                    updates["comments"] = FieldValue.arrayUnion([commentData])
                }
                
                d.reference.updateData(updates) { _ in
                    // Log Activity
                    let activity = ActivityItem(user: actorName, action: "changed status to", message: statusString, type: "status")
                    self.addTaskActivity(taskId: d.documentID, activity: activity) { _ in }
                    
                    updated += 1
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion?(updated)
            }
        }
    }
    
    // MARK: - Subtask Status (main tasks)
    func updateSubtaskStatus(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, to newStatus: TaskStatus, completion: ((Int) -> Void)? = nil) {
        let statusString = newStatus.rawValue
        
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail"]
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            var updated = 0
            let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                let data = doc.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            let targetDocs = filtered.isEmpty ? docs : filtered
            let group = DispatchGroup()
            for d in targetDocs {
                group.enter()
                d.reference.updateData([
                    "subtaskStatus": statusString,
                    "updatedAt": Timestamp(date: Date())
                ]) { _ in
                    updated += 1
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion?(updated)
            }
        }
    }
    
    // MARK: - Task Activities
    func findTaskDocumentId(title: String, projectId: String?, completion: @escaping (String?) -> Void) {
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        query.limit(to: 1).getDocuments { snapshot, error in
            completion(snapshot?.documents.first?.documentID)
        }
    }

    func listenToTaskActivities(taskId: String, completion: @escaping ([ActivityItem]) -> Void) -> ListenerRegistration {
        // Target 'comments' collection as requested
        return db.collection("tasks").document(taskId).collection("comments")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                var items = documents.compactMap { doc -> ActivityItem? in
                    let data = doc.data()
                    
                    // Map fields from "comments" collection schema (userName, text)
                    let user = data["userName"] as? String ?? data["user"] as? String ?? "Unknown"
                    let message = data["text"] as? String ?? data["message"] as? String
                    
                    // Allow dynamic action and type if present
                    let action = data["action"] as? String ?? "commented"
                    let type = data["type"] as? String ?? "comment"
                    
                    // Handle Date Parsing (Timestamp or String)
                    var date = Date()
                    if let ts = data["createdAt"] as? Timestamp {
                        date = ts.dateValue()
                    } else if let dateStr = data["createdAt"] as? String {
                        // Try parsing specific format: "January 5, 2026 at 6:39:04 PM UTC+5:30"
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a zzz"
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        if let d = formatter.date(from: dateStr) {
                            date = d
                        } else {
                            // Fallbacks
                            let iso = ISO8601DateFormatter()
                            if let d = iso.date(from: dateStr) { date = d }
                        }
                    }
                    
                    return ActivityItem(
                        id: doc.documentID,
                        user: user,
                        action: action,
                        message: message,
                        timestamp: date,
                        type: type
                    )
                }
                
                // Sort client-side
                items.sort { $0.timestamp < $1.timestamp }
                
                completion(items)
            }
    }
    
    func addTaskActivity(taskId: String, activity: ActivityItem, completion: @escaping (Error?) -> Void) {
        let data: [String: Any] = [
            "userName": activity.user, // Schema: userName
            "text": activity.message ?? "", // Schema: text
            "action": activity.action, // New field
            "type": activity.type, // New field
            "createdAt": Timestamp(date: activity.timestamp),
            "userId": activity.user == "Super Admin" ? "admin_uid" : "unknown" // Optional placeholder
        ]
        
        db.collection("tasks").document(taskId).collection("comments").addDocument(data: data) { error in
            completion(error)
        }
    }
    
    func clearTaskActivities(taskId: String, completion: @escaping (Bool) -> Void) {
        let col = db.collection("tasks").document(taskId).collection("comments")
        col.getDocuments { snapshot, error in
            guard let docs = snapshot?.documents, !docs.isEmpty else {
                completion(true)
                return
            }
            
            let batch = self.db.batch()
            for doc in docs {
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("Error clearing history: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Fetch Tasks for current user (listener)
    func fetchTasks(forUserUid uid: String?, userEmail: String?, userName: String? = nil) {
        isLoading = true
        errorMessage = nil
        db.collection("tasks").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching tasks: \(error.localizedDescription)"
                    return
                }
                let docs = snapshot?.documents ?? []
                func matchesUser(data: [String: Any], uid: String?, email rawEmail: String?, name: String?) -> Bool {
                    // If we don't know the user, accept all
                    let hasUid = uid != nil && !(uid!.isEmpty)
                    let trimmedEmail = rawEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let hasEmail = !trimmedEmail.isEmpty
                    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let hasName = !trimmedName.isEmpty
                    
                    if !hasUid && !hasEmail && !hasName { return true }
                    
                    // Strict assignment check only

                    
                    var isAssignedToCurrent = true
                    var checksPerformed = false
                    
                    if hasUid {
                        checksPerformed = true
                        let uidKeys = [
                            "assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId",
                            "clientId", "clientUid", "clientUID", "createdByUid"
                        ]
                        let uidArrayKeys = ["assignedIds", "assignedUIDs", "assignedUids", "assigneeIds", "employeeIds"]
                        let matchUid = uidKeys.contains { (data[$0] as? String) == uid }
                        let matchUidArr = uidArrayKeys.contains { key in
                            if let arr = data[key] as? [String] { return arr.contains(uid!) }
                            return false
                        }
                        if matchUid || matchUidArr { return true }
                        // If strict UID check failed, continue to other checks?
                        // Original logic was convoluted. Simplified: if any match, return true.
                        isAssignedToCurrent = false
                    }
                    
                    if hasEmail {
                        checksPerformed = true
                        let emailLower = trimmedEmail.lowercased()
                        let emailKeys = ["assignedEmail", "assigneeEmail", "clientEmail", "createdByEmail"]
                        let matchEmail = emailKeys.contains {
                            ((data[$0] as? String)?
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .lowercased() ?? "") == emailLower
                        }
                        if matchEmail { return true }
                    }
                    
                    if hasName {
                        checksPerformed = true
                        let nameLower = trimmedName.lowercased()
                        let nameKeys = ["assigneeName", "assignedName", "assignedEmployeeName", "employeeName", "createdByName", "clientName"]
                        let matchName = nameKeys.contains {
                             ((data[$0] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "") == nameLower
                        }
                        // Also check array
                        let nameArrayKeys = ["assignedNames", "assigneeNames"]
                        let matchNameArr = nameArrayKeys.contains { key in
                             if let arr = data[key] as? [String] {
                                 return arr.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == nameLower }
                             }
                             return false
                        }
                        
                        if matchName || matchNameArr { return true }
                    }
                    
                    // Fallback scan if strict checks failed but we still haven't returned true
                    // Only do fallback if we haven't confirmed a match yet.
                    
                    // Re-implement fallback specific to Email as originally intending, or expand?
                    // Provided code had email fallback.
                     var emailLower: String? = hasEmail ? trimmedEmail.lowercased() : nil
                     if let emailLower = emailLower {
                            for value in data.values {
                                if let s = value as? String {
                                    if s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == emailLower {
                                        return true
                                    }
                                } else if let arr = value as? [String] {
                                    if arr.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == emailLower }) {
                                        return true
                                    }
                                } else if let arr = value as? [[String: Any]] {
                                    for obj in arr {
                                        for v in obj.values {
                                            if let s = v as? String,
                                               s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == emailLower {
                                                return true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    
                    return false
                }
                
                self.tasks = docs.compactMap { doc in
                    let data = doc.data()
                    if !matchesUser(data: data, uid: uid, email: userEmail, name: userName) {
                        return nil
                    }
                    return self.mapTask(from: data, defaultType: .adminTask)
                }
            }
        }
    }
    
    // MARK: - Fetch Tasks for a Project
    func fetchTasks(forProjectId projectId: String) {
        db.collection("tasks").addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error fetching tasks: \(error.localizedDescription)"
                    return
                }
                guard let documents = querySnapshot?.documents else {
                    self.tasks = []
                    return
                }
                self.tasks = documents.compactMap { document -> Task? in
                    let data = document.data()
                    let taskProjectId = data["projectId"] as? String ?? ""
                    if taskProjectId != projectId { return nil }
                    return self.mapTask(from: data, defaultType: .selfTask)
                }
            }
        }
    }
    
    // MARK: - Fetch All Admin Tasks (unfiltered)
    func fetchAdminTasks(completion: @escaping ([Task]) -> Void) {
        db.collection("adminTasks").addSnapshotListener { snapshot, error in
            if let _ = error { completion([]); return }
            let tasks = snapshot?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .adminTask) } ?? []
            completion(tasks)
        }
    }
    
    // MARK: - Fetch tasks assigned to a specific user
    // Tries UID fields first, then falls back to email
    func fetchTasksAssigned(toUserUid uid: String?, userEmail: String?, completion: @escaping ([Task]) -> Void) {
        func finishOrFallback(_ currentResults: [Task]) {
            if !currentResults.isEmpty { completion(currentResults); return }
            guard let email = userEmail, !email.isEmpty else { completion([]); return }
            self.queryTasksByEmail(email: email, completion: completion)
        }
        
        if let uid = uid, !uid.isEmpty {
            let uidKeys = ["assignedId", "assignedUID", "assignedUid", "assigneeId", "employeeId"]
            let uidArrayKeys = ["assignedIds", "assignedUIDs", "assignedUids", "assigneeIds", "employeeIds"]
            var results: [Task] = []
            var seenIds = Set<String>()
            var idx = 0
            var arrIdx = 0
            func queryNext() {
                if idx < uidKeys.count {
                    let key = uidKeys[idx]
                    idx += 1
                    db.collection("tasks").whereField(key, isEqualTo: uid).getDocuments { snapshot, _ in
                        let docs = snapshot?.documents ?? []
                        for doc in docs {
                            let id = doc.documentID
                            if !seenIds.contains(id) {
                                seenIds.insert(id)
                                if let task = self.mapTask(from: doc.data(), defaultType: .adminTask) {
                                    results.append(task)
                                }
                            }
                        }
                        queryNext()
                    }
                    return
                }
                if arrIdx < uidArrayKeys.count {
                    let key = uidArrayKeys[arrIdx]
                    arrIdx += 1
                    db.collection("tasks").whereField(key, arrayContains: uid).getDocuments { snapshot, _ in
                        let docs = snapshot?.documents ?? []
                        for doc in docs {
                            let id = doc.documentID
                            if !seenIds.contains(id) {
                                seenIds.insert(id)
                                if let task = self.mapTask(from: doc.data(), defaultType: .adminTask) {
                                    results.append(task)
                                }
                            }
                        }
                        queryNext()
                    }
                    return
                }
                finishOrFallback(results)
            }
            queryNext()
            return
        }
        // No UID
        finishOrFallback([])
    }
    
    private func queryTasksByEmail(email: String, completion: @escaping ([Task]) -> Void) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailLower = trimmed.lowercased()
        
        // First try fast query on assignedEmail
        db.collection("tasks").whereField("assignedEmail", isEqualTo: trimmed).getDocuments { snapshot, _ in
            let directResults = snapshot?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .adminTask) } ?? []
            if !directResults.isEmpty {
                completion(directResults)
                return
            }
            
            // Fallback: scan all tasks client-side and match email across common fields/arrays
            self.db.collection("tasks").getDocuments { allSnapshot, _ in
                let docs = allSnapshot?.documents ?? []
                let results: [Task] = docs.compactMap { doc in
                    let data = doc.data()
                    
                    // Common email fields first
                    let emailKeys = ["assignedEmail", "assigneeEmail", "employeeEmail", "userEmail", "createdByEmail", "email"]
                    let quickMatch = emailKeys.contains {
                        ((data[$0] as? String)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased() ?? "") == emailLower
                    }
                    if quickMatch {
                        return self.mapTask(from: data, defaultType: .adminTask)
                    }
                    
                    // Deep scan: any string, [String], or [[String: Any]] containing the email
                    var found = false
                    for value in data.values {
                        if let s = value as? String {
                            if s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == emailLower {
                                found = true
                                break
                            }
                        } else if let arr = value as? [String] {
                            if arr.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == emailLower }) {
                                found = true
                                break
                            }
                        } else if let arr = value as? [[String: Any]] {
                            outer: for obj in arr {
                                for v in obj.values {
                                    if let s = v as? String,
                                       s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == emailLower {
                                        found = true
                                        break outer
                                    }
                                }
                            }
                        }
                    }
                    
                    guard found else { return nil }
                    return self.mapTask(from: data, defaultType: .adminTask)
                }
                completion(results)
            }
        }
    }
    
    // MARK: - Fetch tasks assigned to a specific user for a project
    func fetchTasksAssignedForProject(projectId: String, toUserUid uid: String?, userEmail: String?, completion: @escaping ([Task]) -> Void) {
        // Helper: query by UID key with projectId
        func queryByUidKey(_ key: String, uid: String, completion: @escaping ([Task]) -> Void) {
            db.collection("tasks")
                .whereField("projectId", isEqualTo: projectId)
                .whereField(key, isEqualTo: uid)
                .getDocuments { snapshot, _ in
                    let results = snapshot?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .adminTask) } ?? []
                    completion(results)
                }
        }
        
        if let uid = uid, !uid.isEmpty {
            let uidKeys = ["assignedId", "assignedUID", "assignedUid", "assigneeId", "employeeId"]
            var aggregated: [Task] = []
            var index = 0
            func next() {
                if index >= uidKeys.count {
                    if !aggregated.isEmpty { completion(aggregated); return }
                    // Fallback to email if nothing found
                    if let email = userEmail, !email.isEmpty {
                        db.collection("tasks")
                            .whereField("projectId", isEqualTo: projectId)
                            .whereField("assignedEmail", isEqualTo: email)
                            .getDocuments { snapshot, _ in
                                let results = snapshot?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .adminTask) } ?? []
                                completion(results)
                            }
                    } else {
                        completion([])
                    }
                    return
                }
                let key = uidKeys[index]
                index += 1
                queryByUidKey(key, uid: uid) { results in
                    aggregated.append(contentsOf: results)
                    next()
                }
            }
            next()
            return
        }
        
        // No UID, try email only
        if let email = userEmail, !email.isEmpty {
            db.collection("tasks")
                .whereField("projectId", isEqualTo: projectId)
                .whereField("assignedEmail", isEqualTo: email)
                .getDocuments { snapshot, _ in
                    let results = snapshot?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .adminTask) } ?? []
                    completion(results)
                }
            return
        }
        
        completion([])
    }
    
    func saveSelfTask(task: Task, createdByUid uid: String?, createdByEmail email: String?, completion: @escaping (Bool) -> Void) {
        let statusString: String = {
            switch task.status {
            case .completed: return "Done"
            case .inProgress: return "In Progress"
            case .notStarted: return "To-Do"
            case .stuck: return "Stuck"
            case .waitingFor: return "Waiting For"
            case .onHoldByClient: return "Hold by Client"
            case .needHelp: return "Need Help"
            case .canceled: return "Canceled"
            }
        }()
        let priorityString: String = {
            switch task.priority {
            case .p1: return "High"
            case .p2: return "Medium"
            case .p3: return "Low"
            }
        }()
        var data: [String: Any] = [
            "title": task.title,
            "description": task.description,
            "status": statusString,
            "priority": priorityString,
            // Firestore docs often use assignedDate for self tasks
            "assignedDate": Timestamp(date: task.startDate),
            "dueDate": Timestamp(date: task.dueDate),
            "assignedToName": task.assignedTo,
            "assigneeType": "user",
            "taskType": "self",
            "createdAt": Timestamp(date: Date())
        ]
        if let docId = task.project?.documentId {
            data["projectId"] = docId
        }
        if let email = email { data["createdByEmail"] = email }
        if let uid = uid { data["createdByUid"] = uid; data["assigneeId"] = uid }
        if let s = task.subtask?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            data["subtask"] = s
        }
        if let w = task.weightage?.trimmingCharacters(in: .whitespacesAndNewlines), !w.isEmpty {
            data["weightage"] = w
        }
        
        // Save to top-level selfTasks collection (1 doc per task)
        db.collection("selfTasks").addDocument(data: data) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    func fetchSelfTasks(forUserUid uid: String?, userEmail: String?, completion: @escaping ([Task]) -> Void) {
        // Aggregate results from several possible locations and field names
        func dedup(_ arrs: [[Task]]) -> [Task] {
            var seen = Set<String>()
            var out: [Task] = []
            for arr in arrs {
                for t in arr {
                    let key = t.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + "|" + String(Int(t.dueDate.timeIntervalSince1970))
                    if !seen.contains(key) {
                        seen.insert(key)
                        out.append(t)
                    }
                }
            }
            return out
        }
        
        var topAssignee: [Task] = []
        var topCreated: [Task] = []
        var topAssignedId: [Task] = []
        var topAssignedUID: [Task] = []
        var topAssignedUid: [Task] = []
        var topEmployeeId: [Task] = []
        var emailCreated: [Task] = []
        var nestedTasks: [Task] = []
        var nestedSelfTasks: [Task] = []
        
        func emit() {
            let merged = dedup([topAssignee, topCreated, topAssignedId, topAssignedUID, topAssignedUid, topEmployeeId, emailCreated, nestedTasks, nestedSelfTasks])
            DispatchQueue.main.async { completion(merged) }
        }
        
        if let uid = uid, !uid.isEmpty {
            // Top-level variations
            db.collection("selfTasks").whereField("assigneeId", isEqualTo: uid).addSnapshotListener { snap, _ in
                topAssignee = snap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
            db.collection("selfTasks").whereField("createdByUid", isEqualTo: uid).addSnapshotListener { snap, _ in
                topCreated = snap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
            db.collection("selfTasks").whereField("assignedId", isEqualTo: uid).addSnapshotListener { snap, _ in
                topAssignedId = snap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
            db.collection("selfTasks").whereField("assignedUID", isEqualTo: uid).addSnapshotListener { snap, _ in
                topAssignedUID = snap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
            db.collection("selfTasks").whereField("assignedUid", isEqualTo: uid).addSnapshotListener { snap, _ in
                topAssignedUid = snap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
            db.collection("selfTasks").whereField("employeeId", isEqualTo: uid).addSnapshotListener { snap, _ in
                topEmployeeId = snap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
            // Nested subcollections under the user doc
            db.collection("selfTasks").document(uid).collection("tasks").addSnapshotListener { subSnap, _ in
                nestedTasks = subSnap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
            db.collection("selfTasks").document(uid).collection("selfTasks").addSnapshotListener { subSnap, _ in
                nestedSelfTasks = subSnap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
        }
        
        if let email = userEmail, !email.isEmpty {
            db.collection("selfTasks").whereField("createdByEmail", isEqualTo: email).addSnapshotListener { snap, _ in
                emailCreated = snap?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                emit()
            }
        }
        
        // Last resort: if neither UID nor email is available, stream all (dev fallback)
        if (uid == nil || uid!.isEmpty) && (userEmail == nil || userEmail!.isEmpty) {
            db.collection("selfTasks").addSnapshotListener { snapshot, _ in
                let all = snapshot?.documents.compactMap { self.mapTask(from: $0.data(), defaultType: .selfTask) } ?? []
                DispatchQueue.main.async { completion(all) }
            }
        }
    }
    
    // MARK: - Users Metrics
    func fetchUsersCount(completion: @escaping (Int) -> Void) {
        db.collection("users").addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ Error fetching users count: \(error.localizedDescription)")
                completion(0)
                return
            }
            completion(snapshot?.documents.count ?? 0)
        }
    }
    
    // MARK: - Fetch Employee Profile (users collection)
    func fetchEmployeeProfile(userId: String, completion: @escaping (Result<EmployeeProfile, Error>) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error { completion(.failure(error)); return }
            if let document = document, document.exists, let data = document.data() {
                completion(.success(self.profileFromData(id: userId, data: data)))
            } else {
                // Fallback: query by email
                self.db.collection("users").whereField("email", isEqualTo: userId).limit(to: 1).getDocuments { snapshot, qError in
                    if let qError = qError { completion(.failure(qError)); return }
                    guard let first = snapshot?.documents.first else {
                        completion(.failure(NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Employee profile not found"])))
                        return
                    }
                    completion(.success(self.profileFromData(id: first.documentID, data: first.data())))
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func parseDate(_ any: Any?) -> Date? {
        if let ts = any as? Timestamp { return ts.dateValue() }
        if let s = any as? String {
            let iso = ISO8601DateFormatter()
            if let d = iso.date(from: s) { return d }
            let f1 = DateFormatter()
            f1.locale = Locale(identifier: "en_US_POSIX")
            f1.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
            if let d2 = f1.date(from: s) { return d2 }
            let f2 = DateFormatter()
            f2.locale = Locale(identifier: "en_US_POSIX")
            f2.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let d3 = f2.date(from: s) { return d3 }
            let f3 = DateFormatter()
            f3.locale = Locale(identifier: "en_US_POSIX")
            f3.dateFormat = "yyyy-MM-dd"
            if let d4 = f3.date(from: s) { return d4 }
            let f4 = DateFormatter()
            f4.locale = Locale(identifier: "en_US_POSIX")
            f4.dateFormat = "dd/MM/yyyy"
            if let d5 = f4.date(from: s) { return d5 }
            let f5 = DateFormatter()
            f5.locale = Locale(identifier: "en_US_POSIX")
            f5.dateFormat = "dd-MM-yyyy"
            if let d6 = f5.date(from: s) { return d6 }
            let f6 = DateFormatter()
            f6.locale = Locale(identifier: "en_US_POSIX")
            f6.dateFormat = "dd/MM/yyyy HH:mm"
            if let d7 = f6.date(from: s) { return d7 }
            let f7 = DateFormatter()
            f7.locale = Locale(identifier: "en_US_POSIX")
            f7.dateFormat = "dd-MM-yyyy HH:mm"
            if let d8 = f7.date(from: s) { return d8 }
            let f8 = DateFormatter()
            f8.locale = Locale(identifier: "en_US_POSIX")
            f8.dateFormat = "dd/MM/yyyy h:mm a"
            if let d9 = f8.date(from: s) { return d9 }
            let f9 = DateFormatter()
            f9.locale = Locale(identifier: "en_US_POSIX")
            f9.dateFormat = "dd-MM-yyyy h:mm a"
            return f9.date(from: s)
        }
        if let ms = any as? Int {
            if ms > 100000000000 { return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0) }
            return Date(timeIntervalSince1970: TimeInterval(ms))
        }
        if let msd = any as? Double {
            if msd > 100000000000 { return Date(timeIntervalSince1970: TimeInterval(msd) / 1000.0) }
            return Date(timeIntervalSince1970: msd)
        }
        return nil
    }
    
    private func combine(dateString: String, timeString: String?) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        let timePart = (timeString?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        let patterns = timePart == nil
        ? ["yyyy-MM-dd"]
        : ["yyyy-MM-dd h:mm a", "yyyy-MM-dd hh:mm a", "dd/MM/yyyy h:mm a", "dd-MM-yyyy h:mm a"]
        for p in patterns {
            fmt.dateFormat = p
            let composed = timePart == nil ? dateString : "\(dateString) \(timePart!)"
            if let d = fmt.date(from: composed) { return d }
        }
        // Fallback: parse date only then set 9:00 AM
        fmt.dateFormat = "yyyy-MM-dd"
        if let base = fmt.date(from: dateString) {
            var comps = Calendar.current.dateComponents(in: .current, from: base)
            comps.hour = 9; comps.minute = 0; comps.second = 0
            return Calendar.current.date(from: comps)
        }
        return nil
    }
    
    private func mapEvent(from data: [String: Any], documentId: String? = nil) -> Meeting? {
        let title = data["title"] as? String
        ?? data["name"] as? String
        ?? data["eventTitle"] as? String
        ?? "Meeting"
        
        let startDate: Date = {
            if let d = parseDate(data["start"]) { return d }
            if let d = parseDate(data["startTime"]) { return d }
            if let d = parseDate(data["startDate"]) { return d }
            if let ds = data["date"] as? String {
                let timeStr = (data["time"] as? String) ?? (data["start_time"] as? String)
                if let combined = combine(dateString: ds, timeString: timeStr) { return combined }
                if let onlyDate = parseDate(ds) { return onlyDate }
            }
            if let d = parseDate(data["scheduledAt"]) { return d }
            return Date()
        }()
        
        let endDate: Date? = {
            if let d = parseDate(data["end"]) { return d }
            if let d = parseDate(data["endTime"]) { return d }
            if let d = parseDate(data["endDate"]) { return d }
            if let ds = data["date"] as? String, let t = data["end_time"] as? String { return combine(dateString: ds, timeString: t) }
            if let d = parseDate(data["to"]) { return d }
            return nil
        }()
        
        let durationFromData = data["duration"] as? Int ?? data["durationMinutes"] as? Int
        let duration: Int = {
            if let minutes = durationFromData { return minutes }
            if let endDate = endDate { return max(1, Int(endDate.timeIntervalSince(startDate) / 60)) }
            return 60
        }()
        
        var participants: [String] = data["participants"] as? [String]
        ?? data["attendees"] as? [String]
        ?? data["members"] as? [String]
        ?? []
        if participants.isEmpty, let arr = data["participants"] as? [[String: Any]] {
            participants = arr.compactMap { $0["name"] as? String ?? $0["email"] as? String }
        }
        if participants.isEmpty, let arr = data["attendees"] as? [[String: Any]] {
            participants = arr.compactMap { $0["name"] as? String ?? $0["email"] as? String }
        }
        
        let agenda = data["agenda"] as? String
        ?? data["description"] as? String
        ?? data["desc"] as? String
        ?? ""
        
        let typeString = (data["type"] as? String ?? data["meetingType"] as? String ?? "general").lowercased()
        let meetingType: MeetingType = {
            switch typeString {
            case "client", "clientreview", "client review": return .clientReview
            case "team", "teamsync", "team sync", "standup", "daily standup", "daily": return .teamSync
            case "projectupdate", "project update": return .projectUpdate
            case "sprintplanning", "sprint planning", "planning": return .sprintPlanning
            case "1:1", "1-1", "oneonone", "one on one", "one-on-one": return .oneOnOne
            default: return .general
            }
        }()
        
        let project = data["project"] as? String
        ?? data["projectName"] as? String
        ?? data["project_title"] as? String
        ?? data["clientName"] as? String
        
        let statusString = (data["status"] as? String ?? data["meetingStatus"] as? String ?? "").lowercased()
        let status: MeetingStatus = {
            switch statusString {
            case "completed", "done": return .completed
            case "in progress", "inprogress", "ongoing": return .inProgress
            case "cancelled", "canceled": return .cancelled
            case "scheduled": return .scheduled
            default:
                if startDate > Date() { return .scheduled }
                return .completed
            }
        }()
        
        let mom = data["mom"] as? String
        ?? data["minutes"] as? String
        ?? data["MOM"] as? String
        ?? data["notes"] as? String
        
        let location = data["location"] as? String
        ?? data["venue"] as? String
        ?? data["place"] as? String
        ?? data["address"] as? String
        
        let createdByUid = (
            data["createdByUid"] as? String
            ?? data["ownerUid"] as? String
            ?? data["employeeUid"] as? String
            ?? data["employeeId"] as? String
            ?? data["organizerUid"] as? String
        )
        
        let createdByEmail = (
            data["createdByEmail"] as? String
            ?? data["ownerEmail"] as? String
            ?? data["employeeEmail"] as? String
            ?? data["organizerEmail"] as? String
        )
        var m = Meeting(
            documentId: documentId,
            title: title,
            date: startDate,
            duration: duration,
            participants: participants,
            agenda: agenda,
            meetingType: meetingType,
            project: project,
            status: status,
            mom: mom,
            location: location,
            createdByUid: createdByUid,
            createdByEmail: createdByEmail
        )
        return m
    }

    // MARK: - Event CRUD
    func updateEvent(documentId: String, meeting: Meeting, completion: @escaping (Bool) -> Void) {
        let data: [String: Any] = [
            "title": meeting.title,
            "date": Timestamp(date: meeting.date),
            "start": Timestamp(date: meeting.date),
            "duration": meeting.duration,
            "participants": meeting.participants,
            "agenda": meeting.agenda,
            "clientName": meeting.project ?? "", // Best guess mapping
            "updatedAt": Timestamp(date: Date())
            // Add other fields as necessary
        ]
        
        db.collection("events").document(documentId).updateData(data) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    func deleteEvent(documentId: String, completion: @escaping (Bool) -> Void) {
        db.collection("events").document(documentId).delete { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    private func mapTask(from data: [String: Any], defaultType: TaskType) -> Task? {
        guard let title = data["title"] as? String else { return nil }
        let description = data["description"] as? String ?? ""
        let assignedToName = data["assignedToName"] as? String
        ?? data["assigneeName"] as? String
        ?? data["assignedTo"] as? String
        ?? data["assigneeId"] as? String
        ?? data["assignedId"] as? String
        ?? data["assignedUID"] as? String
        ?? data["employeeId"] as? String
        ?? ""
        
        let statusRaw = (data["status"] as? String ?? "To-Do")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let statusString = statusRaw.lowercased()
        let status: TaskStatus = {
            // Make mapping tolerant to variations like "Done Task", "task_done", etc.
            if statusString.contains("done") || statusString.contains("complete") {
                return .completed
            }
            if statusString.contains("progress") || statusString.contains("ongoing") {
                return .inProgress
            }
            if statusString.contains("stuck") {
                return .stuck
            }
            if statusString.contains("waiting") || statusString.contains("wait") {
                return .waitingFor
            }
            if statusString.contains("hold") && statusString.contains("client") {
                return .onHoldByClient
            }
            if statusString.contains("hold") {
                return .onHoldByClient
            }
            if statusString.contains("help") {
                return .needHelp
            }
            // Anything else is treated as TODO / not started
            return .notStarted
        }()
        
        let priorityString = (data["priority"] as? String ?? "P2").uppercased()
        let priority: Priority = {
            if priorityString.contains("HIGH") || priorityString.contains("P1") || priorityString.contains("URGENT") {
                return .p1
            }
            if priorityString.contains("LOW") || priorityString.contains("P3") {
                return .p3
            }
            // Explicitly check for Medium/P2 before defaulting
            if priorityString.contains("MEDIUM") || priorityString.contains("P2") || priorityString.contains("NORMAL") {
                return .p2
            }
            // Default to Medium if unknown, but this catches fewer accidental matches
            return .p2
        }()
        
        let startDate: Date = {
            let keys = ["startDate", "assignedDate", "start", "createdAt", "assigned_on"]
            for key in keys {
                if let d = parseDate(data[key]) { return d }
            }
            return Date()
        }()
        let dueDate: Date = {
            let keys = ["dueDate", "deadline", "endDate", "due", "due_date", "dueDateTime", "due_date_string"]
            for key in keys {
                if let d = parseDate(data[key]) { return d }
            }
            return Date().addingTimeInterval(86400 * 7)
        }()
        let departmentName = data["department"] as? String
        let department = Department.sampleDepartments.first { $0.name == departmentName }
        
        let typeString = (data["taskType"] as? String ?? data["type"] as? String ?? "").lowercased()
        let resolvedType: TaskType = {
            switch typeString {
            case "self", "selftask": return .selfTask
            case "admin", "admintask": return .adminTask
            case "client", "clientassigned", "client-assigned": return .clientAssigned
            default: return defaultType
            }
        }()
        
        // Store raw status label for custom filtering (keyed by title + due-date day)
        do {
            let keyTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let day = Calendar.current.startOfDay(for: dueDate)
            let key = keyTitle + "|" + String(Int(day.timeIntervalSince1970))
            self.taskRawStatusByKey[key] = statusRaw
        }
        
        // Try to link to a loaded Project using projectId or projectName
        let projectIdField = data["projectId"] as? String ?? data["project_id"] as? String
        let projectNameField = data["projectName"] as? String
        ?? data["project"] as? String
        ?? data["project_title"] as? String
        var linkedProject: Project? = nil
        if let pid = projectIdField {
            linkedProject = self.projects.first { $0.documentId == pid }
        }
        if linkedProject == nil, let pname = projectNameField {
            linkedProject = self.projects.first { $0.name.caseInsensitiveCompare(pname) == .orderedSame }
        }
        if linkedProject == nil {
            if let name = projectNameField ?? projectIdField {
                linkedProject = Project(
                    documentId: projectIdField,
                    name: name,
                    description: "",
                    progress: 0.0,
                    startDate: startDate,
                    endDate: dueDate,
                    tasks: [],
                    assignedEmployees: [],
                    department: department
                )
            }
        }
        
        // Recurring task fields
        let isRecurring: Bool = {
            if let flag = data["isRecurring"] as? Bool { return flag }
            if let flag = data["recurring"] as? Bool { return flag }
            if let str = data["isRecurring"] as? String {
                let lower = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return ["true", "yes", "1"].contains(lower)
            }
            return false
        }()
        
        let recurringPattern: RecurringPattern? = {
            let raw = (data["recurringPattern"] as? String
                       ?? data["recurrencePattern"] as? String
                       ?? data["recurrence"] as? String
                       ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch raw {
            case "daily": return .daily
            case "weekly": return .weekly
            case "bi-weekly", "biweekly", "bi weekly": return .biweekly
            case "monthly": return .monthly
            case "custom": return .custom
            default: return nil
            }
        }()
        
        let recurringDays: Int? = {
            if let v = data["recurringDays"] as? Int { return v }
            if let v = data["repeatIntervalDays"] as? Int { return v }
            if let s = data["recurringDays"] as? String, let v = Int(s) { return v }
            if let s = data["repeatIntervalDays"] as? String, let v = Int(s) { return v }
            return nil
        }()
        
        let recurringEndDate: Date? = {
            let keys: [String] = [
                "recurringEndDate",
                "recurrenceEndDate",
                "recurring_until",
                "recursUntil"
            ]
            for key in keys {
                if let d = parseDate(data[key]) { return d }
            }
            return nil
        }()
        
        let subtask = data["subtask"] as? String
        let weightage = data["weightage"] as? String
        
        let subtaskStatus: TaskStatus? = {
            guard let raw = data["subtaskStatus"] as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            let s = trimmed.lowercased()
            if s.contains("done") || s.contains("complete") {
                return .completed
            }
            if s.contains("progress") || s.contains("ongoing") {
                return .inProgress
            }
            if s.contains("stuck") {
                return .stuck
            }
            if s.contains("waiting") || s.contains("wait") {
                return .waitingFor
            }
            if s.contains("hold") && s.contains("client") {
                return .onHoldByClient
            }
            if s.contains("hold") {
                return .onHoldByClient
            }
            if s.contains("help") {
                return .needHelp
            }
            return .notStarted
        }()
        
        let commentsData = data["comments"] as? [[String: Any]] ?? []
        let comments: [Comment] = commentsData.compactMap { dict in
            guard let user = dict["user"] as? String,
                  let message = dict["message"] as? String else { return nil }
            // Handle timestamp which can be Timestamp or Date or String
            let timestamp: Date = {
                if let ts = dict["timestamp"] as? Timestamp { return ts.dateValue() }
                if let d = dict["timestamp"] as? Date { return d }
                return Date()
            }()
            return Comment(user: user, message: message, timestamp: timestamp)
        }
        
        // Extract total logged time
        let totalTimeLogged = data["totalTimeLogged"] as? TimeInterval
        
        return Task(
            title: title,
            description: description,
            status: status,
            priority: priority,
            startDate: startDate,
            dueDate: dueDate,
            assignedTo: assignedToName,
            comments: comments,
            department: department,
            project: linkedProject,
            taskType: resolvedType,
            isRecurring: isRecurring,
            recurringPattern: recurringPattern,
            recurringDays: recurringDays,
            recurringEndDate: recurringEndDate,
            subtask: subtask,
            weightage: weightage,
            subtaskStatus: subtaskStatus,
            totalTimeLogged: totalTimeLogged
        )
    }
    
    private func profileFromData(id: String, data: [String: Any]) -> EmployeeProfile {
        let name = data["name"] as? String ?? data["displayName"] as? String ?? "Employee"
        let email = data["email"] as? String ?? ""
        let profileImageURL = data["imageUrl"] as? String
        ?? data["imageurl"] as? String
        ?? data["profileImageURL"] as? String
        ?? data["photoURL"] as? String
        let department = data["department"] as? String
        let position = (
            data["resourceRoleType"] as? String
            ?? data["position"] as? String
            ?? data["designation"] as? String
            ?? data["role"] as? String
        )
        var mobile: String? = nil
        var password: String? = data["devPassword"] as? String
        
        for (key, value) in data {
            let lowerKey = key.lowercased()
            // Aggressive mobile matching
            if mobile == nil && (lowerKey.contains("mobile") || lowerKey.contains("phone") || lowerKey.contains("contact")) {
                mobile = "\(value)"
            }
            // Aggressive password matching
            if password == nil && (lowerKey.contains("pass") || lowerKey.contains("pwd") || lowerKey.contains("word") || lowerKey == "psw" || lowerKey == "pswd") {
                password = "\(value)"
            }
        }
        
        let roleType = data["roleType"] as? String ?? data["userRole"] as? String
        
        var joinDate: Date? = nil
        if let ts = data["joinDate"] as? Timestamp {
            joinDate = ts.dateValue()
        } else if let ts = data["createdAt"] as? Timestamp {
            joinDate = ts.dateValue()
        }
        
        let employmentType = data["employmentType"] as? String
        let resourceType = data["resourceType"] as? String
        let status = data["status"] as? String
        
        return EmployeeProfile(
            id: id,
            name: name,
            email: email,
            profileImageURL: profileImageURL,
            department: department,
            position: position,
            mobile: mobile,
            roleType: roleType,
            joinDate: joinDate,
            password: password,
            employmentType: employmentType,
            resourceType: resourceType,
            status: status
        )
    }
    
    // Update task status using a raw label string from Firestore settings
    func updateTaskStatusLabel(title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, toLabel label: String, completion: ((Int) -> Void)? = nil) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        var query: Query = db.collection("tasks").whereField("title", isEqualTo: title)
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail"]
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            var updated = 0
            let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                let data = doc.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            let group = DispatchGroup()
            for d in filtered {
                group.enter()
                d.reference.updateData([
                    "status": trimmed,
                    "updatedAt": Timestamp(date: Date())
                ]) { _ in
                    updated += 1
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion?(updated)
            }
        }
    }
    
    // Update total logged time for a task
    // Update total logged time for a task
    func updateTaskTotalTime(taskType: TaskType = .adminTask, title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, newTotalTime: TimeInterval, completion: ((Int) -> Void)? = nil) {
        let collectionName = (taskType == .selfTask) ? "selfTasks" : "tasks"
        var query: Query = db.collection(collectionName).whereField("title", isEqualTo: title)
        
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        // Keys to identify the user
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "userUid"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail", "userEmail"]
        
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            var updated = 0
            
            let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                let data = doc.data()
                
                // If it's a self task, we are looser with matching or stricter depending on structure
                // But generally filtering by user is safe
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            
            let group = DispatchGroup()
            for d in filtered {
                group.enter()
                d.reference.updateData([
                    "totalTimeLogged": newTotalTime,
                    "updatedAt": Timestamp(date: Date())
                ]) { _ in
                    updated += 1
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion?(updated)
            }
        }
    }
    
    // Fetch total logged time for a specific task
    func fetchTaskTotalTime(taskType: TaskType = .adminTask, title: String, projectId: String?, forUserUid uid: String?, userEmail: String?, completion: @escaping (TimeInterval?) -> Void) {
        let collectionName = (taskType == .selfTask) ? "selfTasks" : "tasks"
        var query: Query = db.collection(collectionName).whereField("title", isEqualTo: title)
        
        if let pid = projectId, !pid.isEmpty {
            query = query.whereField("projectId", isEqualTo: pid)
        }
        
        let uidKeys = ["assigneeId", "assignedId", "assignedUID", "assignedUid", "employeeId", "createdByUid", "userUid"]
        let emailKeys = ["assignedEmail", "assigneeEmail", "createdByEmail", "userEmail"]
        
        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            
            // Filter exactly like update to find the right doc
            let filtered: [QueryDocumentSnapshot] = docs.filter { doc in
                let data = doc.data()
                var uidMatched = false
                if let uid = uid, !uid.isEmpty {
                    uidMatched = uidKeys.contains { (data[$0] as? String) == uid }
                }
                var emailMatched = false
                if let email = userEmail, !email.isEmpty {
                    emailMatched = emailKeys.contains { (data[$0] as? String) == email }
                }
                
                if (uid != nil && !(uid!.isEmpty)) && (userEmail != nil && !(userEmail!.isEmpty)) {
                    return uidMatched || emailMatched
                }
                if let _ = uid, !(uid!.isEmpty) { return uidMatched }
                if let _ = userEmail, !(userEmail!.isEmpty) { return emailMatched }
                return true
            }
            
            if let firstMatch = filtered.first {
                let val = firstMatch.data()["totalTimeLogged"] as? TimeInterval
                completion(val)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Hierarchy Management
    func listenHierarchy() {
        db.collection("settings").document("hierarchy")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching hierarchy: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let rolesArray = data["roles"] as? [[String: Any]] else {
                    print("Hierarchy data not found or format incorrect")
                    self.hierarchyRoles = []
                    return
                }
                
                DispatchQueue.main.async {
                    self.hierarchyRoles = rolesArray.compactMap { dict in
                        guard let name = dict["name"] as? String,
                              let role = dict["role"] as? String else { return nil }
                        // Use existing ID if available, otherwise generate new (though it should exist)
                        let id = dict["id"] as? String ?? UUID().uuidString
                        return HierarchyRole(id: id, name: name, role: role)
                    }
                }
            }
    }
    
    func addHierarchyRole(name: String, role: String, completion: @escaping (Bool) -> Void) {
        let newRoleDict: [String: Any] = [
            "name": name,
            "role": role
        ]
        
        let docRef = db.collection("settings").document("hierarchy")
        
        docRef.updateData([
            "roles": FieldValue.arrayUnion([newRoleDict])
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error adding hierarchy role: \(error.localizedDescription)")
                    // If the document doesn't exist, create it
                    if (error as NSError).code == 5 { // NOT_FOUND
                        docRef.setData(["roles": [newRoleDict]]) { err in
                            completion(err == nil)
                        }
                    } else {
                        completion(false)
                    }
                } else {
                    completion(true)
                }
            }
        }
    }
    
    func updateHierarchyRole(roleToUpdate: HierarchyRole, newName: String, newRoleType: String, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("settings").document("hierarchy")
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = document.data(),
                  var roles = data["roles"] as? [[String: Any]] else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Hierarchy roles not found"])
                errorPointer?.pointee = error
                return nil
            }
            
            // Find index of the role to update
            var indexToUpdate: Int?
            
            // Try matching by ID first
            if let index = roles.firstIndex(where: { ($0["id"] as? String) == roleToUpdate.id }) {
                indexToUpdate = index
            } else {
                // Fallback: match by name and role (for legacy data)
                if let index = roles.firstIndex(where: { ($0["name"] as? String) == roleToUpdate.name && ($0["role"] as? String) == roleToUpdate.role }) {
                    indexToUpdate = index
                }
            }
            
            if let index = indexToUpdate {
                roles[index]["name"] = newName
                roles[index]["role"] = newRoleType
                // Remove ID if present, or explicitly do not set it as per request
                roles[index].removeValue(forKey: "id")
                transaction.updateData(["roles": roles], forDocument: docRef)
                return true
            } else {
                return nil
            }
        }) { (object, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error updating hierarchy role: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    func deleteHierarchyRole(roleToDelete: HierarchyRole, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("settings").document("hierarchy")
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = document.data(),
                  var roles = data["roles"] as? [[String: Any]] else {
                return nil
            }
            
            // Remove the role
            var indexToDelete: Int?
            
            if let index = roles.firstIndex(where: { ($0["id"] as? String) == roleToDelete.id }) {
                indexToDelete = index
            } else {
                // Fallback
                if let index = roles.firstIndex(where: { ($0["name"] as? String) == roleToDelete.name && ($0["role"] as? String) == roleToDelete.role }) {
                    indexToDelete = index
                }
            }
            
            if let index = indexToDelete {
                roles.remove(at: index)
                transaction.updateData(["roles": roles], forDocument: docRef)
                return true
            } else {
                return nil
            }
        }) { (object, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error deleting hierarchy role: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Knowledge Management
    // MARK: - Knowledge Management
    func fetchAdminKnowledge() {
        isLoading = true
        db.collection("knowledge").order(by: "createdAt", descending: true).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            guard let docs = snapshot?.documents else { 
                self.adminKnowledgeItems = []
                return 
            }
            
            self.adminKnowledgeItems = docs.compactMap { doc in
                let data = doc.data()
                let title = data["title"] as? String ?? ""
                // Handle both description (new) and bodyText (legacy/existing)
                let description = data["description"] as? String ?? data["bodyText"] as? String ?? ""
                let attachmentName = data["attachmentName"] as? String
                let attachmentURL = data["attachmentURL"] as? String
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                let createdBy = data["createdByName"] as? String ?? data["createdByEmail"] as? String ?? data["userEmail"] as? String ?? "Super Admin"
                
                return AdminKnowledgeItem(
                    id: doc.documentID,
                    title: title,
                    description: description,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    attachmentName: attachmentName,
                    attachmentURL: attachmentURL,
                    createdBy: createdBy,
                    allowedUserIds: data["allowedUserIds"] as? [String] ?? [],
                    allowedEmails: data["allowedEmails"] as? [String] ?? [],
                    links: data["links"] as? [String] ?? []
                )
            }
        }
    }
    
    func saveAdminKnowledge(userUid: String?, userEmail: String?, userName: String? = nil, title: String, bodyText: String, attachmentName: String? = nil, attachmentURL: String? = nil, allowedUserIds: [String] = [], allowedEmails: [String] = [], links: [String] = [], completion: @escaping (Result<String, Error>) -> Void) {
        var data: [String: Any] = [
            "title": title,
            "bodyText": bodyText,
            "description": bodyText, // Verify description is saved for fetchAdminKnowledge priority
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let uid = userUid { data["userUid"] = uid }
        if let email = userEmail { data["userEmail"] = email }
        if let name = userName { data["createdByName"] = name }
        if let name = attachmentName { data["attachmentName"] = name }
        if let url = attachmentURL { data["attachmentURL"] = url }
        
        // Always store these arrays to match consistent schema
        data["allowedUserIds"] = allowedUserIds
        data["allowedEmails"] = allowedEmails
        data["links"] = links
        
        var ref: DocumentReference? = nil
        ref = db.collection("knowledge").addDocument(data: data) { error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
            } else if let id = ref?.documentID {
                // Log creation activity
                self.logKnowledgeActivity(
                    knowledgeId: id,
                    description: "Created knowledge",
                    user: userName ?? "Unknown User"
                )
                
                DispatchQueue.main.async { completion(.success(id)) }
            }
        }
    }
    
    func updateAdminKnowledge(documentId: String, title: String, bodyText: String, attachmentName: String?, attachmentURL: String?, allowedUserIds: [String] = [], allowedEmails: [String] = [], links: [String] = [], changeLog: String? = nil, completion: ((Error?) -> Void)? = nil) {
        var data: [String: Any] = [
            "title": title,
            "bodyText": bodyText,
            "description": bodyText, // Ensure description is updated as it takes precedence in fetch
            "updatedAt": Timestamp(date: Date())
        ]
        if let name = attachmentName { data["attachmentName"] = name }
        if let url = attachmentURL { data["attachmentURL"] = url }
        
        // Always update these, passing empty array if cleared
        data["allowedUserIds"] = allowedUserIds
        data["allowedEmails"] = allowedEmails
        data["links"] = links
        
        db.collection("knowledge").document(documentId).updateData(data) { error in
            if error == nil {
                // Use provided change log or default
                let description = changeLog ?? "Updated knowledge details"
                
                let currentUser = FirebaseAuthService.shared.currentUser?.name ?? "Unknown User"
                self.logKnowledgeActivity(
                    knowledgeId: documentId,
                    description: description,
                    user: currentUser
                )
            }
            DispatchQueue.main.async { completion?(error) }
        }
    }
    
    // MARK: - Knowledge Activities
    
    func fetchKnowledgeActivities(knowledgeId: String, completion: @escaping ([KnowledgeActivity]) -> Void) {
        db.collection("knowledge").document(knowledgeId).collection("activities")
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching activities: \(error)")
                    completion([])
                    return
                }
                
                let activities = snapshot?.documents.compactMap { doc -> KnowledgeActivity? in
                    let data = doc.data()
                    guard let description = data["description"] as? String,
                          let performedBy = data["performedBy"] as? String else { return nil }
                    
                    let timestamp: Date
                    if let ts = data["timestamp"] as? Timestamp {
                        timestamp = ts.dateValue()
                    } else {
                        timestamp = Date()
                    }
                    
                    return KnowledgeActivity(
                        id: doc.documentID,
                        description: description,
                        performedBy: performedBy,
                        timestamp: timestamp
                    )
                } ?? []
                
                completion(activities)
            }
    }
    
    func logKnowledgeActivity(knowledgeId: String, description: String, user: String, completion: (() -> Void)? = nil) {
        let data: [String: Any] = [
            "description": description,
            "performedBy": user,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("knowledge").document(knowledgeId).collection("activities").addDocument(data: data) { error in
            if let error = error {
                print("Error logging activity: \(error)")
            }
            completion?()
        }
    }
    
    // MARK: - Document Activities
    
    func logDocumentActivity(projectId: String, folderName: String, documentId: String, description: String, user: String) {
        let db = Firestore.firestore()
        
        let validFolder = !folderName.isEmpty ? folderName : "documents"
        let collectionPath: CollectionReference
        
        if validFolder == "documents" || projectId.isEmpty {
             // Legacy/Root
             collectionPath = db.collection("documents").document(documentId).collection("activities")
        } else {
             // Sub-collection
             collectionPath = db.collection("documents").document(projectId).collection(validFolder).document(documentId).collection("activities")
        }
        
        let data: [String: Any] = [
            "description": description,
            "performedBy": user,
            "timestamp": Timestamp(date: Date())
        ]
        
        collectionPath.addDocument(data: data) { error in
            if let error = error {
                print("❌ Error logging document activity: \(error.localizedDescription)")
            } else {
                print("✅ Document activity logged: \(description)")
            }
        }
    }
    
    func fetchDocumentActivities(projectId: String, folderName: String, documentId: String, completion: @escaping ([KnowledgeActivity]) -> Void) {
        let db = Firestore.firestore()
        
        let validFolder = !folderName.isEmpty ? folderName : "documents"
        let collectionPath: Query
        
        if validFolder == "documents" || projectId.isEmpty {
             collectionPath = db.collection("documents").document(documentId).collection("activities")
        } else {
             collectionPath = db.collection("documents").document(projectId).collection(validFolder).document(documentId).collection("activities")
        }
        
        collectionPath.order(by: "timestamp", descending: true).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching document activities: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let activities = snapshot?.documents.compactMap { doc -> KnowledgeActivity? in
                let data = doc.data()
                guard let description = data["description"] as? String,
                      let performedBy = data["performedBy"] as? String else { return nil }
                
                let timestamp: Date
                if let ts = data["timestamp"] as? Timestamp {
                    timestamp = ts.dateValue()
                } else {
                    timestamp = Date()
                }
                
                return KnowledgeActivity(
                    id: doc.documentID,
                    description: description,
                    performedBy: performedBy,
                    timestamp: timestamp
                )
            } ?? []
            
            completion(activities)
        }
    }
    
    func deleteAdminKnowledge(documentId: String, completion: ((Error?) -> Void)? = nil) {
        db.collection("knowledge").document(documentId).delete { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - MOM Management
    @Published var savedMOMs: [MOMDocument] = []
    
    func fetchNextMOMID(completion: @escaping (String) -> Void) {
        db.collection("minutes_of_meetings")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                var nextID = "MOM_101" // Default start
                
                if let doc = snapshot?.documents.first {
                    let lastID = doc.documentID
                    // Try to parse "MOM_XXX"
                    let components = lastID.components(separatedBy: "_")
                    if components.count == 2, let number = Int(components[1]) {
                        nextID = "MOM_\(number + 1)"
                    }
                }
                
                DispatchQueue.main.async {
                    completion(nextID)
                }
            }
    }
    
    func saveMOM(_ mom: MOMDocument, completion: @escaping (Result<String, Error>) -> Void) {
        var data: [String: Any] = [
            "projectName": mom.projectName,
            "date": Timestamp(date: mom.date),
            "startTime": Timestamp(date: mom.startTime),
            "endTime": Timestamp(date: mom.endTime),
            "venue": mom.venue,
            "internalAttendees": mom.internalAttendees,
            "externalAttendees": mom.externalAttendees,
            "preparedBy": mom.preparedBy,
            "agenda": mom.agenda,
            "createdAt": Timestamp(date: mom.createdAt)
        ]
        
        // Encode complex objects manually
        do {
            let encoder = JSONEncoder()
            
            let encodedPoints = try encoder.encode(mom.discussionPoints)
            let pointsArray = try JSONSerialization.jsonObject(with: encodedPoints, options: []) as? [[String: Any]] ?? []
            data["discussionPoints"] = pointsArray
            
            if let ana = mom.analysis {
                let encodedAna = try encoder.encode(ana)
                let anaDict = try JSONSerialization.jsonObject(with: encodedAna, options: []) as? [String: Any] ?? [:]
                data["analysis"] = anaDict
            }
            
            let encodedActions = try encoder.encode(mom.actionItems)
            let actionsArray = try JSONSerialization.jsonObject(with: encodedActions, options: []) as? [[String: Any]] ?? []
            data["actionItems"] = actionsArray
            
        } catch {
            print("Error encoding MOM: \(error)")
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }
        
        if let customId = mom.id, !customId.isEmpty {
            // Use custom ID
            let ref = db.collection("minutes_of_meetings").document(customId)
            ref.setData(data) { error in
                if let error = error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                } else {
                    DispatchQueue.main.async { completion(.success(customId)) }
                }
            }
        } else {
            // Auto-generate ID
            var ref: DocumentReference? = nil
            ref = db.collection("minutes_of_meetings").addDocument(data: data) { error in
                if let error = error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                } else if let docId = ref?.documentID {
                    DispatchQueue.main.async { completion(.success(docId)) }
                } else {
                    let unknownError = NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get document ID"])
                    DispatchQueue.main.async { completion(.failure(unknownError)) }
                }
            }
        }
    }
    
    func fetchMOMs() {
        isLoading = true
        db.collection("minutes_of_meetings").order(by: "createdAt", descending: true).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            guard let docs = snapshot?.documents else { return }
            
            self.savedMOMs = docs.compactMap { doc -> MOMDocument? in
                let data = doc.data()
                return self.mapMOM(doc.documentID, data: data)
            }
        }
    }
    
    private func mapMOM(_ id: String, data: [String: Any]) -> MOMDocument? {
        guard let projectName = data["projectName"] as? String,
              let dateTs = data["date"] as? Timestamp else { return nil }
        
        let date = dateTs.dateValue()
        let startTime = (data["startTime"] as? Timestamp)?.dateValue() ?? date
        let endTime = (data["endTime"] as? Timestamp)?.dateValue() ?? date
        let venue = data["venue"] as? String ?? ""
        let internalAttendees = data["internalAttendees"] as? [String] ?? []
        let externalAttendees = data["externalAttendees"] as? String ?? ""
        let preparedBy = data["preparedBy"] as? String ?? ""
        let agenda = data["agenda"] as? [String] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Decode complex objects
        var discussionPoints: [DiscussionPoint] = []
        if let pointsData = data["discussionPoints"] as? [[String: Any]] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: pointsData),
               let decoded = try? JSONDecoder().decode([DiscussionPoint].self, from: jsonData) {
                discussionPoints = decoded
            }
        }
        
        var analysis: DiscussionAnalysis?
        if let anaData = data["analysis"] as? [String: Any] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: anaData),
               let decoded = try? JSONDecoder().decode(DiscussionAnalysis.self, from: jsonData) {
                analysis = decoded
            }
        }
        
        var actionItems: [ActionItem] = []
        if let actionsData = data["actionItems"] as? [[String: Any]] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: actionsData),
               let decoded = try? JSONDecoder().decode([ActionItem].self, from: jsonData) {
                actionItems = decoded
            }
        }
        
        return MOMDocument(
            id: id,
            projectName: projectName,
            date: date,
            startTime: startTime,
            endTime: endTime,
            venue: venue,
            internalAttendees: internalAttendees,
            externalAttendees: externalAttendees,
            preparedBy: preparedBy,
            agenda: agenda,
            discussionPoints: discussionPoints,
            analysis: analysis,
            actionItems: actionItems,
            createdAt: createdAt
        )
    }
    
    func uploadMOMPDF(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        uploadDocument(fileURL: fileURL, folder: "moms", completion: completion)
    }

    func uploadDocument(fileURL: URL, folder: String = "knowledge_docs", completion: @escaping (Result<String, Error>) -> Void) {
        let fileName = "\(folder)/" + UUID().uuidString + "_" + fileURL.lastPathComponent
        let ref = storage.reference().child("documents").child(fileName)
        
        ref.putFile(from: fileURL, metadata: nil) { _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            ref.downloadURL { url, error in
                DispatchQueue.main.async {
                    if let url = url {
                        completion(.success(url.absoluteString))
                    } else {
                        completion(.failure(error ?? NSError(domain: "UploadDocument", code: -1, userInfo: nil)))
                    }
                }
            }
        }
    }

    func saveDocumentEntry(name: String, url: String, category: String, description: String, userUid: String?, momId: String? = nil, completion: @escaping (Error?) -> Void) {
        var data: [String: Any] = [
            "id": momId ?? UUID().uuidString,
            "name": name,
            "url": url,
            "category": category,
            "description": description,
            "createdAt": Timestamp(date: Date()),
            "createdBy": userUid ?? "unknown",
            "accessType": "Internal"
        ]
        
        // Add MOM ID if provided
        if let momId = momId {
            data["momId"] = momId
            // Use the MOM ID as the document reference ID
            db.collection("documents").document(momId).setData(data) { error in
                DispatchQueue.main.async { completion(error) }
            }
        } else {
            // Generate a new ID
            db.collection("documents").addDocument(data: data) { error in
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
}

struct MOMDocument: Identifiable, Codable {
    var id: String?
    var projectName: String
    var date: Date
    var startTime: Date
    var endTime: Date
    var venue: String
    var internalAttendees: [String]
    var externalAttendees: String
    var preparedBy: String
    var agenda: [String]
    var discussionPoints: [DiscussionPoint]
    var analysis: DiscussionAnalysis?
    var actionItems: [ActionItem]
    var createdAt: Date
}

// MARK: - Expense Model
struct Expense: Identifiable, Codable {
    var id: String?
    var employeeName: String
    var employeeId: String
    var title: String
    var description: String
    var amount: Double
    var category: String
    var status: ExpenseStatus
    var date: Date
    var receiptURL: String?
    var projectName: String?  // Added optional project name
    var createdAt: Date
    var updatedAt: Date
    
    enum ExpenseStatus: String, Codable {
        case draft = "Draft"
        case submitted = "Submitted"
        case approved = "Approved"
        case rejected = "Rejected"
        case paid = "Paid"
    }
}

// MARK: - Expense Management Extension
extension FirebaseService {
    func fetchExpenses() {
        db.collection("expenses")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching expenses: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.expenses = []
                    return
                }
                
                self.expenses = documents.compactMap { doc -> Expense? in
                    let data = doc.data()
                    
                    // Handle flexible keys for Employee Name
                    let employeeName = data["employeeName"] as? String
                        ?? data["userName"] as? String
                        ?? data["name"] as? String
                        ?? data["employeeEmail"] as? String
                        ?? "Unknown"
                        
                    // Handle flexible keys for Employee ID
                    let employeeId = data["employeeId"] as? String
                        ?? data["employeeUid"] as? String
                        ?? data["empId"] as? String
                        ?? data["uid"] as? String
                        ?? "unknown"
                    
                    // Essential fields
                    guard let title = data["title"] as? String,
                          let amount = data["amount"] as? Double,
                          let category = data["category"] as? String,
                          let statusRaw = data["status"] as? String else {
                        return nil
                    }
                    
                    let description = data["description"] as? String ?? ""
                    
                    // Case-insensitive status mapping
                    let status: Expense.ExpenseStatus = {
                        let normalized = statusRaw.lowercased()
                        switch normalized {
                        case "submitted": return .submitted
                        case "approved": return .approved
                        case "rejected": return .rejected
                        case "paid": return .paid
                        case "draft": return .draft
                        default: return Expense.ExpenseStatus(rawValue: statusRaw) ?? .draft
                        }
                    }()
                    
                    // Fix date parsing (handle String or Timestamp)
                    let date: Date = {
                        if let ts = data["date"] as? Timestamp { return ts.dateValue() }
                        if let str = data["date"] as? String {
                            // Try parsing YYYY-MM-DD
                            let fmt = DateFormatter()
                            fmt.dateFormat = "yyyy-MM-dd"
                            fmt.locale = Locale(identifier: "en_US_POSIX") // Ensure consistent parsing
                            if let d = fmt.date(from: str) { return d }
                            // Try other formats if needed
                        }
                        return Date()
                    }()
                    
                    let receiptURL = data["receiptURL"] as? String
                    let projectName = data["projectName"] as? String  // Parse project name
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    return Expense(
                        id: doc.documentID,
                        employeeName: employeeName,
                        employeeId: employeeId,
                        title: title,
                        description: description,
                        amount: amount,
                        category: category,
                        status: status,
                        date: date,
                        receiptURL: receiptURL,
                        projectName: projectName,  // Initialize project name
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                }
            }
    }
    
    func addExpense(_ expense: Expense, completion: @escaping (Result<String, Error>) -> Void) {
        var data: [String: Any] = [
            "employeeName": expense.employeeName,
            "employeeId": expense.employeeId,
            "title": expense.title,
            "description": expense.description,
            "amount": expense.amount,
            "category": expense.category,
            "status": expense.status.rawValue,
            "date": Timestamp(date: expense.date),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let receiptURL = expense.receiptURL {
            data["receiptURL"] = receiptURL
        }
        
        var ref: DocumentReference? = nil
        ref = db.collection("expenses").addDocument(data: data) { error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
            } else if let docId = ref?.documentID {
                DispatchQueue.main.async { completion(.success(docId)) }
            }
        }
    }
    
    func updateExpenseStatus(expenseId: String, status: Expense.ExpenseStatus, completion: @escaping (Error?) -> Void) {
        db.collection("expenses").document(expenseId).updateData([
            "status": status.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
    
    func deleteExpense(expenseId: String, completion: @escaping (Error?) -> Void) {
        db.collection("expenses").document(expenseId).delete { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
    
    // Computed properties for expense statistics
    var totalExpenses: Int {
        expenses.count
    }
    
    var approvedExpenses: [Expense] {
        expenses.filter { $0.status == .approved }
    }
    
    var paidExpenses: [Expense] {
        expenses.filter { $0.status == .paid }
    }
    
    var draftExpenses: [Expense] {
        expenses.filter { $0.status == .draft }
    }
    
    var submittedExpenses: [Expense] {
        expenses.filter { $0.status == .submitted }
    }
    
    var rejectedExpenses: [Expense] {
        expenses.filter { $0.status == .rejected }
    }
    
    var totalApprovedAmount: Double {
        approvedExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var totalPaidAmount: Double {
        paidExpenses.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Subtask Management (Sub-collection)
    
    func addSubtask(taskId: String, subtask: SubTaskItem, completion: @escaping (Error?) -> Void) {
        let data: [String: Any] = [
            "title": subtask.title,
            "description": subtask.description,
            "isCompleted": subtask.isCompleted,
            "status": subtask.status.rawValue,
            "priority": subtask.priority.rawValue,
            "createdAt": Timestamp(date: subtask.createdAt),
            "assignedDate": Timestamp(date: subtask.assignedDate),
            "dueDate": Timestamp(date: subtask.dueDate),
            "assignedTo": subtask.assignedTo ?? ""
        ]
        
        db.collection("tasks").document(taskId).collection("subtasks").addDocument(data: data) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
    
    func listenToSubtasks(taskId: String, completion: @escaping ([SubTaskItem]) -> Void) -> ListenerRegistration {
        return db.collection("tasks").document(taskId).collection("subtasks")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                let items = documents.compactMap { doc -> SubTaskItem? in
                    let data = doc.data()
                    guard let title = data["title"] as? String else { return nil }
                    let description = data["description"] as? String ?? ""
                    let isCompleted = data["isCompleted"] as? Bool ?? false
                    let statusRaw = data["status"] as? String ?? ""
                    let status = TaskStatus(rawValue: statusRaw) ?? .notStarted
                    let priorityRaw = data["priority"] as? String ?? "P2"
                    // Map priority properly
                    let priority: Priority = {
                         if priorityRaw == "P1" || priorityRaw == "High" { return .p1 }
                         if priorityRaw == "P3" || priorityRaw == "Low" { return .p3 }
                         return .p2
                    }()
                    
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let assignedDate = (data["assignedDate"] as? Timestamp)?.dateValue() ?? Date()
                    let dueDate = (data["dueDate"] as? Timestamp)?.dateValue() ?? Date().addingTimeInterval(86400 * 7)
                    let assignedTo = data["assignedTo"] as? String
                    
                    return SubTaskItem(
                        id: doc.documentID,
                        title: title,
                        description: description,
                        isCompleted: isCompleted,
                        status: status,
                        priority: priority,
                        createdAt: createdAt,
                        assignedDate: assignedDate,
                        dueDate: dueDate,
                        assignedTo: assignedTo
                    )
                }
                
                DispatchQueue.main.async { completion(items) }
            }
    }
    
    func updateSubtask(taskId: String, subtask: SubTaskItem, completion: @escaping (Error?) -> Void) {
        let data: [String: Any] = [
            "title": subtask.title,
            "description": subtask.description,
            "isCompleted": subtask.isCompleted,
            "status": subtask.status.rawValue,
            "priority": subtask.priority.rawValue,
            "assignedDate": Timestamp(date: subtask.assignedDate),
            "dueDate": Timestamp(date: subtask.dueDate),
            "assignedTo": subtask.assignedTo ?? ""
        ]
        
        db.collection("tasks").document(taskId).collection("subtasks").document(subtask.id).updateData(data) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
    
    func deleteSubtask(taskId: String, subtaskId: String, completion: @escaping (Error?) -> Void) {
        db.collection("tasks").document(taskId).collection("subtasks").document(subtaskId).delete { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
}
