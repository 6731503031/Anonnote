# Firebase Architecture Diagram & Flow
**Visual Guide to Your App's Firebase Integration**

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Presentation Layer                    │  │
│  │  ┌─────────────┐  ┌────────────────┐  ┌──────────────┐   │  │
│  │  │ Home Screen │  │ Create Screen  │  │Settings/etc  │   │  │
│  │  └─────────────┘  └────────────────┘  └──────────────┘   │  │
│  └────────────┬───────────────────────────────────────────┬───┘  │
│               │                                           │       │
│  ┌────────────▼─────────────────────────────────────────▼──────┐│
│  │              Business Logic Layer (Services)               ││
│  │                                                            ││
│  │  ┌──────────────────┐        ┌──────────────────────┐   ││
│  │  │  AuthService     │        │   NoteService        │   ││
│  │  │  (Singleton)     │        │   (Firestore CRUD)   │   ││
│  │  │                  │        │                      │   ││
│  │  │ • signInAnon()   │        │ • createNote()       │   ││
│  │  │ • currentUser    │        │ • getNotesForUser()  │   ││
│  │  │ • error handling │        │ • updateNote()       │   ││
│  │  └────────┬─────────┘        │ • deleteNote()       │   ││
│  │           │                  │ • userId filtering   │   ││
│  │           │                  └────────┬─────────────┘   ││
│  │           │                           │                 ││
│  │           └────────────────────────────┘                 ││
│  └──────────────────────┬──────────────────────────────────┘│
│                         │                                   │
│  ┌──────────────────────▼──────────────────────────────┐   │
│  │         State Management Layer                      │   │
│  │                                                    │   │
│  │  • SharedPreferences (theme, locale)              │   │
│  │  • Firebase Auth (currentUser)                    │   │
│  │  • Firestore Streams (notes real-time)           │   │
│  └──────────────────────┬──────────────────────────────┘   │
└─────────────────────────┼──────────────────────────────────┘
                          │
                          │ (Internet / Network)
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────▼──────┐    ┌─────▼─────┐     ┌───▼──────┐
   │ Firebase  │    │ Firestore │     │ Storage  │
   │   Auth    │    │ Database  │     │ (Future) │
   └───────────┘    └───────────┘     └──────────┘
        │                 │
   ┌────▼──────────────────▼─────────────────────┐
   │  anonnote-47650 Firebase Project            │
   │                                             │
   │  • Authentication: Anonymous               │
   │  • Database: Firestore (/notes collection) │
   │  • Security Rules: Owner-only access       │
   │  • Platforms: Web, Android, iOS, macOS     │
   └─────────────────────────────────────────────┘
```

---

## 2. Data Flow Diagram

### Creating a Note (Write Flow)

```
User Types Note
      │
      ▼
┌─────────────────────┐
│  CreateNoteScreen   │
└──────────┬──────────┘
           │
           ▼
    ┌──────────────┐
    │ _saveNote()  │
    └──────┬───────┘
           │
           ▼
  ┌────────────────────────┐
  │ 1. Get current UID     │
  │    from AuthService    │
  └────────┬───────────────┘
           │
           ▼
  ┌────────────────────────────────────┐
  │ 2. Create NoteModel with:          │
  │    • title                         │
  │    • tags                          │
  │    • content (Quill delta)         │
  │    • userId (from auth)            │
  └────────┬───────────────────────────┘
           │
           ▼
  ┌────────────────────────────────────┐
  │ 3. Call note_service.createNote()  │
  └────────┬───────────────────────────┘
           │
           ▼
  ┌────────────────────────────────────┐
  │ 4. Firestore _collection.add()     │
  │    • Adds document                 │
  │    • Sets createdAt (server-side)  │
  │    • With userId field             │
  └────────┬───────────────────────────┘
           │
           ▼
  ┌────────────────────────────────────┐
  │ 5. Firestore Rules Check:          │
  │    allow create: if                │
  │      auth != null &&               │
  │      userId == auth.uid ✅ PASS    │
  └────────┬───────────────────────────┘
           │
           ▼
  ┌────────────────────────────────────┐
  │ 6. Document saved to:              │
  │    /notes/{docId}                  │
  │    with: userId, title, tags,      │
  │          content, createdAt        │
  └────────┬───────────────────────────┘
           │
           ▼
  ┌────────────────────────────────────┐
  │ 7. Return to HomeScreen            │
  │ Note appears in user's list        │
  └────────────────────────────────────┘
```

### Reading Notes (Read Flow)

```
User Opens App → HomeScreen
      │
      ▼
┌──────────────────────────────┐
│ StreamBuilder fetches notes  │
│ from NoteService             │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────────────────────┐
│ getNotesForCurrentUser():                    │
│ 1. Get currentUser UID from AuthService     │
│ 2. Query: .where('userId', isEqualTo: uid) │
│ 3. .orderBy('createdAt', descending)       │
│ 4. .snapshots() (real-time stream)         │
└──────────┬───────────────────────────────────┘
           │
           ▼
┌────────────────────────────────┐
│ Firestore Rules Check:          │
│ allow list: if auth != null     │
│ (per-doc filtering on get)  ✅  │
└──────────┬─────────────────────┘
           │
           ▼
┌────────────────────────────────┐
│ Results filtered by rule:       │
│ Only docs where userId ==       │
│ auth.uid are returned       ✅  │
└──────────┬─────────────────────┘
           │
           ▼
┌────────────────────────────────┐
│ StreamMap to NoteModel objects │
└──────────┬─────────────────────┘
           │
           ▼
┌────────────────────────────────┐
│ Display in GridView             │
│ • Show previews                │
│ • Show tags                    │
│ • Show dates                   │
└────────────────────────────────┘
```

### Updating a Note (Update Flow)

```
User Edits Note → DetailScreen
      │
      ▼
┌──────────────────────┐
│ EditNoteScreen       │
│ (or edit in detail)  │
└──────────┬───────────┘
           │
           ▼
    ┌──────────────────┐
    │ Call updateNote()│
    └────────┬─────────┘
             │
             ▼
┌─────────────────────────────────┐
│ Firestore _collection.update(): │
│ • Uses .update() NOT .set()     │
│ • Only updates:                 │
│   - title                       │
│   - tags                        │
│   - content                     │
│ • Does NOT change:              │
│   - userId (preserved!)         │
│   - createdAt (preserved!)      │
└────────┬────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Firestore Rules Check:              │
│ allow update: if                    │
│   auth != null &&                  │
│   userId == auth.uid &&            │
│   (no userId/createdAt changes) ✅ │
└────────┬───────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Document updated with new content  │
│ Original userId & createdAt kept   │
└────────────────────────────────────┘
```

### Deleting a Note (Delete Flow)

```
User Deletes Note
      │
      ▼
┌────────────────────────┐
│ Show confirmation      │
│ "Are you sure?"        │
└────────┬───────────────┘
         │ (if confirmed)
         ▼
┌────────────────────────┐
│ deleteNote(docId)      │
└────────┬───────────────┘
         │
         ▼
┌────────────────────────────┐
│ Firestore delete:          │
│ _collection.doc(id).delete()
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Firestore Rules Check:              │
│ allow delete: if                    │
│   auth != null &&                  │
│   userId == auth.uid ✅ PASS       │
└────────┬───────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│ Document deleted from Firestore    │
│ Removed from user's note list      │
└────────────────────────────────────┘
```

---

## 3. Security Rules Flow

```
┌──────────────────────────────────────────────────────────┐
│ User A logs in (Anonymous)                              │
│ → Firebase creates unique UID: user_a_uid_12345       │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│ User A creates a note                                   │
│ • Calls: createNote(note, userId: user_a_uid_12345)   │
│ • Firestore receives: {                                 │
│     userId: "user_a_uid_12345",                        │
│     title: "My Secret",                                │
│     content: [...],                                     │
│     createdAt: server_timestamp                        │
│   }                                                     │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│ Firestore Rules Engine Checks:                          │
│                                                         │
│ ✅ Is user authenticated?                              │
│    → request.auth != null                              │
│    → YES (they're signed in)                          │
│                                                         │
│ ✅ Does userId in note match auth UID?                │
│    → request.resource.data.userId                     │
│    → == request.auth.uid                              │
│    → "user_a_uid_12345" == "user_a_uid_12345"        │
│    → YES! ✅                                           │
│                                                         │
│ RESULT: Document CREATED ✅                           │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│ Now User B (different device) tries to hack            │
│ → Firebase creates unique UID: user_b_uid_67890       │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│ User B tries to read User A's note:                     │
│ • Query: /notes/doc_id_of_user_a_note                 │
│ • Firestore receives GET request                       │
│ • User B's auth.uid: "user_b_uid_67890"              │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│ Firestore Rules Engine Checks:                          │
│                                                         │
│ ✅ Is User B authenticated?                            │
│    → request.auth != null                              │
│    → YES (they're signed in)                          │
│                                                         │
│ ❌ Does stored userId match User B's auth.uid?        │
│    → resource.data.userId (user_a_uid_12345)         │
│    → == request.auth.uid (user_b_uid_67890)          │
│    → "user_a_uid_12345" != "user_b_uid_67890"       │
│    → NO! ❌                                            │
│                                                         │
│ RESULT: READ DENIED ❌                                │
│ User B sees: "Permission denied"                      │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Authentication Flow

```
┌─────────────────────────────────────────┐
│ App Starts                              │
│ main() called                           │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ 1. Initialize Firebase                  │
│    Firebase.initializeApp(...)          │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ 2. Check if user already signed in      │
│    authService.currentUser               │
└────────────┬────────────────────────────┘
             │
      ┌──────┴──────┐
      │             │
   YES│             │NO
      ▼             ▼
┌─────────────┐  ┌─────────────────────────────┐
│ Use existing│  │ Sign in anonymously         │
│ UID         │  │ authService.signInAnon()    │
└─────────────┘  └────────────┬────────────────┘
      │                       │
      │                       ▼
      │          ┌──────────────────────────┐
      │          │ Firebase creates new:    │
      │          │ • Anonymous account      │
      │          │ • Unique UID             │
      │          │ • No email/password      │
      │          │ • Can't be deleted user-side
      │          └────────────┬─────────────┘
      │                       │
      └───────────┬───────────┘
                  │
                  ▼
        ┌──────────────────────┐
        │ UID available        │
        │ (AuthService.instance
        │  .currentUser?.uid)  │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ Build HomeScreen     │
        │ with notes query     │
        │ filtered by UID      │
        └──────────────────────┘
```

---

## 5. Real-Time Updates Flow

```
App starts listening to notes
      │
      ▼
┌────────────────────────────────────┐
│ StreamBuilder in HomeScreen        │
│ stream: getNotesForCurrentUser()   │
└────────────┬─────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│ Firestore starts streaming:        │
│ • Query: .snapshots()              │
│ • Listen for: /notes collection    │
│ • Filter: userId == currentUser    │
└────────────┬─────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│ Changes detected:                  │
│ • New document added               │
│ • Document modified                │
│ • Document deleted                 │
│ • Sort order changed               │
└────────────┬─────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│ Emit new QuerySnapshot with        │
│ updated list of documents          │
└────────────┬─────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│ StreamBuilder rebuilds UI with     │
│ new data (no manual refresh!)      │
└────────────────────────────────────┘
```

---

## 6. Error Handling Flow

```
Try to save note
      │
      ▼
   ┌──────────────────┐
   │ Network error?   │
   └────┬─────────┬───┘
        │ NO      │ YES
        ▼         ▼
   ┌────────┐  ┌──────────────────────┐
   │ Try    │  │ Show error message:  │
   │ saving │  │ "Network error."     │
   │        │  │ "Check connection."  │
   └────┬───┘  └──────────────────────┘
        │
        ▼
   ┌──────────────────┐
   │ Firestore error? │
   └────┬─────────┬───┘
        │ NO      │ YES
        ▼         ▼
   ┌────────┐  ┌────────────────────────────┐
   │ Save   │  │ Check error code:          │
   │ success│  │                            │
   └────┬───┘  │ permission-denied?         │
        │      │ → "Permission denied"      │
        │      │                            │
        │      │ unavailable?               │
        │      │ → "Service unavailable"    │
        │      │                            │
        │      │ other?                     │
        │      │ → "Please try again"       │
        │      └────────────┬────────────────┘
        │                   │
        ▼                   ▼
   ┌──────────────┐   ┌──────────────┐
   │ Return to    │   │ Show SnackBar│
   │ home, show   │   │ with message │
   │ new note     │   └──────────────┘
   └──────────────┘
```

---

## 7. Component Interaction Map

```
                    ┌────────────────────────────┐
                    │   HomeScreen (View)        │
                    │                            │
                    │ • StreamBuilder            │
                    │ • GridView of notes        │
                    │ • Search input             │
                    └────────┬───────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
   ┌──────────────────┐ ┌──────────────┐ ┌──────────────┐
   │ CreateNote       │ │ NoteDetail   │ │ Settings     │
   │ Screen           │ │ Screen       │ │ Screen       │
   └────────┬─────────┘ └──────┬───────┘ └──────┬───────┘
            │                  │                 │
            └──────────────────┼─────────────────┘
                               │
                               ▼
                    ┌────────────────────────┐
                    │  NoteService (CRUD)    │
                    │                        │
                    │ • createNote()         │
                    │ • getNotesForUser()    │
                    │ • updateNote()         │
                    │ • deleteNote()         │
                    └────────────┬───────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  AuthService (Auth)    │
                    │                        │
                    │ • currentUser          │
                    │ • signInAnon()         │
                    └────────────┬───────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
                    ▼            ▼            ▼
              ┌──────────┐ ┌──────────┐ ┌─────────────┐
              │FirebaseAuth
              │           │Firestore │ │Storage      │
              │(UID mgmt) │(Notes)   │ │(Future)     │
              └──────────┘ └──────────┘ └─────────────┘
```

---

## 8. Offline Support (Future Addition)

```
User goes offline
      │
      ▼
┌─────────────────────────────────┐
│ Firestore detects network down  │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ Enable local cache:             │
│ • Read from cache               │
│ • Queue writes locally          │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ App continues:                  │
│ • Show cached notes             │
│ • Allow create/edit (queued)    │
│ • Show "offline" indicator      │
└────────────┬────────────────────┘
             │
User comes back online
             │
             ▼
┌─────────────────────────────────┐
│ Firestore detects network       │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ Sync queued changes:            │
│ • Send pending creates          │
│ • Send pending updates          │
│ • Send pending deletes          │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ Receive server updates:         │
│ • Latest notes merged           │
│ • Conflicts resolved            │
│ • UI automatically updates      │
└─────────────────────────────────┘
```

---

## 9. Security Model Summary

```
┌─────────────────────────────────────────────────────┐
│ Anonnote Security Model                             │
└─────────────────────────────────────────────────────┘

Layer 1: Authentication
├─ Firebase Anonymous Auth
│  └─ Each user gets unique, permanent UID
│     (doesn't change across sessions)

Layer 2: Authorization (Firestore Rules)
├─ Every document has userId field
│  └─ Stores the document owner's UID
│
├─ CREATE rule:
│  └─ Only auth users can create
│  └─ Must set their own UID
│
├─ READ rule:
│  └─ Can only read own documents
│  └─ Query filters by UID automatically
│
├─ UPDATE rule:
│  └─ Can only update own documents
│  └─ Can't change userId or createdAt
│
└─ DELETE rule:
   └─ Can only delete own documents

Layer 3: Data Isolation
├─ All queries include: .where('userId', isEqualTo: uid)
│
├─ Prevents accidental access to other users' data
│
└─ Firestore rules double-check on server-side

Result: Bulletproof access control ✅
```

---

## 10. Code to Diagram Mapping

**See these files for the actual code implementing above diagrams:**

```
Architecture         → lib/features/ directory structure
Data Flow           → lib/features/notes/services/
Security            → firestore.rules file
Auth Flow           → lib/features/notes/services/auth_service.dart
CRUD Operations     → lib/features/notes/services/note_service.dart
UI Components       → lib/features/notes/screens/
Error Handling      → try-catch blocks throughout services
Real-Time Updates   → StreamBuilder in home_screen.dart
```

---

**These diagrams show how everything connects. Read them top-to-bottom during implementation!** 🎯
