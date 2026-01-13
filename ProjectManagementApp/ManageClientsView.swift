import SwiftUI
import PhotosUI

struct ManageClientsView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @State private var searchText = ""
    @State private var showingAddClient = false
    @State private var selectedClient: Client?
    @State private var clientToEdit: Client?
    @State private var clientToDelete: Client?
    @State private var showingDeleteAlert = false
    
    var filteredClients: [Client] {
        if searchText.isEmpty {
            return firebaseService.clients
        } else {
            return firebaseService.clients.filter { client in
                client.name.lowercased().contains(searchText.lowercased()) ||
                (client.email?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 12) {
                HStack {
                    Text("Manage Clients")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAddClient = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Client")
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
                
                // Search Bar & Filters
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search by company, client name or email", text: $searchText)
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
                    
                    HStack {
                        Text("Showing \(filteredClients.count) records")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: .gray.opacity(0.1), radius: 2, y: 2)
            
            // Client List
            if firebaseService.clients.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Clients Found")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Add your first client to get started")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredClients.isEmpty {
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
                        ForEach(Array(filteredClients.enumerated()), id: \.element.documentId) { index, client in
                            ClientListRow(
                                index: index + 1,
                                client: client,
                                onEdit: {
                                    clientToEdit = client
                                },
                                onDelete: {
                                    clientToDelete = client
                                    showingDeleteAlert = true
                                },
                                action: {
                                    selectedClient = client
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
            if firebaseService.clients.isEmpty {
                firebaseService.fetchClients()
            }
        }
        .sheet(isPresented: $showingAddClient) {
            AddClientView()
        }
        .sheet(item: $clientToEdit) { client in
            AddClientView(existingClient: client)
        }
        .sheet(item: $selectedClient) { client in
            ClientDetailView(client: client)
        }
        .alert("Confirm Delete", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let client = clientToDelete, let docId = client.documentId {
                    firebaseService.deleteClient(documentId: docId) { error in
                        if let error = error {
                            print("Error deleting client: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \(clientToDelete?.companyName ?? clientToDelete?.name ?? "this client")? This action cannot be undone.")
        }
    }
}

struct ClientListRow: View {
    let index: Int
    let client: Client
    var onEdit: () -> Void
    var onDelete: () -> Void
    let action: () -> Void
    
    // Random colors for avatars to match the colorful list
    let colors: [Color] = [.purple, .blue, .orange, .pink, .green]
    var avatarColor: Color {
        colors[index % colors.count]
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // SR. NO.
                Text("\(index)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 20, alignment: .center)
                
                // Avatar / Logo
                ZStack {
                    if let logoURL = client.logoURL, let url = URL(string: logoURL) {
                        CachedAsyncImage(url: url) {
                            Circle().fill(avatarColor.opacity(0.1))
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(avatarColor.opacity(0.8))
                            .frame(width: 44, height: 44)
                        
                        Text(client.name.prefix(1).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Company Name
                        Text(client.companyName ?? client.name)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Action Icons
                        HStack(spacing: 12) {
                            Button(action: onEdit) {
                                Image(systemName: "square.and.pencil")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Client name
                    Text(client.name)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Email & Phone
                    HStack(spacing: 12) {
                        if let email = client.email {
                            Label(email, systemImage: "envelope")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        if let phone = client.phone {
                            Label(phone, systemImage: "phone")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Tags row
                    HStack(spacing: 8) {
                        if let type = client.businessType {
                            Text(type)
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        if let count = client.employeeCount {
                            Text("\(count) Employees")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddClientView: View {
    let existingClient: Client?
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    init(existingClient: Client? = nil) {
        self.existingClient = existingClient
    }
    
    // Basic Information
    @State private var companyName = ""
    @State private var clientName = ""
    @State private var email = ""
    @State private var contactNumber = ""
    
    // Business Details
    @State private var businessType = ""
    @State private var employeeCount = ""
    @State private var address = ""
    
    // Media & Security
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var password = ""
    
    // UI State
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.badge.plus.fill")
                                .foregroundColor(.orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(existingClient == nil ? "Add New Client" : "Edit Client")
                                .font(.headline)
                            Text(existingClient == nil ? "Enter client details to create a new account" : "Update client details and save changes")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Mobile-friendly adaptive grid
                    let columns = [
                        GridItem(.adaptive(minimum: 340), spacing: 20)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        // BASIC INFORMATION
                        clientFormSection(title: "BASIC INFORMATION", icon: "building.2.fill") {
                            CustomAddResourceField(icon: "", label: "Company Name", placeholder: "e.g. Acme Corp", text: $companyName, isRequired: true)
                            CustomAddResourceField(icon: "", label: "Client Name", placeholder: "e.g. John Doe", text: $clientName, isRequired: true)
                            CustomAddResourceField(icon: "envelope.fill", label: "Email Address", placeholder: "john@example.com", text: $email, isRequired: true, keyboardType: .emailAddress)
                            CustomAddResourceField(icon: "phone.fill", label: "Contact Number", placeholder: "Enter 10 digit Mobile No", text: $contactNumber, isRequired: true, keyboardType: .phonePad)
                        }
                        
                        // BUSINESS DETAILS
                        clientFormSection(title: "BUSINESS DETAILS", icon: "briefcase.fill") {
                            CustomAddResourceField(icon: "", label: "Type of Business", placeholder: "e.g. Software Development", text: $businessType, isRequired: true)
                            CustomAddResourceField(icon: "person.2.fill", label: "No. of Employees", placeholder: "e.g. 50", text: $employeeCount)
                            CustomAddResourceField(icon: "mappin.and.ellipse", label: "Address", placeholder: "Enter full business address...", text: $address, isRequired: true)
                        }
                        
                        // MEDIA & SECURITY
                        clientFormSection(title: "MEDIA & SECURITY", icon: "lock.shield.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Company Logo")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
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
                                            } else {
                                                Circle()
                                                    .fill(Color.orange.opacity(0.1))
                                                    .frame(width: 100, height: 100)
                                                    .overlay(
                                                        Image(systemName: "camera.fill")
                                                            .font(.system(size: 30))
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
                            }
                            
                            CustomAddResourceField(icon: "lock.fill", label: "Password", placeholder: "********", text: $password, isRequired: true, isSecure: true)
                            
                            Text("Min: 8 chars, 1 Upper, 1 Lower, 1 Num, 1 Special (!@#$%^&*_-)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6).opacity(0.4))
            
            Divider()
            
            // Footer
            HStack(spacing: 20) {
                Spacer()
                
                Button("Cancel") { dismiss() }
                    .foregroundColor(.gray)
                    .fontWeight(.medium)
                
                Button(action: saveClient) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(existingClient == nil ? "Create Account" : "Update Client")
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(isFormValid ? Color.orange : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!isFormValid || isSubmitting)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .alert("Status", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .onAppear {
            if let client = existingClient {
                companyName = client.companyName ?? ""
                clientName = client.name
                email = client.email ?? ""
                contactNumber = client.phone ?? ""
                businessType = client.businessType ?? ""
                employeeCount = client.employeeCount ?? ""
                address = client.address ?? ""
                password = client.password ?? "********" // Placeholder if not available
            }
        }
        .onChange(of: contactNumber) { newValue in
            let filtered = newValue.filter { $0.isNumber }
            if newValue != filtered {
                contactNumber = filtered
            }
            if contactNumber.count > 10 {
                contactNumber = String(contactNumber.prefix(10))
            }
        }
    }
    
    private func clientFormSection<Content: View>(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .font(.caption)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Divider()
            
            VStack(spacing: 16) {
                content()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
    
    private var isFormValid: Bool {
        !companyName.isEmpty && !clientName.isEmpty && !email.isEmpty && validateMobile(contactNumber) && !password.isEmpty && validatePassword(password) && !address.isEmpty && !businessType.isEmpty
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
    
    private func saveClient() {
        isSubmitting = true
        
        var clientData: [String: Any] = [
            "companyName": companyName,
            "clientName": clientName,
            "email": email,
            "phone": contactNumber,
            "businessType": businessType,
            "employeeCount": employeeCount,
            "address": address,
            "password": password
        ]
        
        if let image = selectedImage {
            let path = "profiles/client/\(UUID().uuidString).jpg"
            firebaseService.uploadImage(image: image, path: path) { result in
                switch result {
                case .success(let url):
                    clientData["imageUrl"] = url
                    clientData["imageStoragePath"] = path
                    submitToFirebase(clientData)
                case .failure(let error):
                    isSubmitting = false
                    errorMessage = "Logo upload failed: \(error.localizedDescription)"
                }
            }
        } else {
            // Preserve existing URLs if editing and no new image selected
            if let existing = existingClient {
               if let logo = existing.logoURL {
                   clientData["imageUrl"] = logo // Ensure legacy fields are synced
               }
               // We would ideally preserve imageStoragePath too if we had it in the model
            }
            submitToFirebase(clientData)
        }
    }
    
    private func submitToFirebase(_ data: [String: Any]) {
        if let existing = existingClient, let docId = existing.documentId {
            firebaseService.updateClient(documentId: docId, data: data) { error in
                isSubmitting = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
        } else {
            firebaseService.createClient(data: data) { error in
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

struct ClientDetailView: View {
    let client: Client
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Client Details")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        if let logoURL = client.logoURL, let url = URL(string: logoURL) {
                            CachedAsyncImage(url: url) {
                                Circle().fill(Color.orange.opacity(0.1))
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                        } else {
                            Circle()
                                .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(client.name.prefix(1).uppercased())
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .shadow(radius: 5)
                        }
                        
                        VStack(spacing: 4) {
                            Text(client.companyName ?? "No Company Name")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(client.name)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top)
                    
                    // Info Sections
                    VStack(alignment: .leading, spacing: 20) {
                        detailSection(title: "CONTACT INFO", icon: "person.circle.fill") {
                            ResourceDetailRow(icon: "envelope.fill", title: "Email Address", value: client.email ?? "Not provided")
                            ResourceDetailRow(icon: "phone.fill", title: "Contact Number", value: client.phone ?? "Not provided")
                        }
                        
                        detailSection(title: "BUSINESS INFO", icon: "building.2.fill") {
                            ResourceDetailRow(icon: "tag.fill", title: "Business Type", value: client.businessType ?? "Not set")
                            ResourceDetailRow(icon: "person.2.fill", title: "Employees", value: client.employeeCount ?? "Not set")
                            ResourceDetailRow(icon: "mappin.and.ellipse", title: "Address", value: client.address ?? "Not set")
                        }
                        
                        detailSection(title: "ACCOUNT SECURITY", icon: "lock.shield.fill") {
                            ResourceDetailRow(icon: "key.fill", title: "Current Password", value: "********")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGray6).opacity(0.4))
        }
    }
    
    private func detailSection<Content: View>(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.orange)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                content()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}
