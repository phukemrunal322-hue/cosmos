import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ExpensesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var searchText: String = ""
    @State private var selectedStatusFilter: String = "All Statuses"
    @State private var selectedCategoryFilter: String = "All Categories"
    @State private var fromDate: Date? = nil
    @State private var toDate: Date? = nil
    @State private var isFromDatePickerPresented: Bool = false
    @State private var isToDatePickerPresented: Bool = false
    @State private var tempFromDate: Date = Date()
    @State private var tempToDate: Date = Date()
    @State private var isExportingCSV: Bool = false
    @State private var csvURL: URL? = nil
    @State private var isShowingNewExpenseForm: Bool = false
    @State private var editingExpense: ExpenseItem? = nil

    private let statusOptions: [String] = ["All Statuses", "Draft", "Submitted", "Approved", "Rejected", "Paid"]
    private let categoryOptions: [String] = ["All Categories", "Travel", "Food", "Stay", "Office", "Other"]

    @State private var expenses: [ExpenseItem] = []

    private var filteredExpenses: [ExpenseItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusFilter = selectedStatusFilter.lowercased()
        let categoryFilter = selectedCategoryFilter.lowercased()

        return expenses.filter { expense in
            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    expense.employee.localizedCaseInsensitiveContains(query) ||
                    expense.category.localizedCaseInsensitiveContains(query) ||
                    expense.title.localizedCaseInsensitiveContains(query) ||
                    (expense.description?.localizedCaseInsensitiveContains(query) ?? false)
            }

            let matchesStatus: Bool
            if statusFilter == "all statuses" {
                matchesStatus = true
            } else {
                matchesStatus = expense.status.displayTitle.lowercased() == statusFilter
            }

            let matchesCategory: Bool
            if categoryFilter == "all categories" {
                matchesCategory = true
            } else {
                matchesCategory = expense.category.lowercased() == categoryFilter
            }

            let matchesDateRange: Bool
            if fromDate == nil && toDate == nil {
                matchesDateRange = true
            } else if let expenseDate = parseExpenseDate(expense.date) {
                if let from = fromDate, expenseDate < from {
                    matchesDateRange = false
                } else if let to = toDate, expenseDate > to {
                    matchesDateRange = false
                } else {
                    matchesDateRange = true
                }
            } else {
                matchesDateRange = true
            }

            return matchesSearch && matchesStatus && matchesCategory && matchesDateRange
        }
    }

    private var totalClaims: Int { expenses.count }
    private var approvedClaims: Int { expenses.filter { $0.status == .approved }.count }
    private var paidAmount: Double { expenses.filter { $0.status == .paid }.reduce(0) { $0 + $1.amount } }
    private var paidClaims: Int { expenses.filter { $0.status == .paid }.count }
    private var unpaidClaims: Int { expenses.filter { $0.status == .unpaid }.count }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    searchBar

                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        summarySection
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.08), radius: 5, x: 0, y: 3)

                    filterSection
                    tableSection
                }
                .padding()
                .background(Color.gray.opacity(0.05))
            }
            .navigationTitle("Expense Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            fetchExpenses()
        }
        .sheet(isPresented: $isFromDatePickerPresented) {
            VStack(spacing: 20) {
                HStack {
                    Text("Select From Date")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Close") {
                        fromDate = tempFromDate
                        isFromDatePickerPresented = false
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)
                .padding(.top)

                VStack {
                    DatePicker("", selection: $tempFromDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                }
                .background(.background)
                .cornerRadius(16)
                .shadow(color: .gray.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding()

                Spacer()
            }
            .background(Color.gray.opacity(0.05).ignoresSafeArea())
        }
        .sheet(isPresented: $isToDatePickerPresented) {
            VStack(spacing: 20) {
                HStack {
                    Text("Select To Date")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Close") {
                        toDate = tempToDate
                        isToDatePickerPresented = false
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)
                .padding(.top)

                VStack {
                    DatePicker("", selection: $tempToDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                }
                .background(.background)
                .cornerRadius(16)
                .shadow(color: .gray.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding()

                Spacer()
            }
            .background(Color.gray.opacity(0.05).ignoresSafeArea())
        }
        .sheet(isPresented: $isExportingCSV, onDismiss: {
            csvURL = nil
        }) {
            if let url = csvURL {
                ReportShareSheet(activityItems: [url])
            } else {
                Text("Preparing export...")
            }
        }
        .sheet(isPresented: $isShowingNewExpenseForm, onDismiss: {
            editingExpense = nil
        }) {
            NewExpenseFormView(firebaseService: firebaseService, authService: authService, editingExpense: editingExpense)
        }
    }

    private var headerSection: some View {
        Text("Review and process employee reimbursement claims")
            .font(.subheadline)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(title: "Total Claims", value: "\(totalClaims)", subtitle: nil, icon: "creditcard", color: .purple)
                SummaryCard(title: "Approved", value: "\(approvedClaims)", subtitle: nil, icon: "checkmark.seal", color: .green)
            }
            HStack(spacing: 12) {
                SummaryCard(title: "Paid", value: String(format: "₹%.2f", paidAmount), subtitle: "\(paidClaims) claims", icon: "indianrupeesign.circle", color: .pink)
                SummaryCard(title: "Unpaid", value: "\(unpaidClaims)", subtitle: nil, icon: "clock", color: .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterSection: some View {
        VStack(spacing: 12) {
            // Filters row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    statusFilterMenu
                    categoryFilterMenu

                    Button(action: {
                        tempFromDate = fromDate ?? Date()
                        isFromDatePickerPresented = true
                    }) {
                        datePill(title: formattedDate(from: fromDate))
                    }

                    Text("-")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button(action: {
                        tempToDate = toDate ?? Date()
                        isToDatePickerPresented = true
                    }) {
                        datePill(title: formattedDate(from: toDate))
                    }

                    Button(action: {
                        generateCSVAndShare()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("Export CSV")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.background)
                        .cornerRadius(20)
                        .shadow(color: .gray.opacity(0.08), radius: 4, x: 0, y: 2)
                    }
                    Button(action: {
                        editingExpense = nil
                        isShowingNewExpenseForm = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("New Expense")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(color: .blue.opacity(0.25), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusFilterMenu: some View {
        Menu {
            ForEach(statusOptions, id: \.self) { option in
                Button(option) {
                    selectedStatusFilter = option
                }
            }
        } label: {
            filterPill(title: selectedStatusFilter, systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var categoryFilterMenu: some View {
        Menu {
            ForEach(categoryOptions, id: \.self) { option in
                Button(option) {
                    selectedCategoryFilter = option
                }
            }
        } label: {
            filterPill(title: selectedCategoryFilter, systemImage: "square.grid.2x2")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search by title, employee, description...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(.background)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var tableSection: some View {
        if filteredExpenses.isEmpty {
            AnyView(
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.6))

                        Text("No expenses found")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("You haven't submitted any expenses matching your filters yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(.background)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.08), radius: 5, x: 0, y: 3)

                    Button(action: {
                        editingExpense = nil
                        isShowingNewExpenseForm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Create New Expense")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.25), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            )
        } else {
            AnyView(
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                tableHeaderCell("EMPLOYEE", alignment: .leading, width: 240)
                                tableColumnDivider
                                tableHeaderCell("EXPENSE DETAILS", alignment: .leading, width: 150)
                                tableColumnDivider
                                tableHeaderCell("CATEGORY", alignment: .leading, width: 120)
                                tableColumnDivider
                                tableHeaderCell("AMOUNT", alignment: .trailing, width: 120)
                                tableColumnDivider
                                tableHeaderCell("STATUS", alignment: .center, width: 100)
                                tableColumnDivider
                                tableHeaderCell("ACTIONS", alignment: .center, width: 140)
                            }
                            .background(Color.gray.opacity(0.03))

                            ForEach(filteredExpenses) { expense in
                                HStack(spacing: 0) {
                                    tableBodyCell(expense.employee, alignment: .leading, width: 240)
                                    tableColumnDivider
                                    expenseDetailsCell(expense: expense, width: 150)
                                    tableColumnDivider
                                    tableBodyCell(expense.category, alignment: .leading, width: 120)
                                    tableColumnDivider
                                    tableBodyCell(String(format: "%.2f %@", expense.amount, expense.currency), alignment: .trailing, width: 120)
                                    tableColumnDivider
                                    statusCell(for: expense, width: 100)
                                    tableColumnDivider
                                    actionsCell(for: expense, width: 140)
                                }
                                .background(.background)
                                .overlay(Divider().opacity(0.6), alignment: .bottom)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .background(.background)
                        .cornerRadius(16)
                        .shadow(color: .gray.opacity(0.08), radius: 5, x: 0, y: 3)
                    }
                }
            )
        }
    }

    private func tableHeaderCell(_ title: String, alignment: Alignment, width: CGFloat) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(.gray)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
    }

    private func tableBodyCell(_ text: String, alignment: Alignment, width: CGFloat) -> some View {
        Text(text)
            .font(.subheadline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
    }

    private var tableColumnDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 1)
    }
    
    private func statusCell(for expense: ExpenseItem, width: CGFloat) -> some View {
        Text(expense.status.displayTitle)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(expense.status.badgeColor.opacity(0.15))
            .foregroundColor(expense.status.badgeColor)
            .cornerRadius(8)
            .frame(width: width, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
    }
    
    private func actionsCell(for expense: ExpenseItem, width: CGFloat) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                startEditing(expense)
            }) {
                Image(systemName: "square.and.pencil")
            }
            
            Button(action: {
                deleteExpense(expense)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .font(.caption2)
        .frame(width: width, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
    
    private func expenseDetailsCell(expense: ExpenseItem, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(expense.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if let description = expense.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Text(expense.date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: width, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
    
    // MARK: - Filter Pills Helpers

    private func filterPill(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(title)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.background)
        .cornerRadius(20)
        .shadow(color: .gray.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func datePill(title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundColor(.green)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.background)
        .cornerRadius(20)
        .shadow(color: .gray.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func fetchExpenses() {
        // Check if user is Super Admin to fetch ALL expenses
        let isSuperAdmin = authService.currentUser?.role == .superAdmin
        
        // Pass nil credentials for Super Admin to bypass filtering in fetchExpensesForEmployee
        let uid = isSuperAdmin ? nil : authService.currentUid
        let email = isSuperAdmin ? nil : authService.currentUser?.email
        
        firebaseService.fetchExpensesForEmployee(userUid: uid, userEmail: email) { items in
            DispatchQueue.main.async {
                self.expenses = items
            }
        }
    }

    private func formattedDate(from date: Date?) -> String {
        guard let date = date else { return "dd-mm-yyyy" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: date)
    }

    private func generateCSVAndShare() {
        var rows: [[String]] = []
        rows.append(["Employee", "Date", "Category", "Amount", "Currency", "Status"])

        for expense in filteredExpenses {
            let amountString = String(format: "%.2f", expense.amount)
            rows.append([
                expense.employee,
                expense.date,
                expense.category,
                amountString,
                expense.currency,
                expense.status.displayTitle
            ])
        }

        let csvString = rows
            .map { row in
                row.map { value in
                    "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                }.joined(separator: ",")
            }
            .joined(separator: "\n")

        do {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            let fileURL = documentsDir.appendingPathComponent("Expenses.csv")
            try csvString.data(using: .utf8)?.write(to: fileURL, options: .atomic)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            print("Error writing CSV: \(error.localizedDescription)")
        }
    }

    private func parseExpenseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: dateString)
    }

    private func startEditing(_ expense: ExpenseItem) {
        editingExpense = expense
        isShowingNewExpenseForm = true
    }

    private func deleteExpense(_ expense: ExpenseItem) {
        firebaseService.deleteExpense(documentId: expense.id) { success in
            if !success {
                print("Failed to delete expense with id: \(expense.id)")
            }
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .padding(10)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.08), radius: 5, x: 0, y: 3)
    }
}

struct ExpenseItem: Identifiable {
    enum Status {
        case draft
        case submitted
        case approved
        case rejected
        case paid
        case unpaid

        var displayTitle: String {
            switch self {
            case .draft: return "Draft"
            case .submitted: return "Submitted"
            case .approved: return "Approved"
            case .rejected: return "Rejected"
            case .paid: return "Paid"
            case .unpaid: return "Unpaid"
            }
        }

        var badgeColor: Color {
            switch self {
            case .draft: return .gray
            case .submitted: return .blue
            case .approved: return .green
            case .rejected: return .red
            case .paid: return .purple
            case .unpaid: return .orange
            }
        }
    }

    let id: String
    let employee: String
    let date: String
    let category: String
    let amount: Double
    let currency: String
    let status: Status
    let title: String
    let projectName: String?
    let description: String?
    let receiptUrl: String?
}

struct NewExpenseFormView: View {
    @ObservedObject var firebaseService: FirebaseService
    @ObservedObject var authService: FirebaseAuthService
    @Environment(\.dismiss) private var dismiss

    let editingExpense: ExpenseItem?

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var selectedProjectName: String = ""
    @State private var category: String = "Other"
    @State private var amountText: String = ""
    @State private var currency: String = "INR"
    @State private var descriptionText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var receiptFileURL: URL?
    @State private var receiptFileName: String?
    @State private var existingReceiptUrl: String?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let categories: [String] = ["Travel", "Food", "Stay", "Office", "Other"]

    @StateObject private var speechHelper = SpeechRecognizerHelper()
    @State private var activeSpeechField: SpeechField?

    private var isEditing: Bool { editingExpense != nil }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    enum SpeechField {
        case title
        case description
    }

    private var assignedProjects: [Project] {
        firebaseService.projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isEditing ? "Edit Expense" : "New Expense")
                            .font(.title2)
                            .fontWeight(.bold)

                        ZStack(alignment: .trailing) {
                            TextField("e.g. Client Lunch", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button(action: {
                                toggleSpeech(for: .title)
                            }) {
                                Image(systemName: speechIcon(for: .title))
                                    .foregroundColor(speechHelper.isRecording && activeSpeechField == .title ? .red : .gray)
                                    .padding(.trailing, 8)
                            }
                        }

                        HStack(spacing: 12) {
                            Text("Date")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Project (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Menu {
                                Button("None") {
                                    selectedProjectName = ""
                                }
                                ForEach(assignedProjects) { project in
                                    Button(project.name) {
                                        selectedProjectName = project.name
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedProjectName.isEmpty ? "Select Project" : selectedProjectName)
                                        .foregroundColor(selectedProjectName.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Menu {
                                ForEach(categories, id: \.self) { item in
                                    Button(item) {
                                        category = item
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(category)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Amount")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                TextField("0.00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: amountText) { newValue in
                                        var filtered = ""
                                        var hasDecimalPoint = false
                                        for ch in newValue {
                                            if ch.isNumber {
                                                filtered.append(ch)
                                            } else if ch == "." && !hasDecimalPoint {
                                                filtered.append(ch)
                                                hasDecimalPoint = true
                                            }
                                        }
                                        if filtered != newValue {
                                            amountText = filtered
                                        }
                                    }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Currency")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("INR")
                                    .frame(width: 80)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            ZStack(alignment: .bottomTrailing) {
                                TextEditor(text: $descriptionText)
                                    .frame(minHeight: 80)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                Button(action: {
                                    toggleSpeech(for: .description)
                                }) {
                                    Image(systemName: speechIcon(for: .description))
                                        .foregroundColor(speechHelper.isRecording && activeSpeechField == .description ? .red : .gray)
                                        .padding(12)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Receipt (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Button(action: {
                                showDocumentPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "tray.and.arrow.up")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(receiptFileName ?? "Upload a file")
                                            .font(.subheadline)
                                        Text("PNG, JPG, PDF up to 1MB")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.15), radius: 5)

                    HStack(spacing: 12) {
                        Button(action: {
                            submitExpense(status: "draft")
                        }) {
                            Text("Save as Draft")
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: {
                            submitExpense(status: "submitted")
                        }) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Submit Expense")
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(canSubmit ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(!canSubmit || isSubmitting)
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                ReceiptDocumentPicker { url in
                    handlePickedFile(url)
                } onCancel: {
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                let uid = authService.currentUid
                let email = authService.currentUser?.email
                // Load only projects assigned to the logged-in employee, same as ProjectsView
                firebaseService.fetchProjectsForEmployee(userUid: uid, userEmail: email)
                firebaseService.fetchTasks(forUserUid: uid, userEmail: email)

                if let expense = editingExpense {
                    title = expense.title
                    category = expense.category
                    amountText = String(expense.amount)
                    selectedProjectName = expense.projectName ?? ""
                    descriptionText = expense.description ?? ""
                    existingReceiptUrl = expense.receiptUrl
                    if let url = expense.receiptUrl, !url.isEmpty {
                        receiptFileName = URL(string: url)?.lastPathComponent ?? "Existing receipt"
                    }

                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let parsed = formatter.date(from: expense.date) {
                        date = parsed
                    }
                }
            }
        }
    }

    private func toggleSpeech(for field: SpeechField) {
        if speechHelper.isRecording && activeSpeechField == field {
            speechHelper.stop()
            activeSpeechField = nil
            return
        }

        if speechHelper.isRecording {
            speechHelper.stop()
        }

        activeSpeechField = field

        let baseTitle = title
        let baseDescription = descriptionText

        speechHelper.toggle { text in
            switch self.activeSpeechField {
            case .title:
                let prefix = baseTitle.isEmpty ? "" : baseTitle + " "
                self.title = prefix + text
            case .description:
                let prefix = baseDescription.isEmpty ? "" : baseDescription + " "
                self.descriptionText = prefix + text
            case .none:
                break
            }
        }
    }

    private func speechIcon(for field: SpeechField) -> String {
        if speechHelper.isRecording && activeSpeechField == field {
            return "mic.circle.fill"
        } else {
            return "mic.circle"
        }
    }

    private func handlePickedFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let maxSize = 1_048_576
            if data.count > maxSize {
                errorMessage = "File is larger than 1MB. Please choose a smaller file."
                showError = true
                return
            }
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = url.lastPathComponent
            let destURL = tempDir.appendingPathComponent(UUID().uuidString + "_" + fileName)
            try data.write(to: destURL)
            receiptFileURL = destURL
            receiptFileName = fileName
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func submitExpense(status: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDraft = status.lowercased() == "draft"

        let amount: Double
        if isDraft {
            amount = Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
        } else {
            guard !trimmedTitle.isEmpty else {
                errorMessage = "Please enter a title for the expense."
                showError = true
                return
            }
            guard let parsed = Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                errorMessage = "Please enter a valid amount."
                showError = true
                return
            }
            amount = parsed
        }

        if isSubmitting {
            return
        }
        isSubmitting = true

        let uid = authService.currentUid
        let email = authService.currentUser?.email

        func handleCompletion(_ success: Bool) {
            isSubmitting = false
            if success {
                dismiss()
            } else {
                errorMessage = "Failed to save expense. Please try again."
                showError = true
            }
        }

        func finishSave(receiptURLString: String?) {
            let finalCurrency = "INR"
            let project = selectedProjectName.isEmpty ? nil : selectedProjectName

            if let existing = editingExpense {
                firebaseService.updateExpense(
                    documentId: existing.id,
                    forUserUid: uid,
                    userEmail: email,
                    title: trimmedTitle.isEmpty ? (isDraft ? existing.title : trimmedTitle) : trimmedTitle,
                    date: date,
                    category: category,
                    amount: amount,
                    currency: finalCurrency,
                    description: descriptionText,
                    projectName: project,
                    receiptURL: receiptURLString ?? existing.receiptUrl,
                    status: status
                ) { success in
                    handleCompletion(success)
                }
            } else {
                firebaseService.createExpense(
                    forUserUid: uid,
                    userEmail: email,
                    title: trimmedTitle,
                    date: date,
                    category: category,
                    amount: amount,
                    currency: finalCurrency,
                    description: descriptionText,
                    projectName: project,
                    receiptURL: receiptURLString,
                    status: status
                ) { success in
                    handleCompletion(success)
                }
            }
        }

        if let fileURL = receiptFileURL {
            firebaseService.uploadExpenseReceipt(fileURL: fileURL, forUserUid: uid) { result in
                switch result {
                case .success(let urlString):
                    finishSave(receiptURLString: urlString)
                case .failure(let error):
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } else {
            finishSave(receiptURLString: existingReceiptUrl)
        }
    }
}

struct ReceiptDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            UTType.jpeg,
            UTType.png,
            UTType.pdf
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

