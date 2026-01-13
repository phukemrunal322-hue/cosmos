# Fix: ExpenseStatus Enum Update

## Problem
```
Error: Type 'Expense.ExpenseStatus' has no member 'pending'
Location: FirebaseService.swift:4704
```

## Root Cause
The `ExpenseStatus` enum was updated to include `draft` and `submitted` statuses, and `pending` was removed. However, the default fallback value in `fetchExpenses()` was still using `.pending`.

## Solution

### Before (❌ Error):
```swift
enum ExpenseStatus: String, Codable {
    case pending = "Pending"  // ❌ Old
    case approved = "Approved"
    case paid = "Paid"
    case rejected = "Rejected"
}

// In fetchExpenses():
let status = Expense.ExpenseStatus(rawValue: statusRaw) ?? .pending  // ❌ Error!
```

### After (✅ Fixed):
```swift
enum ExpenseStatus: String, Codable {
    case draft = "Draft"           // ✅ New
    case submitted = "Submitted"   // ✅ New
    case approved = "Approved"
    case rejected = "Rejected"
    case paid = "Paid"
}

// In fetchExpenses():
let status = Expense.ExpenseStatus(rawValue: statusRaw) ?? .draft  // ✅ Fixed!
```

## Changes Made

### 1. Updated ExpenseStatus Enum (Line 4664-4669)
```swift
enum ExpenseStatus: String, Codable {
    case draft = "Draft"
    case submitted = "Submitted"
    case approved = "Approved"
    case rejected = "Rejected"
    case paid = "Paid"
}
```

### 2. Updated Default Status (Line 4704)
```swift
// Changed from:
let status = Expense.ExpenseStatus(rawValue: statusRaw) ?? .pending

// To:
let status = Expense.ExpenseStatus(rawValue: statusRaw) ?? .draft
```

### 3. Updated Computed Properties (Lines 4784-4795)
```swift
// Removed:
var pendingExpenses: [Expense] {
    expenses.filter { $0.status == .pending }
}

// Added:
var draftExpenses: [Expense] {
    expenses.filter { $0.status == .draft }
}

var submittedExpenses: [Expense] {
    expenses.filter { $0.status == .submitted }
}

var rejectedExpenses: [Expense] {
    expenses.filter { $0.status == .rejected }
}
```

## Status Workflow

### Old Workflow:
```
Pending → Approved → Paid
         ↓
      Rejected
```

### New Workflow:
```
Draft → Submitted → Approved → Paid
                    ↓
                 Rejected
```

## UI Updates

### Dropdown Options:
```
✓ All Statuses
- Draft         (new)
- Submitted     (new)
- Approved
- Rejected
- Paid
```

### Stat Cards:
```
[Total] [Approved] [Paid] [Draft]
```

## Database Mapping

### Status Values in Firebase:
```json
{
  "status": "Draft"      // or "Submitted", "Approved", "Rejected", "Paid"
}
```

### Fallback Behavior:
If Firebase has an invalid status value, it defaults to `"Draft"`.

## Testing

### Test Cases:
1. ✅ Create expense with status "Draft"
2. ✅ Create expense with status "Submitted"
3. ✅ Create expense with status "Approved"
4. ✅ Create expense with status "Rejected"
5. ✅ Create expense with status "Paid"
6. ✅ Create expense with invalid status → defaults to "Draft"

## Result
- ✅ No compilation errors
- ✅ All status values properly mapped
- ✅ Default fallback works correctly
- ✅ Computed properties updated
- ✅ UI dropdowns show correct options
- ✅ Filtering works with new statuses
