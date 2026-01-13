import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var authService = FirebaseAuthService.shared
    @ObservedObject var firebaseService = FirebaseService.shared
    @State private var selectedTab: SettingsTab = .hierarchy
    @State private var searchText = ""
    @State private var currentPage = 1
    @State private var showEditProfile = false
    @State private var newStatusText = ""
    @State private var statusSearchText = ""
    @State private var showAddStatusSheet = false
    @State private var showEditStatusSheet = false
    @State private var selectedStatusColor: Color = .blue
    @State private var oldStatusName = ""
    
    // Project Level State
    @State private var projectLevelSearchText = ""
    @State private var showAddProjectLevelSheet = false
    @State private var newProjectLevelNumber = ""
    @State private var newProjectLevelName = ""
    @State private var editingProjectLevel: ProjectLevelItem?
    @State private var projectLevelPage = 1
    @State private var hierarchyPage = 1
    @State private var showAddHierarchySheet = false
    @State private var editingHierarchyRole: HierarchyRole?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    
    // ... HierarchyItem struct and data ... (unchanged)
    // Dummy Data for Hierarchy
    struct HierarchyItem: Identifiable {
        let id = UUID()
        let srNo: Int
        let name: String
        let type: String
        let typeColor: Color
    }
    
    let hierarchyData: [HierarchyItem] = [
        HierarchyItem(srNo: 1, name: "Super Admin", type: "SUPER ADMIN ROLE", typeColor: .purple),
        HierarchyItem(srNo: 2, name: "BOD", type: "ADMIN ROLE", typeColor: .blue),
        HierarchyItem(srNo: 3, name: "CEO", type: "ADMIN ROLE", typeColor: .blue),
        HierarchyItem(srNo: 4, name: "Partner-Director", type: "ADMIN ROLE", typeColor: .blue),
        HierarchyItem(srNo: 5, name: "Consultant", type: "MANAGER ROLE", typeColor: .green),
        HierarchyItem(srNo: 6, name: "Project Manager", type: "MANAGER ROLE", typeColor: .green),
        HierarchyItem(srNo: 7, name: "Associate", type: "MEMBER ROLE", typeColor: .gray),
        HierarchyItem(srNo: 8, name: "Associate Consultant", type: "MEMBER ROLE", typeColor: .gray),
        HierarchyItem(srNo: 9, name: "CA-Financial Consultant", type: "MEMBER ROLE", typeColor: .gray),
        HierarchyItem(srNo: 10, name: "CA-Startup Consultant", type: "MEMBER ROLE", typeColor: .gray)
    ]
    
    enum SettingsTab: String, CaseIterable {
        case hierarchy = "Hierarchy"
        case projectLevel = "Project Level"
        case status = "Status"
        case theme = "Theme"
        case profile = "Profile"
        
        var icon: String {
            switch self {
            case .hierarchy: return "person.3.sequence.fill"
            case .projectLevel: return "square.stack.3d.up.fill"
            case .status: return "flag.fill"
            case .theme: return "paintpalette.fill"
            case .profile: return "person.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .hierarchy: return .blue
            case .projectLevel: return .purple
            case .status: return .orange
            case .theme: return .indigo
            case .profile: return .green
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure hierarchy and project preferences in one place.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Content Card
                VStack(spacing: 0) {
                    // Tab Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(SettingsTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    withAnimation {
                                        selectedTab = tab
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: tab.icon)
                                            .foregroundColor(selectedTab == tab ? tab.color : .gray)
                                        Text(tab.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                                            .foregroundColor(selectedTab == tab ? .primary : .gray)
                                    }
                                    .padding(.vertical, 16)
                                    .overlay(
                                        Rectangle()
                                            .fill(selectedTab == tab ? tab.color : Color.clear)
                                            .frame(height: 2)
                                            .offset(y: 16),
                                        alignment: .bottom
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Selected View
                    VStack {
                        switch selectedTab {
                        case .hierarchy:
                            hierarchyView
                        case .projectLevel:
                            projectLevelView
                        case .status:
                            statusView
                        case .theme:
                            themeView
                        case .profile:
                            profileView
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground)) // Adapts to light/dark mode
        .onAppear {
            firebaseService.listenTaskStatusOptions()
            firebaseService.listenProjectLevels()
            firebaseService.listenHierarchy()
        }
        .sheet(isPresented: $showAddHierarchySheet, onDismiss: { editingHierarchyRole = nil }) {
            AddHierarchySheet(isPresented: $showAddHierarchySheet, roleToEdit: editingHierarchyRole)
        }
        .sheet(isPresented: $showEditProfile) {
            if let user = authService.currentUser {
                EditProfileView(user: user, themeManager: themeManager, showEditProfile: $showEditProfile)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .tint(themeManager.accentColor)
    }
    
    // MARK: - Profile Tab View
    private var profileView: some View {
        let user = authService.currentUser
        let initials = user?.name.prefix(1).uppercased() ?? "U"
        let roleName = "\(user?.role ?? .admin)".capitalized
        let createdDate = "December 31, 2025 at 09:44 AM"
        let lastSignInDate = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short)
        
        return VStack(spacing: 20) {
            // Top Card: Basic Info
            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(themeManager.accentColor)
                            .frame(width: 70, height: 70)
                            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                        
                        Text(initials)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(user?.name ?? "User")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(user?.email ?? "email@example.com")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                                .font(.caption)
                                .foregroundColor(themeManager.accentColor)
                            Text(roleName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.accentColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.accentColor.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                
                // Edit Button (Full Width)
                Button(action: {
                    showEditProfile = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Profile")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeManager.accentColor)
                    .cornerRadius(10)
                    .shadow(color: themeManager.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            // Bottom Card: Account Details
            VStack(alignment: .leading, spacing: 16) {
                Text("Account Details")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
                
                VStack(spacing: 16) {
                    detailField(title: "Display Name", value: user?.name ?? "N/A", icon: "person.fill")
                    detailField(title: "Email Address", value: user?.email ?? "N/A", icon: "envelope.fill")
                    detailField(title: "User ID", value: user?.id.uuidString.prefix(8).uppercased() ?? "UNKNOWN", icon: "number")
                    detailField(title: "Role", value: roleName, icon: "briefcase.fill")
                    detailField(title: "Account Created", value: createdDate, icon: "calendar")
                    detailField(title: "Last Sign In", value: lastSignInDate, icon: "clock.fill")
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private func detailField(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(10)
    }


    
    // MARK: - Hierarchy Tab View
    // MARK: - Hierarchy Tab View
    private var hierarchyView: some View {
        let filteredRoles = firebaseService.hierarchyRoles.filter {
            searchText.isEmpty ? true : ($0.name.localizedCaseInsensitiveContains(searchText) || $0.role.localizedCaseInsensitiveContains(searchText))
        }
        
        let itemsPerPage = 10
        let totalPages = max(1, Int(ceil(Double(filteredRoles.count) / Double(itemsPerPage))))
        
        // Ensure current page is valid
        let safePage = min(max(1, hierarchyPage), totalPages)
        
        let startIndex = (safePage - 1) * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredRoles.count)
        
        // Safe slicing
        let paginatedRoles: [HierarchyRole]
        if startIndex < filteredRoles.count {
            paginatedRoles = Array(filteredRoles[startIndex..<endIndex])
        } else {
            paginatedRoles = []
        }
        
        return VStack(spacing: 20) {
            hierarchySearchAndActions(totalCount: filteredRoles.count)
            hierarchyList(paginatedRoles: paginatedRoles, startIndex: startIndex, totalPages: totalPages, safePage: safePage)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private func hierarchySearchAndActions(totalCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Responsive Header
            ViewThatFits(in: .horizontal) {
                // Wide Layout (Web-like)
                HStack(alignment: .center) {
                    Text("Search & Actions")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Text("Showing \(totalCount) records")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize()
                        
                        addHierarchyButton
                    }
                }
                
                // Narrow Layout (Mobile Optimized)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search & Actions")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Spacer()
                        Text("Showing \(totalCount) records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        addHierarchyButton
                    }
                }
            }
            
            // Search Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Search by hierarchy type or name")
                    .font(.caption) // Smaller, standard label
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search by type or name", text: $searchText)
                        .font(.system(size: 14)) // Standard text size
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var addHierarchyButton: some View {
        Button(action: {
            showAddHierarchySheet = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add Hierarchy")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple)
            .cornerRadius(8) // Standard rounded corners, not full capsule
        }
    }
    
    private func hierarchyList(paginatedRoles: [HierarchyRole], startIndex: Int, totalPages: Int, safePage: Int) -> some View {
        VStack(spacing: 0) {
            // Card Header
            HStack {
                Text("Hierarchy List")
                    .font(.headline)
                Spacer()
            }
            .padding(20)
            
            Divider()
            
            // Pagination Row
            HStack {
                Text("Page \(safePage) of \(totalPages)")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 10) {
                    Button(action: {
                        if hierarchyPage > 1 { hierarchyPage -= 1 }
                    }) {
                        Text("Prev")
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(hierarchyPage > 1 ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
                            .cornerRadius(6)
                            .foregroundColor(hierarchyPage > 1 ? .primary : .secondary)
                    }
                    .disabled(hierarchyPage <= 1)
                    
                    Button(action: {
                        if hierarchyPage < totalPages { hierarchyPage += 1 }
                    }) {
                        Text("Next")
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(hierarchyPage < totalPages ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
                            .cornerRadius(6)
                            .foregroundColor(hierarchyPage < totalPages ? .primary : .secondary)
                    }
                    .disabled(hierarchyPage >= totalPages)
                }
            }
            .padding(20)
            
            // Scrollable Table Area
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Table Header
                    HStack(spacing: 0) {
                        Text("SR. NO.")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        Text("NAME")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 300, alignment: .leading)
                            .padding(.leading, 20)
                        
                        Text("TYPE")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 180, alignment: .leading)
                        
                        Text("ACTIONS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.05))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.1)),
                        alignment: .bottom
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.1)),
                            alignment: .top
                    )
                    
                    // Table Rows
                    VStack(spacing: 0) {
                        ForEach(Array(paginatedRoles.enumerated()), id: \.element) { index, item in
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    Text("\(startIndex + index + 1)")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 300, alignment: .leading)
                                        .lineLimit(1)
                                        .padding(.leading, 20)
                                        .padding(.trailing, 20)
                                    
                                    // Badge
                                    Text(item.role.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(roleColor(for: item.role))
                                        .cornerRadius(6)
                                        .frame(width: 180, alignment: .leading)
                                    
                                    HStack(spacing: 16) {
                                        Button(action: {
                                            editingHierarchyRole = item
                                            showAddHierarchySheet = true
                                        }) {
                                            Image(systemName: "square.and.pencil")
                                                .font(.system(size: 16))
                                                .foregroundColor(.orange)
                                        }
                                        Button(action: {
                                            FirebaseService.shared.deleteHierarchyRole(roleToDelete: item) { _ in }
                                        }) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .frame(width: 100, alignment: .center)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground))
                                
                                Divider()
                            }
                        }
                    }
                }
                .frame(minWidth: 700)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "super admin role", "super admin", "superadmin": return .purple
        case "admin role", "admin": return .blue
        case "manager role", "manager": return .green
        case "member role", "member": return .gray
        default: return .blue
        }
    }

    // MARK: - Project Level View
    private var projectLevelView: some View {
        VStack(spacing: 24) {
            // Search & Actions
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Search & Actions")
                            .font(.headline)
                        Text("Showing \(filteredProjectLevels.count) records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        newProjectLevelNumber = ""
                        newProjectLevelName = ""
                        editingProjectLevel = nil
                        showAddProjectLevelSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Project Level")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search by level name", text: $projectLevelSearchText)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)

            // Table
            VStack(spacing: 0) {
                 // Pagination Logic
                 let itemsPerPage = 10
                 let totalItems = filteredProjectLevels.count
                 let totalPages = max(1, Int(ceil(Double(totalItems) / Double(itemsPerPage))))
                 let currentPage = min(max(1, projectLevelPage), totalPages)
                 let startIndex = (currentPage - 1) * itemsPerPage
                 let endIndex = min(startIndex + itemsPerPage, totalItems)
                 let pageItems = startIndex < endIndex ? Array(filteredProjectLevels[startIndex..<endIndex]) : []

                 // Pagination Header
                HStack {
                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: { if currentPage > 1 { projectLevelPage = currentPage - 1 } }) {
                            Text("Prev")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .disabled(currentPage <= 1)
                        .opacity(currentPage <= 1 ? 0.6 : 1.0)
                        
                        Button(action: { if currentPage < totalPages { projectLevelPage = currentPage + 1 } }) {
                            Text("Next")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .disabled(currentPage >= totalPages)
                        .opacity(currentPage >= totalPages ? 0.6 : 1.0)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Header Row
                HStack {
                    Text("SR. NO.")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 60, alignment: .leading)
                    Text("LEVEL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 80, alignment: .leading)
                    Text("NAME")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("ACTIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 100, alignment: .center)
                }
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Rows
                ForEach(Array(pageItems.enumerated()), id: \.element) { index, item in
                    VStack(spacing: 0) {
                        HStack {
                            Text("\(startIndex + index + 1)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            Text(item.level)
                                .font(.system(size: 14))
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(item.name)
                                .font(.system(size: 14))
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 16) {
                                Button(action: {
                                    editingProjectLevel = item
                                    newProjectLevelNumber = item.level
                                    newProjectLevelName = item.name
                                    showAddProjectLevelSheet = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14))
                                }
                                
                                Button(action: {
                                    firebaseService.removeProjectLevel(item: item) { error in
                                        if let error = error { print("Error deleting: \(error)") }
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.system(size: 14))
                                }
                            }
                            .frame(width: 100, alignment: .center)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        Divider()
                    }
                }
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.bottom)
            
            Spacer()
        }
        .padding(.top)
        .onChange(of: projectLevelSearchText) { _ in
            projectLevelPage = 1
        }
        .overlay {
            if showAddProjectLevelSheet {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all).onTapGesture { showAddProjectLevelSheet = false }
                
                AddProjectLevelSheet(
                    level: $newProjectLevelNumber,
                    name: $newProjectLevelName,
                    isEditing: editingProjectLevel != nil,
                    onCancel: { showAddProjectLevelSheet = false },
                    onSave: {
                        if let item = editingProjectLevel {
                             var updated = item
                             updated.level = newProjectLevelNumber
                             updated.name = newProjectLevelName
                             firebaseService.updateProjectLevel(item: updated) { _ in showAddProjectLevelSheet = false }
                        } else {
                             firebaseService.addProjectLevel(level: newProjectLevelNumber, name: newProjectLevelName) { _ in showAddProjectLevelSheet = false }
                        }
                    }
                )
                .transition(.scale)
            }
        }
    }
    
    private var filteredProjectLevels: [ProjectLevelItem] {
        if projectLevelSearchText.isEmpty {
            return firebaseService.projectLevels
        } else {
            return firebaseService.projectLevels.filter { $0.name.localizedCaseInsensitiveContains(projectLevelSearchText) }
        }
    }
    private func placeholderView(title: String) -> some View {
        VStack {
            Image(systemName: "gear")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            Text("Coming soon...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 300)
    }
    
    // MARK: - Status Tab View
    private var statusView: some View {
        VStack(spacing: 24) {
             // Search & Actions Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Search & Actions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Search by status name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    HStack {
                        Text("Showing \(filteredStatuses.count) records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            newStatusText = ""
                            selectedStatusColor = themeManager.accentColor
                            showAddStatusSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Status")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple) // Matches the purple button in image
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search by status name", text: $statusSearchText)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)

            // Table Card
            VStack(spacing: 0) {
                 // Pagination (Top)
                HStack {
                    Text("Page \(currentPage) of \(Int(ceil(Double(max(filteredStatuses.count, 1)) / 10.0)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: {
                            if currentPage > 1 { currentPage -= 1 }
                        }) {
                            Text("Prev")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .disabled(currentPage <= 1)
                        .opacity(currentPage <= 1 ? 0.6 : 1.0)
                        
                        Button(action: {
                            let totalPages = Int(ceil(Double(filteredStatuses.count) / 10.0))
                            if currentPage < totalPages { currentPage += 1 }
                        }) {
                            Text("Next")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .disabled(currentPage >= Int(ceil(Double(filteredStatuses.count) / 10.0)))
                        .opacity(currentPage >= Int(ceil(Double(filteredStatuses.count) / 10.0)) ? 0.6 : 1.0)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Header Row
                HStack {
                    Text("SR. NO.")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 60, alignment: .leading)
                    Text("STATUS NAME")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("ACTIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 100, alignment: .center)
                }
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Rows
                let startIndex = (currentPage - 1) * 10
                let endIndex = min(startIndex + 10, filteredStatuses.count)
                let pageItems = startIndex < endIndex ? Array(filteredStatuses[startIndex..<endIndex]) : []
                
                ForEach(Array(pageItems.enumerated()), id: \.element) { index, status in
                    VStack(spacing: 0) {
                        HStack {
                            Text("\(startIndex + index + 1)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            // Status Badge
                            Text(status.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor(for: status))
                                .cornerRadius(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Actions
                            HStack(spacing: 0) {
                                if isDefaultStatus(status) {
                                    Text("DEFAULT")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                } else {
                                    HStack(spacing: 16) {
                                        Button(action: {
                                            oldStatusName = status
                                            newStatusText = status
                                            selectedStatusColor = statusColor(for: status)
                                            showEditStatusSheet = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 14))
                                        }
                                        
                                        Button(action: {
                                            firebaseService.removeTaskStatus(status) { error in
                                                if let error = error {
                                                    print("Error deleting status: \(error)")
                                                }
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.system(size: 14))
                                        }
                                    }
                                }
                            }
                            .frame(width: 100, alignment: .center)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        
                        Divider()
                    }
                }
                
                Spacer() // Push content up if list is short
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.bottom)
            
            Spacer()
        }
        .padding(.top)
        .overlay {
            if showAddStatusSheet {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showAddStatusSheet = false
                    }
                
                AddStatusSheet(
                    statusName: $newStatusText,
                    selectedColor: $selectedStatusColor,
                    onCancel: { showAddStatusSheet = false },
                    onSave: {
                        let trimmed = newStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        
                        let hexString = selectedStatusColor.toHex() ?? "#000000"
                        
                        firebaseService.addTaskStatus(trimmed, color: hexString) { error in
                            if let error = error {
                                print("Error adding status: \(error.localizedDescription)")
                            }
                            showAddStatusSheet = false
                        }
                    }
                )
                .padding()
                .transition(.scale)
            }
            
            if showEditStatusSheet {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showEditStatusSheet = false
                    }
                
                EditStatusSheet(
                    statusName: $newStatusText,
                    selectedColor: $selectedStatusColor,
                    onCancel: { showEditStatusSheet = false },
                    onUpdate: {
                        let trimmed = newStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        
                        let hexString = selectedStatusColor.toHex() ?? "#000000"
                        
                        firebaseService.updateTaskStatus(oldName: oldStatusName, newName: trimmed, newColor: hexString) { error in
                            if let error = error {
                                print("Error updating status: \(error.localizedDescription)")
                            }
                            showEditStatusSheet = false
                        }
                    }
                )
                .padding()
                .transition(.scale)
            }
        }
    }
    
    private var filteredStatuses: [String] {
        var statuses = firebaseService.taskStatusOptions.filter { $0.caseInsensitiveCompare("All") != .orderedSame }
        
        if !statusSearchText.isEmpty {
            statuses = statuses.filter { $0.localizedCaseInsensitiveContains(statusSearchText) }
        }
        
        // Enforce specific order: To Do, In Progress, Done
        // We move these to the front if they exist
        let priorityOrder = ["TODO", "TO DO", "IN PROGRESS", "DONE"]
        
        statuses.sort { a, b in
            let aUpper = a.uppercased()
            let bUpper = b.uppercased()
            
            let aIndex = priorityOrder.firstIndex { aUpper == $0 || aUpper.contains($0) } ?? Int.max
            let bIndex = priorityOrder.firstIndex { bUpper == $0 || bUpper.contains($0) } ?? Int.max
            
            if aIndex != bIndex {
                return aIndex < bIndex
            }
            
            // Fallback to original order or alphabetical
            return firebaseService.taskStatusOptions.firstIndex(of: a) ?? 0 < firebaseService.taskStatusOptions.firstIndex(of: b) ?? 0
        }
        
        return statuses
    }
    
    private func isDefaultStatus(_ status: String) -> Bool {
        let defaults = ["All", "Today's Task", "TODO", "TO DO", "In Progress", "Done", "Recurring Task"]
        return defaults.contains { $0.caseInsensitiveCompare(status) == .orderedSame }
    }
    
    private func statusColor(for status: String) -> Color {
        // First check dynamic colors
        if let hex = firebaseService.taskStatusColors[status], let color = Color(hex: hex) {
            return color
        }
        
        // Fallback to defaults
        switch status.uppercased() {
        case "TODO", "TO DO", "TO-DO": return Color.gray
        case "IN PROGRESS": return Color.orange
        case "DONE", "COMPLETED": return Color.green
        case "HOLD BY CLIENT", "ON HOLD BY CLIENT": return Color.purple
        case "NEED HELP": return Color.blue
        case "STUCK": return Color.pink
        case "WAITING FOR": return Color.yellow
        case "CANCELED", "CANCELLED": return Color.red
        default: return themeManager.accentColor
        }
    }
    
    private var themeView: some View {
        VStack(spacing: 24) {
             // Appearance Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Picker("Appearance", selection: $themeManager.appearance) {
                    Text("Light").tag(ThemeAppearance.light)
                    Text("Dark").tag(ThemeAppearance.dark)
                    Text("Auto").tag(ThemeAppearance.system)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Accent Color Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Accent Color")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ThemeAccent.allCases, id: \.self) { acc in
                        Button(action: {
                            withAnimation {
                                themeManager.accent = acc
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(acc.color)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                
                                if themeManager.accent == acc {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
        .padding(.top)
    }
}

// MARK: - Add Status Sheet Layout
struct AddStatusSheet: View {
    @Binding var statusName: String
    @Binding var selectedColor: Color
    var onCancel: () -> Void
    var onSave: () -> Void
    
    let colors: [Color] = [
        .blue, .purple, .green, .mint, .teal, .cyan, .indigo,
        .orange, .red, .pink, .yellow, .gray, .brown
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Status")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
            }
            
            // Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Status Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 24, height: 24)
                    
                    TextField("e.g. On Hold, Awaiting Client...", text: $statusName)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    Image(systemName: "mic")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
            }
            
            // Color Picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 30), spacing: 12), count: 7), spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .onTapGesture {
                                    selectedColor = color
                                }
                            
                            if selectedColor == color {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            
            // Footer Buttons
            HStack(spacing: 12) {
                Spacer()
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(25)
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                
                Button(action: onSave) {
                    HStack {
                        Image(systemName: "floppy.disk")
                        Text("Save")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple) // Matches UI
                    .cornerRadius(25)
                }
            }
            .padding(.top, 10)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 450)
    }
}

// MARK: - Edit Status Sheet Layout
struct EditStatusSheet: View {
            @Binding var statusName: String
            @Binding var selectedColor: Color
            var onCancel: () -> Void
            var onUpdate: () -> Void
            
            let colors: [Color] = [
                .blue, .purple, .green, .mint, .teal, .cyan, .indigo,
                .orange, .red, .pink, .yellow, .gray, .brown
            ]
            
            var body: some View {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Edit Status")
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 24, height: 24)
                            
                            TextField("e.g. On Hold, Awaiting Client...", text: $statusName)
                                .textFieldStyle(PlainTextFieldStyle())
                            
                            Image(systemName: "mic")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                    }
                    
                    // Color Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 30), spacing: 12), count: 7), spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                ZStack {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                    
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    
                    // Footer Buttons
                    HStack(spacing: 12) {
                        Spacer()
                        
                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(25)
                                .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        
                        Button(action: onUpdate) {
                            HStack {
                                Image(systemName: "floppy.disk")
                                Text("Update")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.purple) // Matches UI
                            .cornerRadius(25)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .frame(maxWidth: 450)
    }
}
        
        
struct EditProfileView: View {
            @State var displayName: String
            let user: User
            let themeManager: ThemeManager
            @Binding var showEditProfile: Bool
            
            init(user: User, themeManager: ThemeManager, showEditProfile: Binding<Bool>) {
                self.user = user
                self.themeManager = themeManager
                self._showEditProfile = showEditProfile
                self._displayName = State(initialValue: user.name)
            }
            
            var body: some View {
                NavigationView {
                    Form {
                        Section(header: Text("Account Details")) {
                            // Display Name - Editable
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Display Name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("*")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                TextField("Enter name", text: $displayName)
                                    .padding(.vertical, 4)
                            }
                            
                            // Email - Read Only
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Email Address")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("*")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Text(user.email)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text("Changing email may require re-login")
                                        .font(.caption)
                                }
                                .foregroundColor(.orange)
                            }
                            
                            // User ID - Read Only
                            VStack(alignment: .leading, spacing: 6) {
                                Text("User ID")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(user.id.uuidString)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            }
                            
                            // Role - Read Only
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Role")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(user.role)".capitalized)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            }
                        }
                        
                        Section(header: Text("Account Info")) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Account Created")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("December 31, 2025 at 09:44 AM")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Sign In")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .navigationTitle("Edit Profile")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showEditProfile = false
                        }
                            .foregroundColor(.red),
                        trailing: Button("Save") {
                            // Update user profile
                            FirebaseAuthService.shared.updateProfile(name: displayName, email: nil, phone: nil) { result in
                                switch result {
                                case .success:
                                    print("✅ Profile updated successfully")
                                    showEditProfile = false
                                case .failure(let error):
                                    print("❌ Error updating profile: \(error.localizedDescription)")
                                    // Ideally show an alert here, but for now we just verify functionality
                                }
                            }
                        }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(themeManager.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    )
                }
                }
            }
        



// MARK: - Add/Edit Project Level Sheet
struct AddProjectLevelSheet: View {
    @Binding var level: String
    @Binding var name: String
    var isEditing: Bool
    var onCancel: () -> Void
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text(isEditing ? "Edit Project Level" : "Create Project Level")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 4)
            
            HStack(alignment: .top, spacing: 16) {
                // Project Level Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Level")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField("1", text: $level)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        .keyboardType(.numberPad)
                        .onChange(of: level) { newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue {
                                self.level = filtered
                            }
                        }
                }
                .frame(width: 100)
                
                // Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., Discovery", text: $name)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                }
            }
            
            // Footer Buttons
            HStack(spacing: 12) {
                Spacer()
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(25)
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                
                Button(action: onSave) {
                    Text(isEditing ? "Update" : "Save")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(25)
                }
            }
            .padding(.top, 10)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 500)
    }
}

struct AddHierarchySheet: View {
    @Binding var isPresented: Bool
    var roleToEdit: HierarchyRole?
    
    @State private var selectedRoleType: String = "Super Admin Role"
    @State private var roleName: String = ""
    @State private var isLoading = false
    
    let roleOptions = ["Super Admin Role", "Admin Role", "Manager Role", "Member Role"]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text(roleToEdit == nil ? "Create Hierarchy" : "Edit Hierarchy")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            
            Divider()
            
            // Role Type Filter Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(roleOptions, id: \.self) { role in
                        Button(action: {
                            selectedRoleType = role
                        }) {
                            Text(role)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .foregroundColor(selectedRoleType == role ? .white : .secondary)
                                .background(selectedRoleType == role ? Color.black : Color.clear)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(4)
                .background(Color(.systemGray6))
                .cornerRadius(24)
            }
            
            // Input Field
            VStack(alignment: .leading, spacing: 8) {
                Text(roleToEdit == nil ? "Add \(selectedRoleType)" : "Update \(selectedRoleType)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                TextField("e.g. \(placeholderForRole(selectedRoleType))", text: $roleName)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            
            Spacer()
            
            // Footer
            HStack(spacing: 12) {
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Button(action: saveHierarchy) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(roleToEdit == nil ? "Save" : "Update")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(roleName.isEmpty ? Color.gray : Color.purple)
                            .cornerRadius(8)
                    }
                }
                .disabled(roleName.isEmpty || isLoading)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            if let role = roleToEdit {
                selectedRoleType = mapInternalRoleToDisplay(role.role)
                roleName = role.name
            }
        }
    }
    
    private func placeholderForRole(_ role: String) -> String {
        switch role {
        case "Super Admin Role": return "Super Admin"
        case "Admin Role": return "Director"
        case "Manager Role": return "Project Manager"
        case "Member Role": return "Developer"
        default: return "Role Name"
        }
    }
    
    private func saveHierarchy() {
        guard !roleName.isEmpty else { return }
        isLoading = true
        
        let internalRole = mapDisplayRoleToInternal(selectedRoleType)
        
        if let roleToUpdate = roleToEdit {
            FirebaseService.shared.updateHierarchyRole(roleToUpdate: roleToUpdate, newName: roleName, newRoleType: internalRole) { success in
                isLoading = false
                if success {
                    isPresented = false
                }
            }
        } else {
            FirebaseService.shared.addHierarchyRole(name: roleName, role: internalRole) { success in
                isLoading = false
                if success {
                    isPresented = false
                }
            }
        }
    }
    
    private func mapDisplayRoleToInternal(_ displayRole: String) -> String {
        switch displayRole {
        case "Super Admin Role": return "superadmin"
        case "Admin Role": return "admin"
        case "Manager Role": return "manager"
        case "Member Role": return "member"
        default: return displayRole.lowercased().replacingOccurrences(of: " role", with: "")
        }
    }
    
    private func mapInternalRoleToDisplay(_ internalRole: String) -> String {
        switch internalRole.lowercased() {
        case "superadmin", "super admin": return "Super Admin Role"
        case "admin": return "Admin Role"
        case "manager": return "Manager Role"
        case "member": return "Member Role"
        default: return "Member Role" // Default fallback
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
