# Fix: Extension Stored Property Error

## Problem
```
Error: Extensions must not contain stored properties
Error: Non-static property 'expenses' declared inside an extension cannot have a wrapper
```

## Root Cause
Swift extensions cannot contain stored properties (properties with `@Published` or other property wrappers).

## Solution

### Before (❌ Error):
```swift
// MARK: - Expense Management Extension
extension FirebaseService {
    @Published var expenses: [Expense] = []  // ❌ ERROR!
    
    func fetchExpenses() {
        // ...
    }
}
```

### After (✅ Fixed):
```swift
// In main FirebaseService class
class FirebaseService: ObservableObject {
    // ... other properties ...
    @Published var expenses: [Expense] = []  // ✅ Moved here
    
    private init() {
        fetchArchivedTasks()
    }
}

// Extension only contains methods
extension FirebaseService {
    func fetchExpenses() {  // ✅ Methods are OK in extensions
        // ...
    }
    
    func addExpense() {
        // ...
    }
}
```

## Changes Made

1. **Added to main class (Line 66):**
   ```swift
   @Published var expenses: [Expense] = []
   ```

2. **Removed from extension (Line 4674):**
   ```swift
   // Deleted this line:
   @Published var expenses: [Expense] = []
   ```

## Why This Works

✅ **Main class can have:**
- Stored properties
- Property wrappers (@Published, @State, etc.)
- Methods
- Computed properties

✅ **Extensions can have:**
- Methods (functions)
- Computed properties
- Convenience initializers

❌ **Extensions CANNOT have:**
- Stored properties
- Property wrappers on stored properties

## Result
- ✅ No compilation errors
- ✅ `expenses` property accessible throughout FirebaseService
- ✅ All extension methods work correctly
- ✅ Real-time updates still work
- ✅ @Published wrapper works as expected
