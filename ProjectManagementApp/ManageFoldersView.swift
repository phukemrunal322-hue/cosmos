import SwiftUI
import FirebaseFirestore

// MARK: - Folder Model
struct ProjectFolder: Identifiable, Codable, Hashable {
    var id: String? = UUID().uuidString
    let name: String
    let colorHex: String
    let createdAt: Date? // Optional to handle old data
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex = "color" // Map 'color' from DB to 'colorHex'
        case createdAt
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}

// MARK: - Manage Folders View
struct ManageFoldersView: View {
    let projectId: String
    @Binding var isPresented: Bool
    @State private var newFolderName = ""
    @State private var selectedColor: Color = .blue
    @State private var folders: [ProjectFolder] = []
    @State private var isLoading = false
    
    private let availableColors: [Color] = [
        .blue, .purple, .green, .orange, .pink, .red, .yellow, .gray, .mint, .indigo
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Input Section
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // Color Picker Menu
                        Menu {
                            ForEach(availableColors, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    HStack {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                        }
                                        Circle().fill(color).frame(width: 20, height: 20)
                                    }
                                }
                            }
                        } label: {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Text Field
                        TextField("Enter folder name...", text: $newFolderName)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        // Add Button
                        Button(action: addFolder) {
                            Text("Add")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(newFolderName.isEmpty ? Color.gray : Color.blue)
                                .cornerRadius(8)
                        }
                        .disabled(newFolderName.isEmpty || isLoading)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                
                // Existing Folders List
                VStack(alignment: .leading, spacing: 0) {
                    Text("Existing Folders")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 8)
                    
                    if isLoading && folders.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if folders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No custom folders yet")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                            Text("Add your first folder using the form above")
                                .foregroundColor(.gray.opacity(0.7))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        List {
                            ForEach(folders, id: \.name) { folder in
                                HStack {
                                    Circle()
                                        .fill(folder.color)
                                        .frame(width: 12, height: 12)
                                    
                                    Text(folder.name)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        deleteFolder(folder)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Manage Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                    }
                }
            }
            .onAppear {
                fetchFolders()
            }
            .background(Color(UIColor.systemBackground))
        }
    }
    
    // MARK: - Firebase Actions
    
    private func fetchFolders() {
        isLoading = true
        let db = Firestore.firestore()
        
        // Listen ONLY to Global Folders (documents/folders)
        db.collection("documents").document("folders")
            .addSnapshotListener { snapshot, error in
                self.isLoading = false
                if let error = error {
                    print("Error fetching folders: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let foldersArray = data["folders"] as? [[String: Any]] else {
                    self.folders = []
                    return
                }
                
                self.folders = foldersArray.compactMap { dict -> ProjectFolder? in
                    let name = dict["name"] as? String ?? ""
                    let color = dict["color"] as? String ?? "#000000"
                    // Handle timestamp if string or Timestamp
                    return ProjectFolder(id: name, name: name, colorHex: color, createdAt: nil)
                }.sorted { $0.name < $1.name }
            }
    }
    
    private func addFolder() {
        guard !newFolderName.isEmpty else { return }
        isLoading = true
        
        // Prepare dictionary for array
        let folderData: [String: Any] = [
            "name": newFolderName,
            "color": selectedColor.toHex() ?? "#0000FF",
            "updatedAt": Timestamp(date: Date())
        ]
        
        let db = Firestore.firestore()
        // Add to Global Documents/Folders
        db.collection("documents").document("folders").updateData([
            "folders": FieldValue.arrayUnion([folderData])
        ]) { error in
            isLoading = false
            if let error = error {
                print("Error adding folder: \(error.localizedDescription)")
            } else {
                newFolderName = ""
            }
        }
    }
    
    private func deleteFolder(_ folder: ProjectFolder) {
        let db = Firestore.firestore()
        
        // Remove from Global Documents/Folders
        db.collection("documents").document("folders").getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  var foldersArray = data["folders"] as? [[String: Any]] else { return }
            
            // Remove by name
            foldersArray.removeAll { ($0["name"] as? String) == folder.name }
            
            db.collection("documents").document("folders").updateData([
                "folders": foldersArray
            ])
        }
    }
}
