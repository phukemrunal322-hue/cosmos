# Firebase Authentication Setup Guide

## Overview
This app now uses Firebase Authentication for secure user login with role-based access control. Users are stored in two separate Firestore collections based on their role:
- **Employees**: `users` collection
- **Clients**: `clients` collection

## Features Implemented

### 1. Firebase Authentication Service (`FirebaseAuthService.swift`)
- ✅ Email/Password authentication
- ✅ Role-based user fetching from Firestore
- ✅ Automatic role detection (employee vs client)
- ✅ Secure logout functionality
- ✅ Password reset capability
- ✅ User signup with role assignment

### 2. Login Flow
- User enters email and password
- Firebase authenticates the credentials
- System checks `users` collection for employee role
- If not found, checks `clients` collection for client role
- Redirects to appropriate dashboard based on role

### 3. Firestore Collections Structure

#### Users Collection (`users`)
```json
{
  "uid": "firebase_user_id",
  "email": "employee@example.com",
  "name": "John Doe",
  "role": "employee",
  "createdAt": "timestamp",
  "profileImage": "optional_url"
}
```

#### Clients Collection (`clients`)
```json
{
  "uid": "firebase_user_id",
  "email": "client@example.com",
  "name": "Jane Smith",
  "role": "client",
  "createdAt": "timestamp",
  "profileImage": "optional_url"
}
```

## Firebase Console Setup

### Step 1: Enable Authentication
1. Go to Firebase Console (https://console.firebase.google.com)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Enable **Email/Password** authentication
5. Click **Save**

### Step 2: Create Firestore Collections
1. Navigate to **Firestore Database**
2. Create two collections:
   - `users` (for employees)
   - `clients` (for clients)

### Step 3: Add Test Users

#### Option A: Using Firebase Console
1. Go to **Authentication** → **Users**
2. Click **Add User**
3. Enter email and password
4. Copy the generated UID

Then in **Firestore Database**:
1. Go to `users` or `clients` collection
2. Click **Add Document**
3. Use the UID as the document ID
4. Add fields:
   ```
   email: "test@example.com"
   name: "Test User"
   role: "employee" or "client"
   createdAt: (current timestamp)
   ```

#### Option B: Using the App (Programmatic Signup)
You can create a temporary signup button in the app to register test users:

```swift
// Add this to ContentView temporarily
Button("Create Test Employee") {
    authService.signUp(
        email: "employee@test.com",
        password: "password123",
        name: "Test Employee",
        role: .employee
    ) { result in
        switch result {
        case .success(let user):
            print("✅ User created: \(user.email)")
        case .failure(let error):
            print("❌ Error: \(error.localizedDescription)")
        }
    }
}
```

## Testing the Authentication

### Test Credentials Setup
1. Create a test employee:
   - Email: `employee@test.com`
   - Password: `Test123!`
   - Collection: `users`

2. Create a test client:
   - Email: `client@test.com`
   - Password: `Test123!`
   - Collection: `clients`

### Testing Login
1. Run the app
2. Enter employee credentials → Should redirect to Employee Dashboard
3. Logout
4. Enter client credentials → Should redirect to Client Dashboard

## Security Rules

### Recommended Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection (employees)
    match /users/{userId} {
      // Users can read their own data
      allow read: if request.auth != null && request.auth.uid == userId;
      // Only authenticated users can create (for signup)
      allow create: if request.auth != null;
      // Users can update their own profile
      allow update: if request.auth != null && request.auth.uid == userId;
    }
    
    // Clients collection
    match /clients/{clientId} {
      // Clients can read their own data
      allow read: if request.auth != null && request.auth.uid == clientId;
      // Only authenticated users can create (for signup)
      allow create: if request.auth != null;
      // Clients can update their own profile
      allow update: if request.auth != null && request.auth.uid == clientId;
    }
    
    // Projects collection
    match /projects/{projectId} {
      // Authenticated users can read projects
      allow read: if request.auth != null;
      // Only employees can create/update/delete projects
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid));
    }
  }
}
```

## Error Handling

The app handles these authentication errors:
- **Invalid credentials**: Wrong email or password
- **User not found**: User doesn't exist in either collection
- **Network error**: Connection issues
- **Role not found**: User exists in Firebase Auth but not in Firestore

## Code Structure

### Key Files
1. **FirebaseAuthService.swift**: Authentication logic
2. **ContentView.swift**: Login UI and authentication flow
3. **AppState.swift**: User state management
4. **User.swift**: User model with role enum

### Authentication Flow
```
User Login
    ↓
Firebase Auth
    ↓
Check users collection (employee)
    ↓
If not found → Check clients collection
    ↓
Fetch user data
    ↓
Redirect to appropriate dashboard
```

## Troubleshooting

### Issue: "No such module 'FirebaseAuth'"
**Solution**: The module is already included in the project. This is an IDE indexing issue. Build the project in Xcode to resolve.

### Issue: Login fails with "User not found"
**Solution**: 
1. Verify the user exists in Firebase Authentication
2. Verify a document with the user's UID exists in either `users` or `clients` collection
3. Check that the document has the required fields (email, name, role)

### Issue: Wrong dashboard after login
**Solution**: 
1. Check the `role` field in the Firestore document
2. Ensure the document is in the correct collection (`users` for employees, `clients` for clients)

## Next Steps

1. ✅ Set up Firebase Authentication in Console
2. ✅ Create test users in both collections
3. ✅ Test login flow for both roles
4. ✅ Implement Firestore security rules
5. 🔄 Add password reset functionality to UI (optional)
6. 🔄 Add user profile editing (optional)
7. 🔄 Add email verification (optional)

## Additional Features Available

The `FirebaseAuthService` includes these ready-to-use methods:
- `signUp()`: Create new users
- `login()`: Authenticate users
- `logout()`: Sign out users
- `resetPassword()`: Send password reset email
- `checkAuthStatus()`: Check if user is already logged in

## Support

For Firebase documentation:
- Authentication: https://firebase.google.com/docs/auth
- Firestore: https://firebase.google.com/docs/firestore
- iOS Setup: https://firebase.google.com/docs/ios/setup
