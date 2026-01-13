# Expense Management - Dynamic Firebase Integration

## ✅ Completed Implementation

### 1. Firebase Backend Setup

#### Expense Model (FirebaseService.swift)
```swift
struct Expense: Identifiable, Codable {
    var id: String?
    var employeeName: String
    var employeeId: String
    var title: String
    var description: String
    var amount: Double
    var category: String
    var status: ExpenseStatus
    var date: Date
    var receiptURL: String?
    var createdAt: Date
    var updatedAt: Date
    
    enum ExpenseStatus: String, Codable {
        case pending = "Pending"
        case approved = "Approved"
        case paid = "Paid"
        case rejected = "Rejected"
    }
}
```

#### Firebase Functions Added:
- ✅ `fetchExpenses()` - Real-time listener for expenses
- ✅ `addExpense()` - Add new expense to Firebase
- ✅ `updateExpenseStatus()` - Update expense status
- ✅ `deleteExpense()` - Delete expense
- ✅ Computed properties for statistics:
  - `totalExpenses` - Total count
  - `approvedExpenses` - Filtered approved expenses
  - `paidExpenses` - Filtered paid expenses
  - `pendingExpenses` - Filtered pending expenses
  - `totalApprovedAmount` - Sum of approved amounts
  - `totalPaidAmount` - Sum of paid amounts

### 2. UI Implementation (BlankExpensesPlaceholderView.swift)

#### Dynamic Stats Cards (All Same Shape)
```swift
// Card 1: Total
count: firebaseService.totalExpenses
icon: Blue document icon

// Card 2: Approved
count: firebaseService.approvedExpenses.count
amount: ₹{totalApprovedAmount}
icon: Green checkmark

// Card 3: Paid
count: firebaseService.paidExpenses.count
amount: ₹{totalPaidAmount}
icon: Purple rupee sign
```

**All cards have:**
- ✅ Same shape (rounded rectangle)
- ✅ Same border style (colored border with opacity)
- ✅ Same padding and spacing
- ✅ Dynamic data from Firebase
- ✅ Real-time updates

#### Features Implemented:
1. **Header Section**
   - Title: "Expense Management"
   - Subtitle: "Review and process employee reimbursement claims"
   - Export Excel button (gradient)

2. **Stats Cards**
   - All cards uniform shape
   - Dynamic counts from Firebase
   - Dynamic amounts (formatted with ₹)
   - Color-coded icons and borders

3. **Search Bar**
   - Searches: title, employee name, description
   - Real-time filtering

4. **Filter Buttons**
   - Status filter (All, Pending, Approved, Paid, Rejected)
   - Category filter (Travel, Food, Accommodation, etc.)
   - Date filter (All Time, This Month, etc.)

5. **Expense List**
   - Dynamic data from Firebase
   - Filtered based on search and filters
   - Shows: employee, title, date, amount, status, category
   - Empty state when no expenses found

6. **Real-time Updates**
   - Automatically fetches expenses on view appear
   - Updates when data changes in Firebase
   - No manual refresh needed

## Firebase Database Structure

### Collection: `expenses`

```json
{
  "documentId": "auto-generated",
  "employeeName": "John Doe",
  "employeeId": "emp123",
  "title": "Travel Expense",
  "description": "Business trip to Mumbai",
  "amount": 5000.00,
  "category": "Travel",
  "status": "Pending",
  "date": Timestamp,
  "receiptURL": "https://...",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

## How to Add Expenses

### Method 1: Using Firebase Console
1. Go to Firebase Console
2. Navigate to Firestore Database
3. Create collection: `expenses`
4. Add document with fields:
   - employeeName (string)
   - employeeId (string)
   - title (string)
   - description (string)
   - amount (number)
   - category (string)
   - status (string: "Pending", "Approved", "Paid", "Rejected")
   - date (timestamp)
   - createdAt (timestamp)
   - updatedAt (timestamp)

### Method 2: Using Code (Future Implementation)
```swift
let newExpense = Expense(
    id: nil,
    employeeName: "John Doe",
    employeeId: "emp123",
    title: "Travel Expense",
    description: "Business trip",
    amount: 5000.00,
    category: "Travel",
    status: .pending,
    date: Date(),
    receiptURL: nil,
    createdAt: Date(),
    updatedAt: Date()
)

firebaseService.addExpense(newExpense) { result in
    switch result {
    case .success(let id):
        print("Expense added with ID: \(id)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

## Testing

1. **Add Test Data:**
   ```
   Go to Firebase Console → Firestore → expenses collection
   Add a few test expenses with different statuses
   ```

2. **Verify Real-time Updates:**
   ```
   - Open Expenses page in app
   - Add/edit expense in Firebase Console
   - See changes appear immediately in app
   ```

3. **Test Filters:**
   ```
   - Use search bar to filter by name/title
   - Use status filter to show only Paid/Pending
   - Use category filter to show specific categories
   ```

## Dynamic Features

✅ **Cards automatically update** when data changes
✅ **Counts are calculated** from Firebase data
✅ **Amounts are summed** dynamically
✅ **List updates** in real-time
✅ **Filters work** on live data
✅ **Search works** on live data
✅ **No hardcoded values** - everything from Firebase

## Next Steps (Optional)

1. Add "Create Expense" button and form
2. Add expense detail view (tap to view)
3. Add approve/reject buttons for admins
4. Add receipt upload functionality
5. Implement Excel/PDF export
6. Add date range filtering
7. Add expense analytics/charts
