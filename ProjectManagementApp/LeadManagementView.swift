import SwiftUI
import FirebaseFirestore
import Firebase

struct LeadManagementView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var searchText = ""
    @State private var showingAddLead = false
    @State private var selectedLead: Lead?
    @State private var leadToEdit: Lead?
    @State private var leadToDelete: Lead?
    @State private var showingDeleteAlert = false
    @State private var selectedTab: String = "Leads" // Leads or Follow-ups
    @State private var isGridView = false
    
    var filteredLeads: [Lead] {
        let baseLeads: [Lead]
        
        if selectedTab == "Follow-ups" {
            // Show leads with follow-ups sorted by date (earliest first)
            baseLeads = firebaseService.leads
                .filter { $0.followUpDate != nil }
                .sorted { ($0.followUpDate ?? Date.distantFuture) < ($1.followUpDate ?? Date.distantFuture) }
        } else {
            // Show all leads
            baseLeads = firebaseService.leads
        }
        
        if searchText.isEmpty {
            return baseLeads
        } else {
            return baseLeads.filter { lead in
                lead.name.lowercased().contains(searchText.lowercased()) ||
                (lead.companyName?.lowercased().contains(searchText.lowercased()) ?? false) ||
                (lead.email?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
    }
    
    // Stats
    var totalLeads: Int { firebaseService.leads.count }
    
    var activeLeads: Int {
        firebaseService.leads.filter {
            $0.status != "Converted" && $0.status != "Lost"
        }.count
    }
    
    var convertedLeads: Int {
        firebaseService.leads.filter { $0.status == "Converted" }.count
    }
    
    var overdueFollowUps: Int {
        let now = Date()
        return firebaseService.leads.filter {
            if let date = $0.followUpDate {
                return date < now && $0.status != "Converted" && $0.status != "Lost"
            }
            return false
        }.count
    }
    
    private func getStatusColor(_ status: String) -> Color {
        let colorName = LeadStatus.getColor(for: status)
        switch colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lead Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tracker for potential clients and business opportunities.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Tabs
                HStack(spacing: 20) {
                    TabButton(title: "Leads", icon: "person.3.fill", isSelected: selectedTab == "Leads") {
                        selectedTab = "Leads"
                    }
                    
                    TabButton(title: "Follow-ups", icon: "phone.fill", isSelected: selectedTab == "Follow-ups") {
                        selectedTab = "Follow-ups"
                    }
                    
                    Spacer()
                }
                
                // Stats Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        LeadStatCard(title: "Total Leads", value: "\(totalLeads)", icon: "person.fill", color: .blue)
                        LeadStatCard(title: "Active Leads", value: "\(activeLeads)", icon: "clock.fill", color: .purple)
                        LeadStatCard(title: "Converted", value: "\(convertedLeads)", icon: "checkmark", color: .green)
                        LeadStatCard(title: "Overdue Follow-ups", value: "\(overdueFollowUps)", icon: "exclamationmark.triangle.fill", color: .red)
                    }
                    .padding(.vertical, 8)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search & Actions")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField(selectedTab == "Follow-ups" ? "Search follow-ups..." : "Search leads...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Actions Row
                    HStack(spacing: 16) {
                        // Add Lead Button
                        Button(action: {
                            showingAddLead = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Add Lead")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.purple)
                            .cornerRadius(20)
                        }
                        
                        // View Toggle
                        HStack(spacing: 0) {
                            Button(action: { isGridView = false }) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(!isGridView ? .purple : .gray)
                                    .frame(width: 44, height: 36)
                                    .background(!isGridView ? Color.white : Color.clear)
                                    .cornerRadius(8)
                                    .shadow(color: !isGridView ? .gray.opacity(0.2) : .clear, radius: 2, y: 1)
                            }
                            
                            Button(action: { isGridView = true }) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isGridView ? .purple : .gray)
                                    .frame(width: 44, height: 36)
                                    .background(isGridView ? Color.white : Color.clear)
                                    .cornerRadius(8)
                                    .shadow(color: isGridView ? .gray.opacity(0.2) : .clear, radius: 2, y: 1)
                            }
                        }
                        .padding(2)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)
            
            // Leads List
            if firebaseService.leads.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Leads Found")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Add your first lead to start tracking")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredLeads.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Results")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if isGridView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(filteredLeads) { lead in
                                LeadGridCard(
                                    lead: lead,
                                    onEdit: {
                                        leadToEdit = lead
                                    },
                                    onDelete: {
                                        leadToDelete = lead
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding()
                    } else {
                        // Card List View
                        ScrollView {
                            VStack(spacing: 16) {
                                // Header
                                HStack {
                                    Text("Leads List")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("\(filteredLeads.count) leads")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                                
                                // Cards
                                LazyVStack(spacing: 16) {
                                    ForEach(Array(filteredLeads.enumerated()), id: \.element.id) { index, lead in
                                        LeadCardRow(
                                            lead: lead,
                                            index: index + 1,
                                            onEdit: {
                                                leadToEdit = lead
                                            },
                                            onDelete: {
                                                leadToDelete = lead
                                                showingDeleteAlert = true
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            if firebaseService.leads.isEmpty {
                firebaseService.fetchLeads()
            }
        }
        .sheet(isPresented: $showingAddLead) {
            AddLeadView()
        }
        .sheet(item: $leadToEdit) { lead in
            AddLeadView(existingLead: lead)
        }
        .alert("Confirm Delete", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let lead = leadToDelete, let docId = lead.documentId {
                    firebaseService.deleteLead(documentId: docId) { error in
                        if let error = error {
                            print("Error deleting lead: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \(leadToDelete?.name ?? "this lead")?")
        }
    }
}

// MARK: - Helper Components

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .blue : .gray)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct LeadStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
            }
        }
        .padding()
        .frame(width: 200) // Wider card
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.5), lineWidth: 1.5)
        )
    }
}

struct LeadGridCard: View {
    let lead: Lead
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    var statusColor: Color {
        let colorName = LeadStatus.getColor(for: lead.status)
        switch colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "green": return .green
        case "red": return .red
        case "gray": return .gray
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Name, Company and Status
            HStack(alignment: .top, spacing: 12) {
                // Avatar Circle with SR Number
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [statusColor.opacity(0.4), statusColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 55, height: 55)
                    .overlay(
                        Text(lead.name.prefix(2).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(lead.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    if let company = lead.companyName, !company.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(company)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // Status Badge
                Circle()
                    .stroke(statusColor, lineWidth: 3)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(lead.status.prefix(3).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                    )
            }
            .padding()
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Data Rows Section
            VStack(alignment: .leading, spacing: 0) {
                // Manager/Contact Person Row
                DataRow(
                    icon: "person.fill",
                    iconColor: .blue,
                    label: "Contact",
                    value: lead.name
                )
                
                // Email Row
                if let email = lead.email, !email.isEmpty {
                    DataRow(
                        icon: "envelope.fill",
                        iconColor: .purple,
                        label: "Email",
                        value: email
                    )
                }
                
                // Phone Row
                if let phone = lead.phone, !phone.isEmpty {
                    DataRow(
                        icon: "phone.fill",
                        iconColor: .green,
                        label: "Phone",
                        value: phone
                    )
                }
                
                // Date Row (Start/Created)
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.green)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Created")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(lead.createdAt.formatted(date: .numeric, time: .omitted))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Follow-up Date (End)
                    if let followUp = lead.followUpDate {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Follow-up")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(followUp.formatted(date: .numeric, time: .omitted))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Status & Priority Row
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(statusColor)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Status")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(lead.status)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(statusColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let priority = lead.priority {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Priority")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(priority)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                
                // Product Row
                if let product = lead.productOfInterest, !product.isEmpty {
                    DataRow(
                        icon: "cube.fill",
                        iconColor: .indigo,
                        label: "Product",
                        value: product
                    )
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                        Text("View")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.caption)
                        Text("Edit")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 44)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: statusColor.opacity(0.2), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: 2)
        )
    }
}

// Helper view for data rows
struct DataRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}




struct AddLeadView: View {
    let existingLead: Lead?
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    init(existingLead: Lead? = nil) {
        self.existingLead = existingLead
        _status = State(initialValue: existingLead?.status ?? "New")
        _date = State(initialValue: existingLead?.createdAt ?? Date())
        
        if let lead = existingLead {
            _name = State(initialValue: lead.name)
            _companyName = State(initialValue: lead.companyName ?? "")
            _email = State(initialValue: lead.email ?? "")
            _phone = State(initialValue: lead.phone ?? "")
            _address = State(initialValue: lead.address ?? "")
            _potentialValue = State(initialValue: lead.potentialValue != nil ? String(format: "%.2f", lead.potentialValue!) : "")
            _productOfInterest = State(initialValue: lead.productOfInterest ?? "")
            _sector = State(initialValue: lead.sector ?? "")
            _source = State(initialValue: lead.source ?? "")
            _productCategory = State(initialValue: lead.productCategory ?? "")
            _priority = State(initialValue: lead.priority ?? "Medium")
            _notes = State(initialValue: lead.notes ?? "")
            
            if let fDate = lead.followUpDate {
                _hasFollowUp = State(initialValue: true)
                _followUpDate = State(initialValue: fDate)
            }
        }
    }
    
    // Form Fields
    @State private var date = Date()
    @State private var name = ""
    @State private var companyName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var potentialValue = ""
    
    // Dropdowns
    @State private var productOfInterest = ""
    @State private var sector = ""
    @State private var source = ""
    @State private var productCategory = ""
    @State private var status: String = "New"
    @State private var priority = "Medium"
    
    // Follow up & Notes
    @State private var followUpDate = Date()
    @State private var hasFollowUp = false
    @State private var notes = ""
    
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    // Validation
    var isFormValid: Bool {
        !name.isEmpty &&
        !companyName.isEmpty &&
        phone.count == 10 &&
        !email.isEmpty &&
        email.contains("@") &&
        email.lowercased().hasSuffix(".com")
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundColor(.purple)
                            .padding(8)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("Add New Lead")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Create a new lead entry")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 10)
                    
                    // Form Stack
                    LazyVStack(spacing: 20) {
                        
                        // Basic Info
                        FormField(label: "Customer Name", required: true) {
                            TextField("Enter name", text: $name)
                        }
                        
                        FormField(label: "Contact Number", required: true) {
                            HStack {
                                Text("+91")
                                    .foregroundColor(.gray)
                                TextField("Enter number", text: $phone)
                                    .keyboardType(.phonePad)
                                    .onChange(of: phone) { newValue in
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        if filtered != newValue {
                                            phone = filtered
                                        }
                                        if phone.count > 10 {
                                            phone = String(phone.prefix(10))
                                        }
                                    }
                            }
                        }
                        
                        FormField(label: "Email Address", required: true) {
                            TextField("Enter email", text: $email)
                                .keyboardType(.emailAddress)
                        }
                        
                        FormField(label: "Customer Company", required: true) {
                            TextField("Enter company name", text: $companyName)
                        }
                        
                        FormField(label: "Address") {
                            TextField("Enter address", text: $address)
                        }
                        
                        // Lead Details
                        FormField(label: "Date", required: true) {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        FormField(label: "Potential Value (₹)") {
                            TextField("0.00", text: $potentialValue)
                                .keyboardType(.decimalPad)
                                .onChange(of: potentialValue) { newValue in
                                    let filtered = newValue.filter { "0123456789.".contains($0) }
                                    if filtered != newValue {
                                        potentialValue = filtered
                                    }
                                }
                        }
                        
                        FormField(label: "Product of Interest", required: true) {
                            Menu {
                                ForEach(firebaseService.leadProducts, id: \.self) { item in
                                    Button(item) { productOfInterest = item }
                                }
                            } label: {
                                HStack {
                                    Text(productOfInterest.isEmpty ? "Select product" : productOfInterest)
                                        .foregroundColor(productOfInterest.isEmpty ? .gray.opacity(0.5) : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        FormField(label: "Sector", required: true) {
                            Menu {
                                ForEach(firebaseService.leadSectors, id: \.self) { item in
                                    Button(item) { sector = item }
                                }
                            } label: {
                                HStack {
                                    Text(sector.isEmpty ? "Select sector" : sector)
                                        .foregroundColor(sector.isEmpty ? .gray.opacity(0.5) : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        FormField(label: "Source of Lead", required: true) {
                            Menu {
                                ForEach(firebaseService.leadSources, id: \.self) { item in
                                    Button(item) { source = item }
                                }
                            } label: {
                                HStack {
                                    Text(source.isEmpty ? "Select source" : source)
                                        .foregroundColor(source.isEmpty ? .gray.opacity(0.5) : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        FormField(label: "Product Category", required: true) {
                            Menu {
                                ForEach(firebaseService.leadCategories, id: \.self) { item in
                                    Button(item) { productCategory = item }
                                }
                            } label: {
                                HStack {
                                    Text(productCategory.isEmpty ? "Select category" : productCategory)
                                        .foregroundColor(productCategory.isEmpty ? .gray.opacity(0.5) : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        FormField(label: "Status") {
                            Menu {
                                ForEach(firebaseService.leadStatuses, id: \.self) { item in
                                    Button(item) { status = item }
                                }
                            } label: {
                                HStack {
                                    Text(status.isEmpty ? "Select status" : status)
                                        .foregroundColor(status.isEmpty ? .gray.opacity(0.5) : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        FormField(label: "Priority") {
                            Menu {
                                ForEach(firebaseService.leadPriorities, id: \.self) { item in
                                    Button(item) { priority = item }
                                }
                            } label: {
                                HStack {
                                    Text(priority.isEmpty ? "Select priority" : priority)
                                        .foregroundColor(priority.isEmpty ? .gray.opacity(0.5) : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Follow Up Date
                    FormField(label: "Follow-up Date") {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.gray)
                            DatePicker("", selection: $followUpDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }
                    
                    // Notes
                    FormField(label: "Notes") {
                        TextEditor(text: $notes)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Footer Buttons
                    HStack(spacing: 16) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        Button(action: saveLead) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(existingLead == nil ? "Add Lead" : "Save Changes")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.purple : Color.purple.opacity(0.3))
                        .cornerRadius(10)
                        .disabled(!isFormValid || isSubmitting)
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
            .onAppear {
                firebaseService.fetchLeadSettings()
            }
        }
    }
    
    private func saveLead() {
        isSubmitting = true
        
        var data: [String: Any] = [
            "customerName": name,
            "companyName": companyName,
            "email": email,
            "phone": phone,
            "source": source,
            "status": status,
            "notes": notes,
            "createdAt": Timestamp(date: date),
            "address": address,
            "productOfInterest": productOfInterest,
            "sector": sector,
            "productCategory": productCategory,
            "priority": priority
        ]
        
        if let val = Double(potentialValue) {
            data["potentialValue"] = val
        }
        
        // Always save follow up date if selected?
        // Logic: The image shows a date picker directly. I'll assume if it's set, we save it.
        // Or I should add a toggle like before? The image only shows the date field with a bell.
        // I'll save it.
        data["followUpDate"] = Timestamp(date: followUpDate)
        
        if let existing = existingLead, let docId = existing.documentId {
            firebaseService.updateLead(documentId: docId, data: data) { error in
                isSubmitting = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
        } else {
            firebaseService.createLead(data: data) { error in
                isSubmitting = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
        }
    }
}

struct FormField<Content: View>: View {
    let label: String
    var required: Bool = false
    let content: Content
    
    init(label: String, required: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.required = required
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                if required {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            content
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground)) // Dynamic background for dark mode
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// Lead Card Row Component
struct LeadCardRow: View {
    let lead: Lead
    let index: Int
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    @State private var showActionMenu = false
    @State private var showDetailSheet = false
    @State private var showScheduleSheet = false
    
    var statusColor: Color {
        let colorName = LeadStatus.getColor(for: lead.status)
        switch colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "green": return .green
        case "red": return .red
        case "gray": return .gray
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with SR No, Name, Company and Menu
            HStack(alignment: .center, spacing: 10) {
                // SR Number Circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [statusColor.opacity(0.4), statusColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 35, height: 35)
                    .overlay(
                        Text("\(index)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                    )
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(lead.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if let company = lead.companyName, !company.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                            Text(company)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                
                // Action Menu
                Menu {
                    Button(action: {
                        showDetailSheet = true
                    }) {
                        Label("View", systemImage: "eye")
                    }
                    
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        showScheduleSheet = true
                    }) {
                        Label("Schedule", systemImage: "calendar")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.purple)
                        .frame(width: 32, height: 32)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
                .tint(.purple)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .sheet(isPresented: $showScheduleSheet) {
                 ScheduleFollowUpSheet(firebaseService: FirebaseService.shared, selectedLead: lead)
            }
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            // Compact Data Section - Single Row
            HStack(spacing: 12) {
                // Email
                if let email = lead.email, !email.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        Text(email)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Phone
                if let phone = lead.phone, !phone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(phone)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            // Dates and Status Row
            HStack(spacing: 12) {
                // Created Date
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Created")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Text(lead.createdAt.formatted(date: .numeric, time: .omitted))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Follow-up Date
                if let followUp = lead.followUpDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Follow-up")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                            Text(followUp.formatted(date: .numeric, time: .omitted))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Status
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                        .foregroundColor(statusColor)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Status")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Text(lead.status)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Priority
                if let priority = lead.priority {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Priority")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                            Text(priority)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: statusColor.opacity(0.15), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.8), lineWidth: 3)
        )
        .sheet(isPresented: $showDetailSheet) {
            LeadDetailSheet(lead: lead)
        }
    }
}

// Lead Detail Sheet
struct LeadDetailSheet: View {
    let lead: Lead
    @Environment(\.dismiss) var dismiss
    
    var statusColor: Color {
        let colorName = LeadStatus.getColor(for: lead.status)
        switch colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Card
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "eye.fill")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lead.name)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Lead Details")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        
                        // Contact Information Section
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Contact Information")
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                DetailInfoCard(
                                    label: "Date",
                                    value: lead.createdAt.formatted(date: .numeric, time: .omitted),
                                    icon: "calendar",
                                    iconColor: .green
                                )
                                DetailInfoCard(
                                    label: "Customer Name",
                                    value: lead.name,
                                    icon: "person.fill",
                                    iconColor: .blue
                                )
                                DetailInfoCard(
                                    label: "Contact Number",
                                    value: lead.phone ?? "-",
                                    icon: "phone.fill",
                                    iconColor: .green
                                )
                                DetailInfoCard(
                                    label: "Email",
                                    value: lead.email ?? "-",
                                    icon: "envelope.fill",
                                    iconColor: .purple
                                )
                            }
                        }
                        
                        // Company Information Section
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Company Information")
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                DetailInfoCard(
                                    label: "Company",
                                    value: lead.companyName ?? "-",
                                    icon: "building.2.fill",
                                    iconColor: .indigo
                                )
                                DetailInfoCard(
                                    label: "Address",
                                    value: lead.address ?? "-",
                                    icon: "location.fill",
                                    iconColor: .red
                                )
                            }
                        }
                        
                        // Product Information Section
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Product Information")
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                DetailInfoCard(
                                    label: "Product of Interest",
                                    value: lead.productOfInterest ?? "-",
                                    icon: "cube.fill",
                                    iconColor: .orange
                                )
                                DetailInfoCard(
                                    label: "Sector",
                                    value: lead.sector ?? "-",
                                    icon: "chart.bar.fill",
                                    iconColor: .teal
                                )
                                DetailInfoCard(
                                    label: "Source of Lead",
                                    value: lead.source ?? "-",
                                    icon: "point.3.connected.trianglepath.dotted",
                                    iconColor: .cyan
                                )
                                DetailInfoCard(
                                    label: "Product Category",
                                    value: lead.productCategory ?? "-",
                                    icon: "tag.fill",
                                    iconColor: .pink
                                )
                            }
                        }
                        
                        // Status & Priority Section
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Status & Priority")
                            
                            HStack(spacing: 12) {
                                // Status Card
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.caption)
                                            .foregroundColor(statusColor)
                                        Text("Status")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text(lead.status)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(statusColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(statusColor.opacity(0.15))
                                        .cornerRadius(8)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                
                                // Priority Card
                                if let priority = lead.priority {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "flag.fill")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            Text("Priority")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Text(priority)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.orange.opacity(0.15))
                                            .cornerRadius(8)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        // Notes Section
                        if let notes = lead.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Notes")
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(nil)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// Section Header Component
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
        }
    }
}

// Detail Info Card Component
struct DetailInfoCard: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = .blue
    var highlight: Color? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundColor(iconColor)
                }
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(highlight ?? .primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }
}
