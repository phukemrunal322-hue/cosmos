import SwiftUI

struct EmployeeSideMenuView: View {
    @Binding var selectedTab: Int
    @Binding var showMenu: Bool
    var onLogout: (() -> Void)? = nil
    
    let menuItems = [
        ("1. Dashboard", "house.fill", 0),
        ("2. Projects", "folder.fill", 1),
        ("3. Tasks", "checklist", 2),
        ("4. Meetings & Calendar", "calendar", 4), // Changed from "AI Reports"
        ("5. Communication", "message.fill", 5),
        ("6. Performance", "chart.line.uptrend.xyaxis", 6), // Changed from "Meetings"
        ("7. Notifications", "bell.fill", 7), // Changed from "Performance"
        ("8. Profile & Attendance", "person.fill", 3),
        ("9. Logout", "rectangle.portrait.and.arrow.right", 9)
    ]
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Employee Portal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("John Doe")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("employee@trilogy.com")
                            .font(.caption)
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    Spacer()
                    
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding()
                .padding(.top, 50)
                
                // Menu Items
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(menuItems, id: \.0) { item in
                            if item.0 == "10. Logout" {
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
                                MenuRow(
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
                    Text("Employee Portal v2.0")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding()
            }
        }
    }
}

struct MenuRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
    }
}
