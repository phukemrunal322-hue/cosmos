# MOM Save to Documents Collection - Implementation Summary

## Problem
When saving Minutes of Meeting (MOM), the generated MOM ID from the `minutes_of_meetings` collection was not being saved in the `documents` collection, making it difficult to link the two records.

## Solution
Modified the save flow to ensure the MOM document ID is properly saved in the documents collection.

## Changes Made

### 1. FirebaseService.swift - `saveMOM` function (Line 4465)
**Changed:** Modified the completion handler to return `Result<String, Error>` instead of `Error?`
- Now returns the generated document ID on success
- Returns error on failure
- This allows the calling code to get the MOM document ID immediately after saving

```swift
func saveMOM(_ mom: MOMDocument, completion: @escaping (Result<String, Error>) -> Void)
```

### 2. FirebaseService.swift - `saveDocumentEntry` function (Line 4600)
**Added:** New optional parameter `momId` to link documents to MOMs
- Added `momId: String? = nil` parameter
- Changed `data` from `let` to `var` to allow modification
- Conditionally adds `momId` to the data dictionary if provided

```swift
func saveDocumentEntry(name: String, url: String, category: String, description: String, userUid: String?, momId: String? = nil, completion: @escaping (Error?) -> Void)
```

### 3. MinutesOfMeetingView.swift - `saveMOM` function (Line 1313)
**Refactored:** Complete rewrite of the save flow to ensure proper ordering
- **Step 1:** Save MOM to `minutes_of_meetings` collection → Get document ID
- **Step 2:** Generate PDF from the MOM data
- **Step 3:** Upload PDF to Firebase Storage → Get download URL
- **Step 4:** Save to `documents` collection with MOM ID and PDF URL

## New Save Flow

```
1. saveMOM(doc) 
   ↓ (returns momDocumentId)
2. Generate PDF
   ↓ (returns pdfURL)
3. Upload PDF to Storage
   ↓ (returns downloadURL)
4. saveDocumentEntry(..., momId: momDocumentId)
   ↓
   Success! ✓
```

## Database Structure

### documents collection
```json
{
  "id": "UUID",
  "name": "Project Name",
  "url": "https://firebase.storage.../MOM_xxx.pdf",
  "category": "Knowledge",
  "description": "Minutes of Meeting for...",
  "createdAt": Timestamp,
  "createdBy": "user_uid",
  "accessType": "Internal",
  "momId": "MOM_DOCUMENT_ID"  // ← NEW: Links to minutes_of_meetings collection
}
```

### minutes_of_meetings collection
```json
{
  "documentId": "MOM_DOCUMENT_ID",  // ← This ID is now saved in documents.momId
  "projectName": "...",
  "date": Timestamp,
  "startTime": Timestamp,
  "endTime": Timestamp,
  "venue": "...",
  "internalAttendees": [...],
  "externalAttendees": "...",
  "preparedBy": "...",
  "agenda": [...],
  "discussionPoints": [...],
  "analysis": {...},
  "actionItems": [...],
  "createdAt": Timestamp
}
```

## Benefits
1. ✅ MOM ID is now properly saved in the documents collection
2. ✅ Easy to query documents by MOM ID
3. ✅ Bidirectional linking between collections
4. ✅ Better data integrity and traceability
5. ✅ Can retrieve full MOM details from documents collection reference

## Testing
To verify the implementation:
1. Create a new MOM
2. Save the MOM
3. Check Firebase Console → `documents` collection
4. Verify the document has a `momId` field with the correct ID
5. Cross-reference with `minutes_of_meetings` collection to confirm the ID matches
