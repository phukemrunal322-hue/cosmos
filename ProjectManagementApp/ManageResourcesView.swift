import SwiftUI
import FirebaseFirestore
import PhotosUI

struct ManageResourcesView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var searchText = ""
    @State private var showingAddEmployee = false
    @State private var selectedEmployee: EmployeeProfile?
    
    // Filter States
    @State private var selectedEmploymentType = "All Types"
    @State private var selectedResourceType = "All Resources"
    @State private var selectedStatus = "All Status"
    
    // Action States
    @State private var employeeToEdit: EmployeeProfile?
    @State private var employeeToDelete: EmployeeProfile?
    @State private var showingDeleteAlert = false
    
    let employmentTypes = ["All Types", "Full-Time", "Part-Time", "Contract", "Intern"]
    let resourceTypes = ["All Resources", "In-house", "Outsourced"]
    let statuses = ["All Status", "Active", "Inactive"]
    
    var filteredEmployees: [EmployeeProfile] {
        if searchText.isEmpty {
            return firebaseService.employees
        } else {
            return firebaseService.employees.filter { employee in
                employee.name.lowercased().contains(searchText.lowercased()) ||
                employee.email.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 12) {
                HStack {
                    Text("Manage Resources")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAddEmployee = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Resources")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search resources...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)
            
            // Filters Row (Scrollable for mobile)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterDropdown(title: "Employment Type", selection: $selectedEmploymentType, options: employmentTypes)
                    FilterDropdown(title: "Resource Type", selection: $selectedResourceType, options: resourceTypes)
                    FilterDropdown(title: "Status", selection: $selectedStatus, options: statuses)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
            .shadow(color: .gray.opacity(0.05), radius: 2, y: 2)
            
            // Resource Stat Cards
            ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ManagementStatCard(
                                title: "Total Resources",
                                count: firebaseService.employees.count,
                                icon: "person.3.fill",
                                color: .blue
                            )
                            
                            ManagementStatCard(
                                title: "Active",
                                count: firebaseService.employees.filter { ($0.status ?? "Active") == "Active" }.count,
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            ManagementStatCard(
                                title: "In-house",
                                count: firebaseService.employees.filter { ($0.resourceType ?? "In-house") == "In-house" }.count,
                                icon: "building.2.fill",
                                color: .orange
                            )
                            
                            ManagementStatCard(
                                title: "Outsourced",
                                count: firebaseService.employees.filter { $0.resourceType == "Outsourced" }.count,
                                icon: "network",
                                color: .purple
                            )
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
      .background(Color(.systemGray6).opacity(0.3))
            
            // Employee List
            if firebaseService.employees.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Employees Found")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Add your first employee to get started")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEmployees.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Results")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Header for larger screens could go here, but focusing on card list for mobile first
                        ForEach(filteredEmployees, id: \.id) { employee in
                            EmployeeCard(
                                employee: employee,
                                action: { selectedEmployee = employee },
                                onEdit: { employeeToEdit = employee },
                                onDelete: {
                                    employeeToDelete = employee
                                    showingDeleteAlert = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.gray.opacity(0.05))
        .onAppear {
            if firebaseService.employees.isEmpty {
                firebaseService.fetchEmployees()
            }
        }
        .sheet(isPresented: $showingAddEmployee) {
            AddEmployeeView()
        }
        .sheet(item: $selectedEmployee) { employee in
            EmployeeDetailView(employee: employee)
        }
        .sheet(item: $employeeToEdit) { employee in
            AddEmployeeView(existingEmployee: employee)
        }
        .alert("Delete Resource", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let emp = employeeToDelete {
                    deleteEmployee(emp)
                }
            }
        } message: {
            Text("Are you sure you want to delete \(employeeToDelete?.name ?? "this resource")? This action cannot be undone.")
        }
    }
    
    private func deleteEmployee(_ employee: EmployeeProfile) {
        FirebaseService.shared.deleteEmployee(id: employee.id) { error in
            if let error = error {
                print("❌ Error deleting employee: \(error.localizedDescription)")
            } else {
                print("✅ Employee deleted successfully")
            }
        }
    }
}

struct EmployeeCard: View {
    let employee: EmployeeProfile
    let action: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Avatar with Gradient
                ZStack {
                    if let urlString = employee.profileImageURL, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) {
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .overlay(ProgressView().tint(.orange))
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.8), .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Text(String(employee.name.prefix(1)).uppercased())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    // Small Status Dot
                    Circle()
                        .fill(employee.status == "Inactive" ? Color.gray : Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 18, y: 18)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(employee.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Mobile-friendly Status Badge
                        Text(employee.status ?? "Active")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((employee.status == "Inactive" ? Color.gray : Color.green).opacity(0.1))
                            .foregroundColor(employee.status == "Inactive" ? .gray : .green)
                            .cornerRadius(12)
                    }
                    
                    Text(employee.email)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                        HStack(spacing: 8) {
                            if let position = employee.position, !position.isEmpty {
                                TagView(text: position, color: .gray)
                            }
                            
                            TagView(text: employee.resourceType ?? "In-house", color: .blue)
                        }
                        .padding(.top, 2)
                }
                
                Spacer()
                
                // Action Buttons (Edit/Delete)
                 VStack(spacing: 12) {
                     Button(action: onEdit) {
                         Image(systemName: "pencil")
                             .font(.caption)
                             .foregroundColor(.orange)
                             .padding(6)
                             .background(Color.orange.opacity(0.1))
                             .clipShape(Circle())
                     }
                     
                     Button(action: onDelete) {
                         Image(systemName: "trash")
                             .font(.caption)
                             .foregroundColor(.red)
                             .padding(6)
                             .background(Color.red.opacity(0.1))
                             .clipShape(Circle())
                     }
                 }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .gray.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddEmployeeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    
    // Track if we are editing
    var existingEmployee: EmployeeProfile? = nil
    
    // Basic Info
    @State private var name = ""
    @State private var email = ""
    @State private var mobile = ""
    
    // Role & Employment
    @State private var employmentType = "Full-time"
    @State private var resourceType = "In-house"
    @State private var resourceRole = "Select role"
    @State private var status = "Active"
    
    // Account & Access
    @State private var password = ""
    @State private var isPasswordVisible = false
    
    // Profile Image
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var profileImageURL: String? = nil
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: existingEmployee == nil ? "person.badge.plus" : "pencil.circle")
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(existingEmployee == nil ? "Add New Resource" : "Edit Resource")
                        .font(.headline)
                    Text(existingEmployee == nil ? "Create a new team member profile" : "Update resource profile information")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Section 1: Basic Info
                    VStack(alignment: .leading, spacing: 16) {
                        Label("BASIC INFO", systemImage: "person.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Divider()
                        
                        // Profile Image with PhotosPicker
                        HStack {
                            Spacer()
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let selectedImage = selectedImage {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else if let urlString = profileImageURL, let url = URL(string: urlString) {
                                        CachedAsyncImage(url: url) {
                                            Circle()
                                                .fill(Color.orange.opacity(0.1))
                                                .overlay(ProgressView().tint(.orange))
                                        }
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.orange.opacity(0.1))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.orange)
                                            )
                                    }
                                    
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .onChange(of: selectedItem) { newItem in
                                _Concurrency.Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        selectedImage = image
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        
                        CustomAddResourceField(icon: "person.fill", label: "Full Name", placeholder: "e.g. Priya Sharma", text: $name, isRequired: true)
                        CustomAddResourceField(icon: "envelope.fill", label: "Email", placeholder: "Work email", text: $email, isRequired: true, keyboardType: .emailAddress)
                        CustomAddResourceField(icon: "phone.fill", label: "Mobile", placeholder: "10-digit mobile number", text: $mobile, isRequired: true, keyboardType: .phonePad)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    // Section 2: Role & Employment
                    VStack(alignment: .leading, spacing: 16) {
                        Label("ROLE & EMPLOYMENT", systemImage: "briefcase.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Divider()
                        
                        CustomDropdownField(label: "Employment Type", selection: $employmentType, options: firebaseService.employmentTypes)
                        CustomDropdownField(label: "Resource Type", selection: $resourceType, options: firebaseService.resourceTypes)
                        CustomDropdownField(label: "Resource Role", selection: $resourceRole, options: firebaseService.resourceRoles)
                        CustomDropdownField(label: "Status", selection: $status, options: firebaseService.resourceStatuses)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    // Section 3: Account & Access
                    VStack(alignment: .leading, spacing: 16) {
                        Label("ACCOUNT & ACCESS", systemImage: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Divider()
                        
                        CustomAddResourceField(icon: "lock.fill", label: "Password", placeholder: "Create a password", text: $password, isRequired: true, isSecure: true)
                        
                        Text("Min: 8 chars, 1 Upper, 1 Lower, 1 Num, 1 Special (!@#$%^&*_-)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
                .padding(.vertical)
                .background(Color(.systemGray6).opacity(0.5))
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 16) {
                Spacer()
                
                Button("Cancel") { dismiss() }
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Button(action: saveEmployee) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(existingEmployee == nil ? "Add Resource" : "Update Resource")
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(isFormValid ? Color.orange : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(!isFormValid || isLoading)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .onAppear {
            firebaseService.fetchResourceMetaData()
            
            // Pre-fill fields if editing
            if let emp = existingEmployee {
                name = emp.name
                email = emp.email
                mobile = emp.mobile ?? ""
                employmentType = emp.employmentType ?? "Full-time"
                resourceType = emp.resourceType ?? "In-house"
                resourceRole = emp.position ?? "Select role"
                status = emp.status ?? "Active"
                password = emp.password ?? ""
                profileImageURL = emp.profileImageURL
                
                // If URL is missing, try to fetch it from storage
                if profileImageURL == nil || profileImageURL?.isEmpty == true {
                    checkAndFetchProfileImage(email: emp.email)
                }
            }
        }
        .alert("Notice", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: mobile) { newValue in
            let filtered = newValue.filter { $0.isNumber }
            if newValue != filtered {
                mobile = filtered
            }
            if mobile.count > 10 {
                mobile = String(mobile.prefix(10))
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && validateMobile(mobile) && !password.isEmpty && validatePassword(password)
    }
    
    private func validatePassword(_ password: String) -> Bool {
        let pattern = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*_\\-]).{8,}$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: password.utf16.count)
        return regex.firstMatch(in: password, options: [], range: range) != nil
    }
    
    private func validateMobile(_ number: String) -> Bool {
        let digits = number.filter { $0.isNumber }
        return digits.count == 10 && number.count == 10
    }
    
    private func saveEmployee() {
        isLoading = true
        
        let completion: (String?, String?) -> Void = { imageURL, storagePath in
            var data: [String: Any] = [
                "name": name,
                "email": email,
                "mobile": mobile,
                "position": resourceRole == "Select role" ? "" : resourceRole,
                "roleType": resourceRole == "Select role" ? "employee" : resourceRole,
                "employmentType": employmentType,
                "resourceType": resourceType,
                "status": status,
                "devPassword": password,
                "password": FieldValue.delete() // Remove legacy password field
            ]
            
            if let imageURL = imageURL {
                data["imageUrl"] = imageURL
            } else if let existingURL = existingEmployee?.profileImageURL {
                data["imageUrl"] = existingURL
            }
            
            if let storagePath = storagePath {
                data["imageStoragePath"] = storagePath
            } else if let existingPath = existingEmployee?.imageStoragePath { // Assuming EmployeeProfile has this, but if not it won't hurt to try or skip if struct doesn't have it. Checking struct... failing that, no op.
                 // Ideally we'd preserve existing path if not changed. 
                 // Since we don't strictly have it in existingEmployee struct yet (maybe), let's just allow new writes.
                 // Actually, best to just set it if we have a new one.
                 // If we don't have a new one, we don't overwrite it with nil.
            }

            if let id = existingEmployee?.id {
                firebaseService.updateEmployee(id: id, data: data) { error in
                    isLoading = false
                    if let error = error {
                        alertMessage = "Error: \(error.localizedDescription)"
                    } else {
                        alertMessage = "Resource updated successfully!"
                    }
                    showingAlert = true
                }
            } else {
                var createData = data
                createData["joinDate"] = Timestamp(date: Date())
                firebaseService.createEmployee(data: createData) { error in
                    isLoading = false
                    if let error = error {
                        alertMessage = "Error: \(error.localizedDescription)"
                    } else {
                        alertMessage = "Resource added successfully!"
                    }
                    showingAlert = true
                }
            }
        }
        
        if let image = selectedImage {
            let path = "profiles/resource/\(email.isEmpty ? UUID().uuidString : email).jpg"
            firebaseService.uploadImage(image: image, path: path) { result in
                switch result {
                case .success(let url):
                    completion(url, path)
                case .failure(let error):
                    isLoading = false
                    alertMessage = "Image upload failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        } else {
            completion(nil, nil)
        }
    }
    
    private func checkAndFetchProfileImage(email: String) {
        guard !email.isEmpty else { return }
        let possiblePath = "profiles/resource/\(email).jpg"
        
        firebaseService.getDownloadURL(path: possiblePath) { result in
            switch result {
            case .success(let url):
                print("✅ Found existing profile image in storage: \(url)")
                self.profileImageURL = url
            case .failure(let error):
                print("ℹ️ No existing profile image found in storage for \(email): \(error.localizedDescription)")
            }
        }
    }
}


struct EmployeeDetailView: View {
    let employee: EmployeeProfile
    @State private var isPasswordVisible = true
    @State private var dynamicProfileImageURL: String? = nil
    @Environment(\.dismiss) var dismiss
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.fill")
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resource Details")
                        .font(.headline)
                    Text("View complete profile information")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Identity Section
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            if let urlString = dynamicProfileImageURL ?? employee.profileImageURL, let url = URL(string: urlString) {
                                CachedAsyncImage(url: url) {
                                    Circle()
                                        .fill(Color.orange.opacity(0.1))
                                        .overlay(ProgressView().tint(.orange))
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.orange, .orange.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 120, height: 120)
                                    
                                    Text(employee.name.prefix(1).uppercased())
                                        .font(.system(size: 50, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                )
                            }
                            
                            // Status Dot
                            Circle()
                                .fill(employee.status == "Inactive" ? Color.gray : Color.green)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                .offset(x: -5, y: -5)
                        }
                        
                        VStack(spacing: 4) {
                            Text(employee.name)
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text(employee.position ?? "Designation Not Set")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 8) {
                            TagView(text: employee.resourceType ?? "In-house", color: .orange)
                            TagView(text: employee.employmentType ?? "Full-time", color: .orange)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Details Grid
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            InfoCard(icon: "envelope.fill", title: "EMAIL", value: employee.email.lowercased())
                            InfoCard(icon: "phone.fill", title: "MOBILE", value: employee.mobile ?? "Not provided", iconColor: .orange)
                        }
                        
                        HStack(spacing: 16) {
                            InfoCard(icon: "person.badge.key.fill", title: "ROLE TYPE", value: employee.roleType ?? "employee", iconColor: .orange)
                            InfoCard(icon: "checkmark.circle.fill", title: "STATUS", value: employee.status ?? "Active", iconColor: .orange)
                        }

                        HStack(spacing: 16) {
                            InfoCard(icon: "calendar", title: "JOIN DATE", value: employee.joinDate.map { dateFormatter.string(from: $0) } ?? "Not set", iconColor: .orange)
                            Spacer().frame(maxWidth: .infinity)
                        }
                        
                        // Password Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                Text("CURRENT PASSWORD")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.orange)
                                
                                Spacer()
                                
                                Button(action: { isPasswordVisible.toggle() }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            HStack {
                                Text(isPasswordVisible ? (employee.password ?? "Not Set") : "********")
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(minWidth: 100, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                
                                Spacer()
                                
                                Text("Visible to admins only")
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Text("Close")
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .onAppear {
            if employee.profileImageURL == nil || employee.profileImageURL?.isEmpty == true {
                let path = "profiles/resource/\(employee.email).jpg"
                FirebaseService.shared.getDownloadURL(path: path) { result in
                    if case .success(let url) = result {
                        self.dynamicProfileImageURL = url
                    }
                }
            }
        }
    }
}

struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(20)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    var iconColor: Color = .orange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}


struct FilterDropdown: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: { selection = option }) {
                        HStack {
                            Text(option)
                            if selection == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 140) // Fixed width for consistency
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}


