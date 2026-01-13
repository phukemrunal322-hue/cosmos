import SwiftUI

struct ClientSideMenuView: View {
    @Binding var selectedTab: Int
    @Binding var showMenu: Bool
    var onLogout: (() -> Void)? = nil
    
    let menuItems = [
        ("1. Dashboard", "house.fill", 0),
        ("2. Projects", "folder.fill", 1),
        ("3. Task Monitoring", "checklist", 2),
        ("4. Meetings & Calendar", "calendar", 4), // Changed from "Feedback & Approval"
        ("6. Communication", "message.fill", 6), // Changed from "Calendar & Meetings"
        ("7. Profile & Settings", "person.fill", 3),
        ("8. Logout", "rectangle.portrait.and.arrow.right", 8)
    ]
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client Portal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("Sarah Wilson")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("client@trilogy.com")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.7))
                    }
                    Spacer()
                    
                    Image(systemName: "building.2.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .padding()
                .padding(.top, 50)
                
                // Menu Items
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(menuItems, id: \.0) { item in
                            if item.0 == "8. Logout" {
                                // Logout button with different styling
                                Button(action: {
                                    // Call logout handler
                                    onLogout?()
                                    showMenu = false
                                }) {
                                    HStack(spacing: 15) {
                                        Image(systemName: item.1)
                                            .font(.system(size: 20))
                                            .foregroundColor(.red)
                                            .frame(width: 24)
                                        
                                        Text(item.0)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.red)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.1))
                                }
                            } else {
                                ClientMenuRow(
                                    title: item.0,
                                    icon: item.1,
                                    isSelected: selectedTab == item.2
                                ) {
                                    selectedTab = item.2
                                    showMenu = false
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Footer
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text("Trilogy Solution Consultancy")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Client Portal v2.0")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding()
            }
        }
    }
}

struct ClientMenuRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .green : .gray)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .green : .primary)
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? Color.green.opacity(0.1) : Color.clear)
        }
    }
}
