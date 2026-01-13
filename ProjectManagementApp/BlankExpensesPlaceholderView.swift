import SwiftUI

struct BlankExpensesPlaceholderView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var searchText = ""
    @State private var selectedStatus = "All Statuses"
    @State private var selectedCategory = "All Categories"
    @State private var showExportSheet = false
    @State private var fromDate: Date? = nil
    @State private var toDate: Date? = nil
    
    // Table Selection & Pagination
    @State private var selectedExpenseIds: Set<String> = []
    @State private var currentPage = 1
    @State private var itemsPerPage = 10
    @State private var showFromDatePicker = false
    @State private var showToDatePicker = false
    @State private var selectedExpenseForDetail: Expense? = nil
    @State private var showComingSoonAlert = false
    @State private var showShareSheet = false
    @State private var exportFileURL: URL? = nil
    
    // Updated status options matching image 2
    let statuses = ["All Statuses", "Draft", "Submitted", "Approved", "Rejected", "Paid"]
    
    // Updated category options matching image 3
    let categories = ["All Categories", "Travel", "Food", "Stay", "Office", "Other"]
    
    // Computed properties for pagination
    var paginatedExpenses: [Expense] {
        let startIndex = (currentPage - 1) * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredExpenses.count)
        guard startIndex < filteredExpenses.count else { return [] }
        return Array(filteredExpenses[startIndex..<endIndex])
    }
    
    var totalPages: Int {
        max(1, Int(ceil(Double(filteredExpenses.count) / Double(itemsPerPage))))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                statsCardsView
                
                searchBarView
                
                // Filters Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("FILTERS:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // Status and Category Dropdowns - Equal Width
                    HStack(spacing: 12) {
                        // Status Dropdown
                        Menu {
                            ForEach(statuses, id: \.self) { status in
                                Button(action: {
                                    selectedStatus = status
                                }) {
                                    HStack {
                                        Text(status)
                                        if status == selectedStatus {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.caption)
                                Text(selectedStatus)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Category Dropdown
                        Menu {
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    HStack {
                                        Text(category)
                                        if category == selectedCategory {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.caption)
                                Text(selectedCategory)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    // Date Filters
                    HStack(spacing: 12) {
                        // From Date
                        VStack(alignment: .leading, spacing: 4) {
                            Text("From Date")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            DatePicker("", selection: Binding(
                                get: { fromDate ?? Date() },
                                set: { fromDate = $0 }
                            ), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // To Date
                        VStack(alignment: .leading, spacing: 4) {
                            Text("To Date")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            DatePicker("", selection: Binding(
                                get: { toDate ?? Date() },
                                set: { toDate = $0 }
                            ), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Clear Filters Button
                    if selectedStatus != "All Statuses" || selectedCategory != "All Categories" || fromDate != nil || toDate != nil {
                        Button(action: {
                            selectedStatus = "All Statuses"
                            selectedCategory = "All Categories"
                            fromDate = nil
                            toDate = nil
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear Filters")
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                }
                
                expenseTableView
                
                Spacer()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Fetch expenses when view appears
            firebaseService.fetchExpenses()
        }
        .onChange(of: searchText) { _ in currentPage = 1 }
        .onChange(of: selectedStatus) { _ in currentPage = 1 }
        .onChange(of: selectedCategory) { _ in currentPage = 1 }
        .onChange(of: fromDate) { _ in currentPage = 1 }
        .onChange(of: toDate) { _ in currentPage = 1 }
        .actionSheet(isPresented: $showExportSheet) {
            exportActionSheet
        }
        .sheet(item: $selectedExpenseForDetail) { expense in
            ExpenseDetailView(expense: expense)
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    // Computed property for filtered expenses
    var filteredExpenses: [Expense] {
        var expenses = firebaseService.expenses
        
        // Filter by search text
        if !searchText.isEmpty {
            expenses = expenses.filter { expense in
                expense.title.localizedCaseInsensitiveContains(searchText) ||
                expense.employeeName.localizedCaseInsensitiveContains(searchText) ||
                expense.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by status
        if selectedStatus != "All Statuses" {
            // Map UI status names to database status values
            let statusMapping: [String: String] = [
                "Draft": "Draft",
                "Submitted": "Submitted",
                "Approved": "Approved",
                "Rejected": "Rejected",
                "Paid": "Paid"
            ]
            
            if let dbStatus = statusMapping[selectedStatus] {
                expenses = expenses.filter { $0.status.rawValue == dbStatus }
            }
        }
        
        // Filter by category
        if selectedCategory != "All Categories" {
            // Map UI category names to database values
            let categoryMapping: [String: String] = [
                "Travel": "Travel",
                "Food": "Food",
                "Stay": "Stay",
                "Office": "Office",
                "Other": "Other"
            ]
            
            if let dbCategory = categoryMapping[selectedCategory] {
                expenses = expenses.filter { $0.category == dbCategory }
            }
        }
        
        // Filter by date range
        if let from = fromDate {
            let startOfDay = Calendar.current.startOfDay(for: from)
            expenses = expenses.filter { $0.date >= startOfDay }
        }
        
        if let to = toDate {
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: to)) ?? to
            expenses = expenses.filter { $0.date < endOfDay }
        }
        
        return expenses
    }
    
    
    private func exportToExcel() {
        let expenses = filteredExpenses
        
        guard !expenses.isEmpty else {
            print("No expenses to export")
            return
        }
        
        // Generate CSV on background thread to prevent UI freeze
        DispatchQueue.global(qos: .userInitiated).async {
            // Create CSV content
            var csvText = "Employee Name,Title,Description,Amount,Category,Status,Date,Project,Created At,Updated At\n"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            for expense in expenses {
                let employeeName = expense.employeeName.replacingOccurrences(of: ",", with: ";")
                let title = expense.title.replacingOccurrences(of: ",", with: ";")
                let description = expense.description.replacingOccurrences(of: ",", with: ";")
                let amount = String(format: "%.2f", expense.amount)
                let category = expense.category
                let status = expense.status.rawValue
                let date = dateFormatter.string(from: expense.date)
                let project = (expense.projectName ?? "No project").replacingOccurrences(of: ",", with: ";")
                let createdAt = dateFormatter.string(from: expense.createdAt)
                let updatedAt = dateFormatter.string(from: expense.updatedAt)
                
                let row = "\(employeeName),\(title),\(description),\(amount),\(category),\(status),\(date),\(project),\(createdAt),\(updatedAt)\n"
                csvText.append(row)
            }
            
            // Save to file
            let fileName = "Expenses_Export_\(Int(Date().timeIntervalSince1970)).csv"
            let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            
            do {
                try csvText.write(to: path, atomically: true, encoding: .utf8)
                print("✅ Excel file exported successfully to: \(path.path)")
                
                // Present share sheet on main thread
                DispatchQueue.main.async {
                    self.exportFileURL = path
                    self.showShareSheet = true
                }
            } catch {
                print("❌ Error exporting to Excel: \(error.localizedDescription)")
            }
        }
    }
    
    private func exportToPDF() {
        // TODO: Implement PDF export
        print("Exporting to PDF...")
    }
}

// MARK: - Expense Stat Card
struct ExpenseStatCard: View {
    let title: String
    let count: String
    let amount: String?
    let icon: String
    let iconColor: Color
    let borderColor: Color
    
    var body: some View {
        HStack(spacing: 0) {
            // Left colored bar
            Rectangle()
                .fill(borderColor)
                .frame(width: 5)
            
            // Main content
            HStack {
                // Left side - Title and Count
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(borderColor)
                    
                    Text(count)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let amount = amount {
                        Text(amount)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Right side - Icon in circle
                ZStack {
                    Circle()
                        .fill(borderColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(borderColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let icon: String
    let options: [String]
    let onSelect: (String) -> Void
    
    @State private var showOptions = false
    
    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    onSelect(option)
                }) {
                    HStack {
                        Text(option)
                        if option == title {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - View Components Breakdown
extension BlankExpensesPlaceholderView {
    
    var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expense Management")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Review and process employee reimbursement claims")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    exportToExcel()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.caption)
                        Text("Export Excel")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    var statsCardsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ExpenseStatCard(
                title: "Total",
                count: "\(firebaseService.totalExpenses)",
                amount: nil,
                icon: "doc.text.fill",
                iconColor: .blue,
                borderColor: .blue
            )
            
            ExpenseStatCard(
                title: "Approved",
                count: "\(firebaseService.approvedExpenses.count)",
                amount: "₹\(String(format: "%.2f", firebaseService.totalApprovedAmount))",
                icon: "checkmark.circle.fill",
                iconColor: .green,
                borderColor: .green
            )
            
            ExpenseStatCard(
                title: "Paid",
                count: "\(firebaseService.paidExpenses.count)",
                amount: "₹\(String(format: "%.2f", firebaseService.totalPaidAmount))",
                icon: "indianrupeesign.circle.fill",
                iconColor: .purple,
                borderColor: .purple
            )
            
            ExpenseStatCard(
                title: "Draft",
                count: "\(firebaseService.draftExpenses.count)",
                amount: nil,
                icon: "doc.text",
                iconColor: .orange,
                borderColor: .orange
            )
        }
        .padding(.horizontal)
    }
    
    var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search by title, employee, description...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    var filtersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FILTERS:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            // Status and Category Dropdowns
            HStack(spacing: 12) {
                // Status Dropdown
                Menu {
                    ForEach(statuses, id: \.self) { status in
                        Button(action: {
                            selectedStatus = status
                        }) {
                            HStack {
                                Text(status)
                                if status == selectedStatus {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                        Text(selectedStatus)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity)
                
                // Category Dropdown
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                        }) {
                            HStack {
                                Text(category)
                                if category == selectedCategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.caption)
                        Text(selectedCategory)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Date Filters
            HStack(spacing: 12) {
                // From Date
                VStack(alignment: .leading, spacing: 4) {
                    Text("From Date")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    DatePicker("", selection: Binding(
                        get: { fromDate ?? Date() },
                        set: { fromDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // To Date
                VStack(alignment: .leading, spacing: 4) {
                    Text("To Date")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    DatePicker("", selection: Binding(
                        get: { toDate ?? Date() },
                        set: { toDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
            
        
        // Bulk Actions Bar (When items are selected)
        if !selectedExpenseIds.isEmpty {
            HStack {
                Text("\(selectedExpenseIds.count) selected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Button(action: {
                    for id in selectedExpenseIds {
                        firebaseService.updateExpenseStatus(expenseId: id, status: .approved) { _ in }
                    }
                    selectedExpenseIds.removeAll()
                }) {
                    Text("Approve Selected")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                
                Button(action: {
                    for id in selectedExpenseIds {
                        firebaseService.updateExpenseStatus(expenseId: id, status: .paid) { _ in }
                    }
                    selectedExpenseIds.removeAll()
                }) {
                    Text("Mark Paid")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundColor(.primary)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            // Clear Filters Button (Only shown when no items selected)
            if selectedStatus != "All Statuses" || selectedCategory != "All Categories" || fromDate != nil || toDate != nil {
                Button(action: {
                    selectedStatus = "All Statuses"
                    selectedCategory = "All Categories"
                    fromDate = nil
                    toDate = nil
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Clear Filters")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
            }
        }
        }
    }
    
    var expenseTableView: some View {
        VStack(spacing: 0) {
            // Header with Title and Pagination Controls
            VStack(spacing: 12) {
                // Row 1: Title
                HStack {
                    Text("Expense List")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                // Row 2: Pagination Controls
                HStack(spacing: 12) {
                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Rows per page dropdown
                    Menu {
                        Button("10") { itemsPerPage = 10 }
                        Button("25") { itemsPerPage = 25 }
                        Button("50") { itemsPerPage = 50 }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Rows: \(itemsPerPage)")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                    
                    // Navigation Buttons
                    HStack(spacing: 8) {
                        Button(action: {
                            if currentPage > 1 { currentPage -= 1 }
                        }) {
                            Text("Previous")
                                .font(.caption)
                                .foregroundColor(currentPage <= 1 ? .gray : .blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                        .disabled(currentPage <= 1)
                        
                        Button(action: {
                            if currentPage < totalPages { currentPage += 1 }
                        }) {
                            Text("Next")
                                .font(.caption)
                                .foregroundColor(currentPage >= totalPages ? .gray : .blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                        .disabled(currentPage >= totalPages)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            // No corner radius here as it sits on top of the list
            
            // Table Content
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Table Header Row
                    HStack(spacing: 0) {
                        Group {

                            
                            Text("SR. NO.").frame(width: 60, alignment: .leading)
                            Text("EMPLOYEE").frame(width: 180, alignment: .leading)
                            Text("EXPENSE DETAILS").frame(width: 220, alignment: .leading)
                            Text("PROJECT").frame(width: 120, alignment: .leading)
                            Text("CATEGORY").frame(width: 120, alignment: .leading)
                            Text("AMOUNT").frame(width: 100, alignment: .leading)
                            Text("STATUS").frame(width: 100, alignment: .leading)
                            Text("APPROVAL").frame(width: 160, alignment: .leading)
                            Text("ACTIONS").frame(width: 100, alignment: .center)
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    
                    // Table Rows
                    if filteredExpenses.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No expenses found")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                    } else {
                        ForEach(Array(paginatedExpenses.enumerated()), id: \.element.id) { index, expense in
                            HStack(spacing: 0) {

                                
                                // SR NO
                                Text("\((currentPage - 1) * itemsPerPage + index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .frame(width: 60, alignment: .leading)
                                
                                // EMPLOYEE
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 30, height: 30)
                                        .overlay(Text(expense.employeeName.prefix(1)).font(.caption).fontWeight(.bold).foregroundColor(.blue))
                                    Text(expense.employeeName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(width: 180, alignment: .leading)
                                
                                // DETAILS
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.date.formatted(date: .numeric, time: .omitted))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text(expense.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    if let _ = expense.receiptURL {
                                        HStack(spacing: 2) {
                                            Image(systemName: "link")
                                                .font(.caption2)
                                            Text("Receipt")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                                .frame(width: 220, alignment: .leading)
                                
                                // PROJECT
                                Text(expense.projectName ?? "No project")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .italic()
                                    .frame(width: 120, alignment: .leading)
                                    
                                // CATEGORY
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text(expense.category)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .frame(width: 120, alignment: .leading)
                                
                                // AMOUNT
                                Text("₹\(String(format: "%.2f", expense.amount))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .frame(width: 100, alignment: .leading)
                                    
                                // STATUS
                                Text(expense.status.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        expense.status == .approved ? Color.green.opacity(0.15) :
                                        expense.status == .rejected ? Color.red.opacity(0.15) :
                                        expense.status == .paid ? Color.purple.opacity(0.15) :
                                        expense.status == .submitted ? Color.blue.opacity(0.15) :
                                        Color.orange.opacity(0.15)
                                    )
                                    .foregroundColor(
                                        expense.status == .approved ? .green :
                                        expense.status == .rejected ? .red :
                                        expense.status == .paid ? .purple :
                                        expense.status == .submitted ? .blue :
                                        .orange
                                    )
                                    .cornerRadius(4)
                                    .frame(width: 100, alignment: .leading)
                                    
                                // APPROVAL
                                HStack(spacing: 8) {
                                    if expense.status == .submitted || expense.status == .draft {
                                        Button("Approve") {
                                            if let id = expense.id {
                                                firebaseService.updateExpenseStatus(expenseId: id, status: .approved) { _ in }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .font(.caption2)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.indigo)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                        
                                        Button("Reject") {
                                            if let id = expense.id {
                                                firebaseService.updateExpenseStatus(expenseId: id, status: .rejected) { _ in }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .font(.caption2)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.red, lineWidth: 1)
                                        )
                                        .foregroundColor(.red)
                                    } else if expense.status == .approved {
                                        Button(action: {
                                            if let id = expense.id {
                                                firebaseService.updateExpenseStatus(expenseId: id, status: .paid) { _ in }
                                            }
                                        }) {
                                            Text("Mark Paid")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 6)
                                                .background(Color(red: 0.6, green: 0.0, blue: 1.0)) // Vivid purple
                                                .foregroundColor(.white)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(width: 160, alignment: .leading)
                                
                                // ACTIONS
                                HStack(spacing: 12) {
                                    // View/Details Button
                                    Button(action: {
                                        selectedExpenseForDetail = expense
                                    }) {
                                        Image(systemName: "eye")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    // Edit Button (Coming Soon)
                                    Button(action: {
                                        showComingSoonAlert = true
                                    }) {
                                        Image(systemName: "square.and.pencil")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    // Delete Button
                                    Button(action: {
                                        if let id = expense.id {
                                            firebaseService.deleteExpense(expenseId: id) { _ in }
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                .frame(width: 120, alignment: .center)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(.systemBackground))
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color.gray.opacity(0.1)),
                                alignment: .bottom
                            )
                        }
                    }
                }
                .frame(minWidth: 1200)
            }
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    var exportActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Export Expenses"),
            message: Text("Choose export format"),
            buttons: [
                .default(Text("Export as Excel")) {
                    exportToExcel()
                },
                .default(Text("Export as PDF")) {
                    exportToPDF()
                },
                .cancel()
            ]
        )
    }
}

// MARK: - Expense Detail View
struct ExpenseDetailView: View {
    let expense: Expense
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with icon and title
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "indianrupeesign.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("ID: \(expense.id?.prefix(8) ?? "N/A")...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Status Badge
                    HStack {
                        Text(expense.status.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(statusColor(for: expense.status).opacity(0.15))
                            .foregroundColor(statusColor(for: expense.status))
                            .cornerRadius(20)
                        
                        Spacer()
                        
                        let descriptionText = (expense.description as String?) ?? ""
                        if !descriptionText.isEmpty {
                            Text(descriptionText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Info Cards Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ExpenseInfoCard(
                            icon: "indianrupeesign.circle.fill",
                            iconColor: .green,
                            title: "AMOUNT",
                            value: "₹\(String(format: "%.2f", expense.amount)) INR"
                        )
                        
                        ExpenseInfoCard(
                            icon: "calendar",
                            iconColor: .blue,
                            title: "DATE",
                            value: expense.date.formatted(date: .abbreviated, time: .omitted)
                        )
                        
                        ExpenseInfoCard(
                            icon: "tag.fill",
                            iconColor: .purple,
                            title: "CATEGORY",
                            value: expense.category
                        )
                    }
                    .padding(.horizontal)
                    
                    // Employee and Project Info
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("Employee")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(expense.employeeName)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "briefcase.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("Project")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(expense.projectName ?? "No project")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Timestamps
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Created: \(expense.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Updated: \(expense.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    private func statusColor(for status: Expense.ExpenseStatus) -> Color {
        switch status {
        case .approved: return .green
        case .rejected: return .red
        case .paid: return .purple
        case .submitted: return .blue
        case .draft: return .orange
        }
    }
}

// MARK: - Expense Info Card Component
struct ExpenseInfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}


// MARK: - Share Sheet Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#Preview {
    BlankExpensesPlaceholderView()
}
