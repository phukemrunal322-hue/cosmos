# Document Management System - Fully Dynamic

## Overview
The document management system is **fully dynamic** with real-time synchronization between the mobile app and Firebase database.

## Architecture

### Firebase Collection: `documents`
All documents are stored in the `documents` collection with the following structure:

```json
{
  "documentName": "Document Title",
  "folderName": "MOMs" or "Daily Report",
  "folderType": "MOMs" or "Daily Report",
  "projectId": "project_document_id",
  "projectName": "Project Name",
  "uploadedBy": "user@email.com",
  "uploadedAt": Timestamp,
  "fileName": "file.pdf",
  "fileURL": "storage_url"
}
```

## How It Works

### 1. Adding Documents from Mobile App
When a user adds a document through the app:
- Form collects: document name, folder type (MOMs/Daily Report), file
- Data is saved to Firebase `documents` collection
- `projectId` links the document to the specific project
- Real-time listener automatically updates the UI

### 2. Adding Documents from Firebase Console (Web)
When documents are added directly in Firebase Console:
- Add a new document to the `documents` collection
- **Required fields:**
  - `documentName`: Name of the document
  - `folderName`: "MOMs" or "Daily Report"
  - `folderType`: "MOMs" or "Daily Report"
  - `projectId`: The project's document ID
  - `projectName`: Name of the project
  - `uploadedBy`: Email of uploader
  - `uploadedAt`: Timestamp
  - `fileName`: Name of the file
  - `fileURL`: URL to the file (optional)

- The mobile app will **automatically detect** the new document
- It will appear in the correct section (MOMs or Daily Report)
- No app restart needed - real-time updates!

### 3. Real-Time Synchronization
The app uses Firebase's `addSnapshotListener` which:
- Listens for ANY changes in the `documents` collection
- Filters documents by `projectId`
- Automatically updates the UI when:
  - New documents are added (from app or web)
  - Documents are modified
  - Documents are deleted
- Works in both directions (app ↔ Firebase)

### 4. Project-Specific Display
Each project shows only its own documents:
- Filter: `whereField("projectId", isEqualTo: project.documentId)`
- Documents are grouped by `folderType`:
  - **DAILY REPORT** section (green badge)
  - **MOMs** section (purple badge)

## Testing the System

### Test 1: Add from App
1. Open a project in the app
2. Click "Add Document"
3. Fill in details and save
4. Check Firebase Console → `documents` collection
5. ✅ Document should appear immediately

### Test 2: Add from Firebase Console
1. Open Firebase Console
2. Go to `documents` collection
3. Add a new document with required fields
4. Make sure `projectId` matches your project
5. Open the app (no restart needed)
6. ✅ Document should appear in the correct section

### Test 3: Real-Time Updates
1. Keep the app open on a project
2. Add a document from Firebase Console
3. ✅ Watch it appear in the app instantly
4. Add another from the app
5. ✅ Check Firebase Console - it's there!

## Key Features

✅ **Fully Dynamic** - No hardcoded data
✅ **Real-Time Sync** - Instant updates from both sources
✅ **Project-Specific** - Each project shows only its documents
✅ **Categorized Display** - Automatic grouping by folder type
✅ **Bi-Directional** - Add from app or Firebase Console
✅ **Search Enabled** - Filter documents by name or folder
✅ **Collapsible Sections** - Clean, organized UI

## Important Notes

1. **projectId is Critical**: Always ensure the `projectId` matches the project's `documentId` in Firebase
2. **Folder Types**: Use exactly "MOMs" or "Daily Report" (case-sensitive)
3. **Timestamps**: Use Firebase Timestamp type for `uploadedAt`
4. **Real-Time**: No need to refresh or restart the app - changes appear instantly

## Data Flow

```
Mobile App → Firebase documents collection
     ↓              ↓
     ↓         (Real-time)
     ↓              ↓
     ↓         Snapshot Listener
     ↓              ↓
     ↓         Fetch & Filter
     ↓              ↓
     ↓         Group by Type
     ↓              ↓
     └──────→  Display in UI
```

## Conclusion

The system is **completely dynamic** and works seamlessly in both directions. Whether you add documents from the mobile app or directly in Firebase Console, they will appear in the correct project and section automatically with real-time synchronization.
