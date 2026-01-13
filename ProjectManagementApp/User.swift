import Foundation

enum UserRole {
    case employee
    case client
    case manager
    case admin
    case superAdmin
}

// Department Model
struct Department: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let companyType: CompanyType
    let color: String
}

enum CompanyType: String, CaseIterable {
    case itCompany = "IT Company"
    case manufacturing = "Manufacturing"
    case healthcare = "Healthcare"
    case finance = "Finance"
    case education = "Education"
    case retail = "Retail"
    case consulting = "Consulting"
    case construction = "Construction"
    case logistics = "Logistics"
    case media = "Media & Entertainment"
}

struct User: Identifiable {
    let id = UUID()
    let email: String
    let password: String
    let name: String
    let role: UserRole
    let profileImage: String?
}

// OKR Models
struct KeyResult: Identifiable, Codable {
    let id: UUID
    let description: String
    
    init(id: UUID = UUID(), description: String) {
        self.id = id
        self.description = description
    }
}

struct Objective: Identifiable, Codable {
    let id: UUID
    let title: String
    let keyResults: [KeyResult]
    
    init(id: UUID = UUID(), title: String, keyResults: [KeyResult]) {
        self.id = id
        self.title = title
        self.keyResults = keyResults
    }
}

struct Project: Identifiable {
    let id: UUID
    var documentId: String? // Firestore document ID
    let name: String
    let description: String
    let progress: Double
    let startDate: Date
    let endDate: Date
    let tasks: [Task]
    let assignedEmployees: [String]
    let department: Department?
    let objectives: [Objective] // OKRs
    let projectManager: String?
    let clientName: String?
    
    // Initializer with default documentId
    init(id: UUID = UUID(), documentId: String? = nil, name: String, description: String, progress: Double, startDate: Date, endDate: Date, tasks: [Task], assignedEmployees: [String], department: Department?, objectives: [Objective] = [], projectManager: String? = nil, clientName: String? = nil) {
        self.id = id
        self.documentId = documentId
        self.name = name
        self.description = description
        self.progress = progress
        self.startDate = startDate
        self.endDate = endDate
        self.tasks = tasks
        self.assignedEmployees = assignedEmployees
        self.department = department
        self.objectives = objectives
        self.projectManager = projectManager
        self.clientName = clientName
    }
}

struct Client: Identifiable {
    let id: UUID
    var documentId: String?
    let name: String // Mapped to Client Name
    let companyName: String?
    let email: String?
    let phone: String?
    let businessType: String?
    let employeeCount: String?
    let address: String?
    let logoURL: String?
    let password: String? // Optional, for reference
    
    init(id: UUID = UUID(), 
         documentId: String? = nil, 
         name: String, 
         companyName: String? = nil,
         email: String? = nil, 
         phone: String? = nil,
         businessType: String? = nil,
         employeeCount: String? = nil,
         address: String? = nil,
         logoURL: String? = nil,
         password: String? = nil) {
        self.id = id
        self.documentId = documentId
        self.name = name
        self.companyName = companyName
        self.email = email
        self.phone = phone
        self.businessType = businessType
        self.employeeCount = employeeCount
        self.address = address
        self.logoURL = logoURL
        self.password = password
    }
}

struct Task: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let status: TaskStatus
    let priority: Priority
    let startDate: Date
    let dueDate: Date
    let assignedTo: String
    let comments: [Comment]
    let department: Department?
    let project: Project?
    let taskType: TaskType
    let isRecurring: Bool
    let recurringPattern: RecurringPattern?
    let recurringDays: Int? // Number of days for the recurring cycle
    let recurringEndDate: Date? // Optional end date for recurring tasks
    let subtask: String?
    let weightage: String?
    let subtaskStatus: TaskStatus?
    var totalTimeLogged: TimeInterval? = nil
}

enum RecurringPattern: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case custom = "Custom" // For custom day intervals
}

enum TaskType: String {
    case selfTask = "Self"
    case adminTask = "Admin"
    case clientAssigned = "Client Assigned"
}

enum TaskStatus: String, Codable {
    case notStarted = "TODO"
    case inProgress = "In Progress"
    case stuck = "Stuck"
    case waitingFor = "Waiting For"
    case onHoldByClient = "Hold by Client"
    case needHelp = "Need Help"
    case completed = "Done"
    case canceled = "Canceled"
}

enum Priority: String, Codable {
    case p1 = "P1"
    case p2 = "P2"
    case p3 = "P3"
}

struct Comment: Identifiable {
    let id = UUID()
    let user: String
    let message: String
    let timestamp: Date
}

struct ActivityItem: Identifiable, Codable {
    let id: String
    let user: String
    let action: String // e.g., "commented", "created this task", "updated status"
    let message: String?
    let timestamp: Date
    let type: String // "comment", "history", "creation"
    
    init(id: String = UUID().uuidString, user: String, action: String, message: String? = nil, timestamp: Date = Date(), type: String = "history") {
        self.id = id
        self.user = user
        self.action = action
        self.message = message
        self.timestamp = timestamp
        self.type = type
    }
}

struct SubTaskItem: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let isCompleted: Bool
    let status: TaskStatus
    let priority: Priority
    let createdAt: Date
    let assignedDate: Date
    let dueDate: Date
    let assignedTo: String?
    
    init(id: String = UUID().uuidString, 
         title: String, 
         description: String = "",
         isCompleted: Bool = false, 
         status: TaskStatus = .notStarted,
         priority: Priority = .p2,
         createdAt: Date = Date(), 
         assignedDate: Date = Date(),
         dueDate: Date = Date().addingTimeInterval(86400 * 7),
         assignedTo: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.assignedDate = assignedDate
        self.dueDate = dueDate
        self.assignedTo = assignedTo
    }
}

// Enhanced Meeting Model
struct Meeting: Identifiable {
    let id = UUID()
    var documentId: String? // Firestore ID
    let title: String
    let date: Date
    let duration: Int // in minutes
    let participants: [String]
    let agenda: String
    let meetingType: MeetingType
    let project: String?
    let status: MeetingStatus
    let mom: String? // Minutes of Meeting
    let location: String?
    var createdByUid: String?
    var createdByEmail: String?
}

enum MeetingType: String {
    case clientReview = "Client Review"
    case teamSync = "Team Sync"
    case projectUpdate = "Project Update"
    case sprintPlanning = "Sprint Planning"
    case oneOnOne = "One-on-One"
    case general = "General Meeting"
}

enum MeetingStatus: String {
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

// Sample Departments
extension Department {
    static let sampleDepartments: [Department] = [
        // IT & Software Development
        Department(name: "Software Development", description: "Application and software development", companyType: .itCompany, color: "#007AFF"),
        Department(name: "Frontend Development", description: "Web and mobile UI development", companyType: .itCompany, color: "#5AC8FA"),
        Department(name: "Backend Development", description: "Server-side and API development", companyType: .itCompany, color: "#0A84FF"),
        Department(name: "Full Stack Development", description: "End-to-end application development", companyType: .itCompany, color: "#007AFF"),
        Department(name: "Mobile Development", description: "iOS and Android app development", companyType: .itCompany, color: "#5856D6"),
        
        // Testing & QA
        Department(name: "Quality Assurance", description: "Software testing and quality control", companyType: .itCompany, color: "#34C759"),
        Department(name: "Manual Testing", description: "Manual software testing", companyType: .itCompany, color: "#30D158"),
        Department(name: "Automation Testing", description: "Automated testing and test scripts", companyType: .itCompany, color: "#32D74B"),
        Department(name: "Performance Testing", description: "Load and performance testing", companyType: .itCompany, color: "#30DB5B"),
        Department(name: "Security Testing", description: "Application security testing", companyType: .itCompany, color: "#34C759"),
        
        // DevOps & Infrastructure
        Department(name: "DevOps", description: "Development operations and CI/CD", companyType: .itCompany, color: "#FF9500"),
        Department(name: "Cloud Infrastructure", description: "Cloud services and infrastructure", companyType: .itCompany, color: "#FF9F0A"),
        Department(name: "System Administration", description: "Server and system management", companyType: .itCompany, color: "#FF9500"),
        Department(name: "Network Engineering", description: "Network design and management", companyType: .itCompany, color: "#FF9F0A"),
        
        // Design & UX
        Department(name: "UI/UX Design", description: "User interface and experience design", companyType: .itCompany, color: "#AF52DE"),
        Department(name: "Graphic Design", description: "Visual design and branding", companyType: .itCompany, color: "#BF5AF2"),
        Department(name: "Product Design", description: "Product design and prototyping", companyType: .itCompany, color: "#AC51DE"),
        
        // Data & Analytics
        Department(name: "Data Analytics", description: "Data analysis and business intelligence", companyType: .itCompany, color: "#FF2D92"),
        Department(name: "Data Science", description: "Machine learning and AI development", companyType: .itCompany, color: "#FF2D55"),
        Department(name: "Data Engineering", description: "Data pipeline and infrastructure", companyType: .itCompany, color: "#FF375F"),
        Department(name: "Business Intelligence", description: "BI reporting and analytics", companyType: .itCompany, color: "#FF2D92"),
        
        // Security
        Department(name: "Cybersecurity", description: "Information security and protection", companyType: .itCompany, color: "#FF3B30"),
        Department(name: "Information Security", description: "Security policies and compliance", companyType: .itCompany, color: "#FF453A"),
        
        // Project Management & Business
        Department(name: "IT Project Management", description: "IT project planning and execution", companyType: .itCompany, color: "#FF9500"),
        Department(name: "Product Management", description: "Product strategy and roadmap", companyType: .itCompany, color: "#FF9F0A"),
        Department(name: "Business Analysis", description: "Requirements and business analysis", companyType: .itCompany, color: "#FFCC00"),
        Department(name: "Scrum Masters", description: "Agile project facilitation", companyType: .itCompany, color: "#FFD60A"),
        
        // HR & Administration
        Department(name: "Human Resources", description: "Employee recruitment and management", companyType: .itCompany, color: "#32ADE6"),
        Department(name: "Talent Acquisition", description: "Recruitment and hiring", companyType: .itCompany, color: "#30D5C8"),
        Department(name: "Training & Development", description: "Employee training programs", companyType: .itCompany, color: "#40C8E0"),
        Department(name: "HR Operations", description: "Payroll and employee operations", companyType: .itCompany, color: "#64D2FF"),
        
        // Finance & Accounting
        Department(name: "Finance", description: "Financial planning and analysis", companyType: .itCompany, color: "#FFD60A"),
        Department(name: "Accounting", description: "Financial accounting and reporting", companyType: .itCompany, color: "#FFCC00"),
        Department(name: "Payroll", description: "Employee payroll processing", companyType: .itCompany, color: "#FFD426"),
        Department(name: "Financial Planning", description: "Budget and financial planning", companyType: .itCompany, color: "#FFD60A"),
        
        // Computer Science & Research
        Department(name: "Computer Science Research", description: "CS research and innovation", companyType: .itCompany, color: "#5856D6"),
        Department(name: "AI/ML Research", description: "Artificial intelligence research", companyType: .itCompany, color: "#5E5CE6"),
        Department(name: "Blockchain Development", description: "Blockchain and Web3 development", companyType: .itCompany, color: "#5856D6"),
        
        // Support & Operations
        Department(name: "Technical Support", description: "Customer technical support", companyType: .itCompany, color: "#8E8E93"),
        Department(name: "IT Support", description: "Internal IT support and helpdesk", companyType: .itCompany, color: "#98989D"),
        Department(name: "Customer Success", description: "Customer success and retention", companyType: .itCompany, color: "#8E8E93"),
        
        // Other Industries
        Department(name: "Production", description: "Manufacturing and assembly operations", companyType: .manufacturing, color: "#8E8E93"),
        Department(name: "Quality Control", description: "Product quality assurance", companyType: .manufacturing, color: "#007AFF"),
        Department(name: "Supply Chain", description: "Logistics and supply management", companyType: .manufacturing, color: "#34C759"),
        Department(name: "Patient Care", description: "Direct patient services", companyType: .healthcare, color: "#FF3B30"),
        Department(name: "Investment Banking", description: "Investment and banking services", companyType: .finance, color: "#007AFF"),
        Department(name: "Risk Management", description: "Financial risk assessment", companyType: .finance, color: "#FF9500"),
        Department(name: "Compliance", description: "Regulatory compliance", companyType: .finance, color: "#8E8E93"),
        Department(name: "Sales", description: "Customer sales and service", companyType: .retail, color: "#34C759"),
        Department(name: "Marketing", description: "Product marketing and promotion", companyType: .retail, color: "#FF2D92")
    ]
}

// MARK: - Employee Profile Model
struct EmployeeProfile: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    var profileImageURL: String? = nil
    var department: String? = nil
    var position: String? = nil
    var mobile: String? = nil
    var roleType: String? = nil
    var joinDate: Date? = nil
    var password: String? = nil
    var employmentType: String? = nil
    var resourceType: String? = nil
    var status: String? = nil
    var imageStoragePath: String? = nil // Add storage path field

    init(
        id: String,
        name: String,
        email: String,
        profileImageURL: String? = nil,
        department: String? = nil,
        position: String? = nil,
        mobile: String? = nil,
        roleType: String? = nil,
        joinDate: Date? = nil,
        password: String? = nil,
        employmentType: String? = nil,
        resourceType: String? = nil,
        status: String? = nil,
        imageStoragePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.profileImageURL = profileImageURL
        self.department = department
        self.position = position
        self.mobile = mobile
        self.roleType = roleType
        self.joinDate = joinDate
        self.password = password
        self.employmentType = employmentType
        self.resourceType = resourceType
        self.status = status
        self.imageStoragePath = imageStoragePath
    }
}

struct EmployeeDailyReport: Identifiable, Codable {
    let id: String
    let employeeUid: String?
    let employeeEmail: String?
    let employeeName: String
    let projectName: String
    let date: Date
    let tasksDone: String
    let status: String?
    let dailyHours: String?
    let objective: String?
    let obstacles: String?
    let nextActionPlan: String?
    let comments: String?
    let reportText: String
    let createdAt: Date
    let reportType: String?
}

// MARK: - Lead Management Models
struct Lead: Identifiable, Codable {
    let id: UUID
    var documentId: String?
    let name: String
    let companyName: String?
    let email: String?
    let phone: String?
    let source: String? // e.g., LinkedIn, Referral
    let status: String
    let followUpDate: Date?
    let notes: String?
    let createdAt: Date
    let potentialValue: Double?
    let address: String?
    let productOfInterest: String?
    let sector: String?
    let productCategory: String?
    let priority: String?
    
    init(id: UUID = UUID(), documentId: String? = nil, name: String, companyName: String? = nil, email: String? = nil, phone: String? = nil, source: String? = nil, status: String = "New", followUpDate: Date? = nil, notes: String? = nil, createdAt: Date = Date(), potentialValue: Double? = nil, address: String? = nil, productOfInterest: String? = nil, sector: String? = nil, productCategory: String? = nil, priority: String? = nil) {
        self.id = id
        self.documentId = documentId
        self.name = name
        self.companyName = companyName
        self.email = email
        self.phone = phone
        self.source = source
        self.status = status
        self.followUpDate = followUpDate
        self.notes = notes
        self.createdAt = createdAt
        self.potentialValue = potentialValue
        self.address = address
        self.productOfInterest = productOfInterest
        self.sector = sector
        self.productCategory = productCategory
        self.priority = priority
    }
}

enum LeadStatus: String, CaseIterable, Codable {
    case new = "New"
    case contacted = "Contacted"
    case qualified = "Qualified"
    case proposalSent = "Proposal Sent"
    case negotiation = "Negotiation"
    case converted = "Converted"
    case lost = "Lost"
    case closed = "Closed"
    
    var color: String {
        switch self {
        case .new: return "blue"
        case .contacted: return "orange"
        case .qualified: return "purple"
        case .proposalSent: return "yellow"
        case .negotiation: return "pink"
        case .converted: return "green"
        case .lost: return "red"
        case .closed: return "gray"
        }
    }
    
    static func getColor(for status: String) -> String {
        return LeadStatus(rawValue: status)?.color ?? "gray"
    }
}


// MARK: - Knowledge Management
struct KnowledgeItem: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let createdAt: Date
    let updatedAt: Date
    let attachmentName: String?
    let attachmentURL: String?
    let link: String?
}

enum KnowledgeTab: String, CaseIterable, Identifiable {
    case knowledge = "Knowledge"
    case documentation = "Documentation"
    var id: String { rawValue }
}
