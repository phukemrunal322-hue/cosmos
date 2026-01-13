import SwiftUI

struct ManagerTeamExpensesView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var firebaseService = FirebaseService.shared
    
    @State private var searchText = ""
    @State private var selectedStatus = "All Statuses"
    @State private var selectedCategory = "All Categories"
    @State private var rowsPerPage = 10
    
    private var filteredExpenses: [Expense] {
        var expenses = firebaseService.expenses
        
        // 1. Filter by Search Text
        if !searchText.isEmpty {
            expenses = expenses.filter { expense in
                let titleMatch = expense.title.localizedCaseInsensitiveContains(searchText)
                return titleMatch
            }
        }
        
        // 2. Filter by Status
        if selectedStatus != "All Statuses" {
            let mappedStatus: String
            switch selectedStatus {
            case "Pending": mappedStatus = "pending"
            case "Approved": mappedStatus = "approved"
            case "Rejected": mappedStatus = "rejected"
            default: mappedStatus = selectedStatus.lowercased()
            }
            expenses = expenses.filter { $0.status.rawValue == mappedStatus || $0.status.rawValue == selectedStatus.lowercased() }
        }
        
        // 3. Filter by Category
        if selectedCategory != "All Categories" {
            expenses = expenses.filter { $0.category == selectedCategory }
        }
        
        return expenses
    }
    
    private var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private var pendingCount: Int {
        filteredExpenses.filter { $0.status.rawValue == "pending" }.count
    }
    
    private var approvedCount: Int {
        filteredExpenses.filter { $0.status.rawValue == "approved" || $0.status.rawValue == "paid" }.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with Close Button
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Team Expenses")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Review and approve expense claims from your team members")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Close Button
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Stats Cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            TeamExpenseStatCard(title: "Total Team Expenses", value: "$\(String(format: "%.0f", totalAmount))", color: .blue, icon: "creditcard.fill")
                            TeamExpenseStatCard(title: "Pending Approval", value: "\(pendingCount)", color: .orange, icon: "exclamationmark.triangle.fill")
                            TeamExpenseStatCard(title: "Approved", value: "\(approvedCount)", color: .green, icon: "checkmark.circle.fill")
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Filters
                    VStack(spacing: 16) {
                        // Search Bar (Full Width)
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search by title...", text: $searchText)
                                .foregroundColor(.primary)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        // Status and Category Pickers (Side by Side)
                        HStack(spacing: 12) {
                            // Status Picker
                            Menu {
                                Button("All Statuses") { selectedStatus = "All Statuses" }
                                Button("Pending") { selectedStatus = "Pending" }
                                Button("Approved") { selectedStatus = "Approved" }
                                Button("Rejected") { selectedStatus = "Rejected" }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(selectedStatus)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            // Category Picker
                            Menu {
                                Button("All Categories") { selectedCategory = "All Categories" }
                                Button("Travel") { selectedCategory = "Travel" }
                                Button("Food") { selectedCategory = "Food" }
                                Button("Stay") { selectedCategory = "Stay" }
                                Button("Office") { selectedCategory = "Office" }
                                Button("Other") { selectedCategory = "Other" }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(selectedCategory)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    
                    // Expense List Title
                    Text("Expense List")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Pagination Controls (Below Title)
                    HStack(spacing: 8) {
                        Text("Page 1 of 1")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Rows per page")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        // Rows per page dropdown
                        Menu {
                            Button(action: { rowsPerPage = 10 }) {
                                HStack {
                                    Text("10")
                                    if rowsPerPage == 10 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button(action: { rowsPerPage = 25 }) {
                                HStack {
                                    Text("25")
                                    if rowsPerPage == 25 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button(action: { rowsPerPage = 50 }) {
                                HStack {
                                    Text("50")
                                    if rowsPerPage == 50 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(rowsPerPage)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        }
                        
                        // Previous Button
                        Button(action: {
                            // Previous page action
                        }) {
                            Text("Previous")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.4, green: 0.3, blue: 0.9))
                                .cornerRadius(6)
                        }
                        .disabled(true)
                        .opacity(0.5)
                        
                        // Next Button
                        Button(action: {
                            // Next page action
                        }) {
                            Text("Next")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.4, green: 0.3, blue: 0.9))
                                .cornerRadius(6)
                        }
                        .disabled(true)
                        .opacity(0.5)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    // List
                    if filteredExpenses.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No team expenses found")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("No expenses match your current filters.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredExpenses.enumerated()), id: \.element.id) { index, expense in
                                TeamExpenseCard(expense: expense, index: index + 1)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                firebaseService.fetchExpenses()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func deleteExpense(_ expense: Expense) {
        guard let expenseId = expense.id else { return }
        firebaseService.deleteExpense(expenseId: expenseId) { error in
            if error == nil {
                // Refresh the list after deletion
                firebaseService.fetchExpenses()
            }
        }
    }
}

struct TeamExpenseStatCard: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var gradientColors: [Color] {
        switch color {
        case .blue:
            return [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.5, blue: 0.9)]
        case .orange:
            return [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.9, green: 0.5, blue: 0.1)]
        case .green:
            return [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.7, blue: 0.3)]
        default:
            return [color, color.opacity(0.8)]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Icon with gradient background
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Spacer()
            }
            
            // Value
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Title
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(minWidth: 170, maxWidth: 210, minHeight: 100)
        .background(
            ZStack {
                // Base background with gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(colorScheme == .dark ? 0.08 : 0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.4) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .overlay(alignment: .leading) {
            // Accent bar on the left
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
                .padding(.vertical, 12)
        }
        .shadow(color: color.opacity(colorScheme == .dark ? 0.2 : 0.15), radius: 12, x: 0, y: 6)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 4, x: 0, y: 2)
    }
}

struct TeamExpenseCard: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var firebaseService = FirebaseService.shared
    let expense: Expense
    let index: Int
    @State private var isHovered = false
    
    var statusColor: Color {
        switch expense.status.rawValue {
        case "approved", "paid": return .green
        case "pending": return .orange
        case "rejected": return .red
        default: return .gray
        }
    }
    
    var statusGradient: LinearGradient {
        switch expense.status.rawValue {
        case "approved", "paid": 
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.7, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "pending": 
            return LinearGradient(
                colors: [Color(red: 0.4, green: 0.5, blue: 1.0), Color(red: 0.3, green: 0.4, blue: 0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "rejected": 
            return LinearGradient(
                colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default: 
            return LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var categoryIcon: String {
        switch expense.category.lowercased() {
        case "travel": return "airplane.circle.fill"
        case "food": return "fork.knife.circle.fill"
        case "stay": return "bed.double.circle.fill"
        case "office": return "building.2.circle.fill"
        default: return "tag.circle.fill"
        }
    }
    
    var categoryColor: Color {
        switch expense.category.lowercased() {
        case "travel": return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "food": return Color(red: 1.0, green: 0.6, blue: 0.2)
        case "stay": return Color(red: 0.6, green: 0.4, blue: 1.0)
        case "office": return Color(red: 0.3, green: 0.8, blue: 0.5)
        default: return Color.gray
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Index Badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.5, green: 0.4, blue: 1.0).opacity(0.2),
                                        Color(red: 0.4, green: 0.3, blue: 0.9).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Text("\(index)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.5, green: 0.4, blue: 1.0))
                    }
                    
                    // Employee Info with Enhanced Avatar
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple.opacity(0.3),
                                            Color.purple.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .shadow(color: Color.purple.opacity(0.3), radius: 3, x: 0, y: 1)
                            
                            Text(expense.employeeName.prefix(1).uppercased())
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(expense.employeeName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Employee")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 160, alignment: .leading)
                    
                    // Expense Details with Icon
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 1.0))
                            
                            Text(expense.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            
                            Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 180, alignment: .leading)
                    
                    // Category Badge with Gradient
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(categoryColor.opacity(0.15))
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: categoryIcon)
                                .font(.system(size: 12))
                                .foregroundColor(categoryColor)
                        }
                        
                        Text(expense.category)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(categoryColor.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(categoryColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .frame(width: 140, alignment: .center)
                    
                    // Amount with Currency Symbol
                    VStack(spacing: 2) {
                        Text("Amount")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 1) {
                            Text("₹")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
                            
                            Text(String(format: "%.2f", expense.amount))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(width: 120, alignment: .center)
                    
                    // Status Badge with Gradient
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        
                        Text((expense.status.rawValue == "pending" ? "Submitted" : expense.status.rawValue).capitalized)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(statusGradient)
                    .cornerRadius(20)
                    .shadow(color: statusColor.opacity(0.4), radius: 6, x: 0, y: 3)
                    .frame(width: 130, alignment: .center)
                    
                    // Action Buttons
                    HStack(spacing: 8) {
                        if expense.status != .approved && expense.status != .rejected {
                            // Approve Button
                            Button(action: {
                                approveExpense(expense)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text("Approve")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.2, green: 0.8, blue: 0.4),
                                            Color(red: 0.1, green: 0.7, blue: 0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: Color.green.opacity(0.4), radius: 4, x: 0, y: 2)
                            }
                            
                            // Reject Button
                            Button(action: {
                                rejectExpense(expense)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text("Reject")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color.red.opacity(0.9),
                                            Color.red.opacity(0.7)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
                            }
                        } else {
                            // Empty space for approved/rejected items
                            Text("")
                                .frame(width: 180)
                        }
                    }
                    .frame(width: 200, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .frame(minWidth: 1000) // Ensure content is wide enough to scroll
        }
        .background(
            ZStack {
                // Base background
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.5, green: 0.4, blue: 1.0).opacity(0.3),
                            Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, x: 0, y: 4)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
    
    private func approveExpense(_ expense: Expense) {
        guard let expenseId = expense.id else { return }
        firebaseService.updateExpenseStatus(expenseId: expenseId, status: .approved) { error in
            if let error = error {
                print("❌ Error approving expense: \(error.localizedDescription)")
            } else {
                print("✅ Expense approved successfully")
                // Refresh the list
                firebaseService.fetchExpenses()
            }
        }
    }
    
    private func rejectExpense(_ expense: Expense) {
        guard let expenseId = expense.id else { return }
        firebaseService.updateExpenseStatus(expenseId: expenseId, status: .rejected) { error in
            if let error = error {
                print("❌ Error rejecting expense: \(error.localizedDescription)")
            } else {
                print("✅ Expense rejected successfully")
                // Refresh the list
                firebaseService.fetchExpenses()
            }
        }
    }
}
