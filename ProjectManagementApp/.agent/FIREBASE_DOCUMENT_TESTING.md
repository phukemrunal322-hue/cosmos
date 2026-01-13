# Firebase Document Testing Guide

## How to Add a Test Document in Firebase Console

### Step 1: Get Your Project ID
1. Open the app
2. Navigate to the project (e.g., "TestMrunal")
3. Check the Xcode console logs for:
   ```
   📄 Setting up real-time listener for project: TestMrunal
   📄 Project ID: abc123xyz
   ```
4. Copy the Project ID

### Step 2: Add Document in Firebase Console
1. Open Firebase Console: https://console.firebase.google.com
2. Select your project: `cosmos-erp`
3. Go to **Firestore Database**
4. Click on **documents** collection
5. Click **Add document**

### Step 3: Fill in Document Fields

**Document ID**: (Auto-generate or leave blank)

**Fields to add:**

| Field Name | Type | Value | Example |
|------------|------|-------|---------|
| `documentName` | string | Name of your document | "Test Document" |
| `folderName` | string | "MOMs" or "Daily Report" | "MOMs" |
| `folderType` | string | "MOMs" or "Daily Report" | "MOMs" |
| `projectId` | string | **YOUR PROJECT ID** | "1766828953419" |
| `projectName` | string | Name of project | "TestMrunal" |
| `uploadedBy` | string | Email | "test@example.com" |
| `uploadedAt` | timestamp | Current time | (Click timestamp button) |
| `fileName` | string | File name | "document.pdf" |
| `fileURL` | string | URL or empty | "" |

### Step 4: Verify in App

1. Keep the app open on the project screen
2. After adding the document in Firebase Console
3. Check Xcode console - you should see:
   ```
   ✅ Fetched 1 documents for project: TestMrunal
   📋 Processing document: xyz123
      Data: [documentName: Test Document, ...]
   📋 Document: Test Document | Folder: MOMs
   📊 Total documents loaded: 1
   📊 MOMs: 1 | Daily Reports: 0
   ```
4. The document should appear **instantly** in the app!

## Common Issues & Solutions

### Issue 1: Document Not Appearing
**Cause**: Wrong `projectId`
**Solution**: 
- Make sure the `projectId` in Firebase exactly matches the project's `documentId`
- Check console logs for the correct Project ID

### Issue 2: "No documents found"
**Cause**: Empty or null `projectId`
**Solution**:
- Ensure the project has a valid `documentId`
- Check if the project was created properly

### Issue 3: Document appears but in wrong section
**Cause**: Wrong `folderType` value
**Solution**:
- Use exactly "MOMs" or "Daily Report" (case-sensitive)
- Check for extra spaces

## Example Document (JSON format)

```json
{
  "documentName": "Test MOM Document",
  "folderName": "MOMs",
  "folderType": "MOMs",
  "projectId": "1766828953419",
  "projectName": "TestMrunal",
  "uploadedBy": "admin@example.com",
  "uploadedAt": "2026-01-05T05:30:00Z",
  "fileName": "meeting_notes.pdf",
  "fileURL": ""
}
```

## Testing Checklist

- [ ] Project ID copied correctly
- [ ] All required fields added
- [ ] `folderType` is exactly "MOMs" or "Daily Report"
- [ ] `projectId` matches the project's document ID
- [ ] App is open on the project screen
- [ ] Console logs show document being fetched
- [ ] Document appears in the correct section

## Real-Time Updates

The system uses Firebase's real-time listeners, so:
- ✅ No need to refresh the app
- ✅ No need to restart
- ✅ Changes appear **instantly**
- ✅ Works from both app and Firebase Console

## Debug Commands

If documents still don't appear, check these console logs:

1. **Listener Setup**:
   ```
   📄 Setting up real-time listener for project: [ProjectName]
   📄 Project ID: [ID]
   ```

2. **Document Fetch**:
   ```
   ✅ Fetched X documents for project: [ProjectName]
   ```

3. **Document Processing**:
   ```
   📋 Document: [Name] | Folder: [Type]
   ```

4. **Final Count**:
   ```
   📊 Total documents loaded: X
   📊 MOMs: X | Daily Reports: X
   ```

If any of these logs are missing, there's an issue with that step!
