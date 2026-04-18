# Anonnote: Security, Code Quality & Privacy Analysis

**Date:** March 27, 2026  
**Project:** Anonnote (Flutter + Firebase/Firestore)  
**Scope:** Full codebase analysis for code quality, security, and privacy

---

## 1. CODE REVIEW: Maintainability & Quality Issues

### Issue #1: Content Extraction Logic Duplicated Across Multiple Locations

**Location:** `lib/features/notes/screens/home_screen.dart` (lines 21–44) + `lib/features/notes/models/note_model.dart` (implied usage)

**Description:**  
The `_previewForContent()` method in `HomeScreen` manually parses Quill delta JSON (List of operation objects) to extract plain text. The same logic is duplicated implicitly when notes are displayed in the detail screen or when converting content for preview. The method:
- Iterates through a List and extracts `insert` field values
- Handles both Map and String types
- Truncates to 300 characters manually

**Why It's a Problem:**
- **Code Duplication:** If Quill format changes or a bug is found, multiple locations must be updated.
- **Maintenance Burden:** Any new screen that needs previews must re-implement the logic.
- **Testing Difficulty:** The same parsing logic is tested in multiple places (if at all).
- **Brittle Format Handling:** No centralized validation of the delta structure.

**Suggested Improvement:**
```dart
// Move to NoteModel as a utility method
extension QuillContentUtils on NoteModel {
  String getPlainTextPreview({int maxChars = 300}) {
    // Centralized extraction logic
    if (content is List) {
      final buffer = StringBuffer();
      for (final op in content) {
        if (op is Map && op.containsKey('insert')) {
          final ins = op['insert'];
          if (ins is String) buffer.write(ins);
        } else if (op is String) {
          buffer.write(op);
        }
        if (buffer.length > maxChars) break;
      }
      final text = buffer.toString().replaceAll('\n', ' ').trim();
      return text.length > maxChars 
          ? '${text.substring(0, maxChars)}…' 
          : text;
    }
    if (content is String) {
      final text = (content as String).replaceAll('\n', ' ').trim();
      return text.length > maxChars 
          ? '${text.substring(0, maxChars)}…' 
          : text;
    }
    return '';
  }
}

// Then in HomeScreen:
final notes = data.where((n) {
  final preview = n.getPlainTextPreview();
  final matchesQuery = _query.isEmpty || 
      n.title.toLowerCase().contains(_query.toLowerCase()) ||
      preview.toLowerCase().contains(_query.toLowerCase()) ||
      n.tags.any((tag) => tag.toLowerCase().contains(_query.toLowerCase()));
  // ... rest of filtering
}).toList();
```

---

### Issue #2: Service Instantiation in Every Build (HomeScreen)

**Location:** `lib/features/notes/screens/home_screen.dart` (line 47)

**Code:**
```dart
@override
Widget build(BuildContext context) {
  final service = NoteService();  // ← Created on every rebuild
  final t = AppLocalizations.of(context)!;
```

**Description:**  
`NoteService` is instantiated fresh inside the `build()` method. While the service itself is lightweight (it only holds a lazy reference to Firestore), this violates the principle of not doing expensive work in build methods and creates multiple object instances unnecessarily.

**Why It's a Problem:**
- **Performance:** Although minimal overhead in this case, it's a code smell that indicates the service isn't properly scoped.
- **State Management Smell:** If the service later needs state, multiple instances could cause inconsistencies.
- **Unnecessary GC Pressure:** Objects created and discarded during rebuilds add pressure to the garbage collector.
- **Bad Pattern:** Teaches readers that it's acceptable to instantiate services on each render.

**Suggested Improvement:**
```dart
class _HomeScreenState extends State<HomeScreen> {
  late final NoteService _service = NoteService();
  String _query = '';
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    // Use _service throughout, not instantiating it in build()
    return Scaffold(
      body: StreamBuilder<List<NoteModel>>(
        stream: _service.getNotesForCurrentUser(),
        // ...
```

---

### Issue #3: Mixed Responsibilities: Auth UID Display in Settings Screen

**Location:** `lib/features/settings/settings_screen.dart` (lines 115–130)

**Description:**  
The `SettingsScreen` is responsible for:
1. **UI:** Language and theme selection.
2. **State Management:** Updating app-level locale/theme via `appKey.currentState`.
3. **Authentication:** Displaying current auth UID and offering a manual re-auth button (`_refreshAuthUid()`).

The auth UID display is only shown in debug mode (`if (kDebugMode)`), but it creates a tight coupling between settings and auth concerns.

**Why It's a Problem:**
- **Single Responsibility Principle Violation:** A settings screen is for user preferences, not for auth debugging.
- **Cognitive Overload:** Developers maintain settings logic and auth logic in one place.
- **Testing Complexity:** Testing settings changes requires spinning up auth mocks.
- **UI Clutter:** Even if debug-only, it adds conditional branches to the build method.

**Suggested Improvement:**
```dart
// Create a separate debug panel file
// lib/widgets/debug_auth_panel.dart
class DebugAuthPanel extends StatefulWidget {
  // Extract the auth debug UI into its own widget
}

// In settings_screen.dart
if (kDebugMode) {
  const DebugAuthPanel(),
}
```

---

### Issue #4: Global App State Key (`appKey`) for Theme/Locale

**Location:** `lib/main.dart` (line 14) + `lib/features/settings/settings_screen.dart` (line 20)

**Code:**
```dart
// In main.dart
final GlobalKey<MyAppState> appKey = GlobalKey<MyAppState>();

// In settings_screen.dart
final state = appKey.currentState;
appKey.currentState?.setLocale(null);
```

**Description:**  
The app uses a global key to access `MyAppState` directly from anywhere in the widget tree (e.g., settings screen). This bypasses the normal widget communication patterns (e.g., InheritedWidget, Provider, Riverpod).

**Why It's a Problem:**
- **Tight Coupling:** Settings screen is tightly bound to the specific structure of MyApp.
- **Testing Complexity:** Tests must create a full widget tree with MyApp to test settings.
- **Hard to Refactor:** Changing MyApp structure requires changes throughout the codebase.
- **Non-Idiomatic:** Flutter best practices recommend InheritedWidget or state management libraries.

**Suggested Improvement:**
```dart
// Create an inherited widget for app state
class AppStateInheritedWidget extends InheritedWidget {
  final MyAppState appState;

  const AppStateInheritedWidget({
    required this.appState,
    required super.child,
  });

  static MyAppState of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<AppStateInheritedWidget>();
    assert(widget != null, 'AppStateInheritedWidget not found in context');
    return widget!.appState;
  }

  @override
  bool updateShouldNotify(AppStateInheritedWidget old) {
    return appState.themeMode != old.appState.themeMode ||
           appState.locale != old.appState.locale;
  }
}

// In MyApp, wrap the home:
return AppStateInheritedWidget(
  appState: this,
  child: MaterialApp(
    // ...
    home: const HomeScreen(),
  ),
);

// In settings_screen.dart:
final appState = AppStateInheritedWidget.of(context);
appState.setLocale(newLocale);
```

---

### Issue #5: Unvalidated Dynamic Content Type in NoteModel

**Location:** `lib/features/notes/models/note_model.dart` (line 7)

**Code:**
```dart
class NoteModel {
  final String id;
  final String title;
  final List<String> tags;
  final dynamic content;  // ← Can be anything
  final DateTime createdAt;
```

**Description:**  
The `content` field accepts `dynamic`, meaning it can hold:
- A `List` (Quill delta JSON)
- A `String` (plain text)
- An `int`, `bool`, `null`, or any other type

This flexibility is intentional (to support both rich-text and plain-text notes), but it creates runtime surprises:
- The `fromMap()` factory doesn't validate the content structure.
- Code that consumes `content` must defensively check its type (e.g., `if (content is List)`).
- Typos or corrupted Firestore documents can introduce invalid types.

**Why It's a Problem:**
- **Runtime Failures:** If content arrives as a Map instead of List, `_previewForContent()` returns an empty string silently.
- **Type Confusion:** Developers must remember to check types everywhere content is used.
- **Firestore Corruption Risk:** A manual edit or a bug in `createNote()` could write a Map when a List is expected.
- **Poor Error Visibility:** No validation happens at the model layer; errors surface in the UI late.

**Suggested Improvement:**
```dart
class NoteModel {
  final String id;
  final String title;
  final List<String> tags;
  final NoteContent content;  // ← Type-safe wrapper
  final DateTime createdAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.tags,
    required this.content,
    required this.createdAt,
  });

  factory NoteModel.fromMap(Map<String, dynamic> map, String id) {
    // Validate and type-check content
    final rawContent = map['content'];
    final content = NoteContent.fromDynamic(rawContent);
    if (content == null) {
      throw FormatException('Invalid note content: $rawContent');
    }
    return NoteModel(
      id: id,
      title: map['title'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      content: content,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

abstract class NoteContent {
  static NoteContent? fromDynamic(dynamic value) {
    if (value is List) return QuillDeltaContent(value);
    if (value is String) return PlainTextContent(value);
    return null; // Invalid type
  }
}

class QuillDeltaContent implements NoteContent {
  final List<dynamic> ops;
  QuillDeltaContent(this.ops);
}

class PlainTextContent implements NoteContent {
  final String text;
  PlainTextContent(this.text);
}
```

---

## 2. SECURITY ANALYSIS

### Security Issue #1: Hardcoded Firebase API Key in Source Code (Critical)

**Location:** `lib/firebase_options.dart` (lines 42–50)

**Code:**
```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyC-xiFGjR5w-cpUIcJV2x31FMishGp88YA',  // ← EXPOSED
  appId: '1:375833053628:web:253c27ee15e84b33fbc3b9',
  messagingSenderId: '375833053628',
  projectId: 'anonnote-47650',
  authDomain: 'anonnote-47650.firebaseapp.com',
  storageBucket: 'anonnote-47650.firebasestorage.app',
  measurementId: 'G-MQ0SCT2922',
);
```

**Description:**  
Firebase API keys are embedded as constants in the Dart source code. This file is:
1. **Compiled into the APK/IPA/app bundle** — extractable via decompilation.
2. **Visible in source repos** — anyone with repository access sees the keys.
3. **Visible in built web apps** — JavaScript source can be viewed in the browser.

**Risk Level:** **CRITICAL**

**Impact:**
- **API Key Abuse:** An attacker can make unauthorized Firebase API calls (Firestore reads, Auth operations) using this key.
- **Impersonation:** The attacker can perform any action the app can do (create/read/delete notes for any user with proper UID).
- **Quota Exhaustion:** The attacker can trigger expensive operations and deplete your Firebase quota/billing.
- **Data Breach:** With access to the project ID and key, the attacker can query the Firestore database if rules are misconfigured.

**Suggested Fix:**
Firebase API keys for web/mobile clients **are intended to be public** (they are not secrets like private keys). However, you **should:**

1. **Use Firebase Security Rules exclusively** to protect your data (which you've done correctly).
2. **Implement API Key Restrictions** in the Firebase Console:
   - Restrict the API key to:
     - **Application Restrictions:** HTTP Referrers for web (e.g., `anonnote-47650.web.app`)
     - **API Restrictions:** Only allow `firebaseauth.googleapis.com` and `firestore.googleapis.com`
3. **Monitor API Key Usage** via Cloud Logging to detect abuse.
4. **Rotate the key periodically** if you suspect compromise.

**Immediate Action (Firebase Console):**
```
1. Go to Firebase Console > Project Settings > API Keys
2. Click the web API key
3. Set:
   - Application restrictions: HTTP referrers → anonnote-47650.web.app
   - API restrictions: Select only Cloud Firestore API, Authentication API
```

---

### Security Issue #2: Insufficient Input Validation on Note Creation

**Location:** `lib/features/notes/screens/create_note_screen.dart` (lines 142–170)

**Code:**
```dart
void _saveNote() async {
  try {
    final tags = tagController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final contentJson = _controller.document.toDelta().toJson();

    final note = NoteModel(
      id: '',
      title: titleController.text.trim(),  // ← No length/content validation
      tags: tags,                          // ← No validation
      content: contentJson,
      createdAt: DateTime.now(),
    );
```

**Description:**
- **Title:** No checks for empty, excessively long, or malicious strings.
- **Tags:** No validation of tag count, length, or character set.
- **Content:** No size limit check (Quill delta JSON could be extremely large).

**Risk Level:** **MEDIUM**

**Impact:**
- **DoS via Large Payloads:** An attacker can create notes with multi-MB Quill delta to exhaust Firestore write quotas.
- **Data Pollution:** Extremely long titles or tags clutter the database and UI.
- **Unicode Exploits:** Special Unicode characters might cause rendering issues or injection attacks if content is later displayed in a web context.

**Suggested Fix:**
```dart
void _saveNote() async {
  try {
    // Validate title
    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showError('Title cannot be empty');
      return;
    }
    if (title.length > 200) {
      _showError('Title must be under 200 characters');
      return;
    }

    // Validate tags
    final tags = tagController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    if (tags.length > 10) {
      _showError('Maximum 10 tags allowed');
      return;
    }
    
    for (final tag in tags) {
      if (tag.length > 50) {
        _showError('Each tag must be under 50 characters');
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(tag)) {
        _showError('Tags can only contain letters, numbers, dashes, and underscores');
        return;
      }
    }

    // Validate content size
    final contentJson = _controller.document.toDelta().toJson();
    final contentString = jsonEncode(contentJson);
    const maxContentSizeBytes = 1024 * 1024; // 1 MB
    if (contentString.lengthInBytes > maxContentSizeBytes) {
      _showError('Note content is too large (max 1 MB)');
      return;
    }

    final note = NoteModel(
      id: '',
      title: title,
      tags: tags,
      content: contentJson,
      createdAt: DateTime.now(),
    );
    
    // ... rest of save logic
  } catch (e) {
    _showError('Failed to save note: $e');
  }
}

void _showError(String message) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
```

Additionally, add server-side validation in Firestore rules:
```firestore
function isValidNoteData(data) {
  return data.title is string
    && data.title.size() > 0
    && data.title.size() <= 200
    && data.tags is list
    && data.tags.size() <= 10
    && data.tags.join('').size() <= 500
    && data.content is list || data.content is string
    && data.content is string ? data.content.size() <= 1048576 : true;
}
```

---

### Security Issue #3: Firestore Rules Allow Excessive Data Exposure via List Query

**Location:** `firestore.rules` (lines 22–24)

**Code:**
```firestore
// Allow queries for signed-in users. Firestore evaluates per-document
// get rules during queries so users only receive docs they may read.
allow list: if request.auth != null;
```

**Description:**
The `list` rule allows any signed-in user to query the entire `/notes` collection. While the `get` rule enforces per-user ownership (users can only read their own notes), the `list` operation itself is unrestricted.

**Why It's Vulnerable:**
1. An authenticated attacker can perform a query like:
   ```firestore
   db.collection('notes').limit(100000).get()
   ```
2. Firestore **will evaluate the `get` rule per document**, but the attacker can:
   - **Count total notes** by using `.limit(N)` and observing how many documents are returned.
   - **Infer note creation patterns** (e.g., daily note counts, peak activity times).
   - **Exhaust quota** by repeatedly querying (each query is a read operation).

**Risk Level:** **MEDIUM**

**Impact:**
- **Metadata Leakage:** An attacker infers system-wide patterns (e.g., "the app has 10,000 notes total").
- **Quota Exhaustion:** Repeated list queries consume read operations and increase costs.
- **Timing Attacks:** Query response times leak information about database size.

**Suggested Fix:**
Restrict `list` queries to the user's own notes:

```firestore
// Allow list queries only for the user's own notes
// (Firestore doesn't support restricting the collection, but we can enforce this)
allow list: if request.auth != null
  && request.query.where.userId == request.auth.uid;
```

**Note:** Firestore doesn't have true query enforcement (you can't prevent clients from calling `.limit()` or other operators), so the best approach is to:
1. **Document the constraint** in your app's query code.
2. **Always filter by userId** on the client side.
3. **Educate developers** that `getNotesForCurrentUser()` must always be used, never a bare `.collection('notes').get()`.

Current code does this correctly (`note_service.dart` lines 43–48), so this is more of a defense-in-depth recommendation.

---

## 3. PRIVACY & PDPA ANALYSIS

### Data Inventory

| Data Type | Collected | Necessary | Risk Level | PDPA Status | Suggested Action |
|-----------|-----------|-----------|------------|------------|-----------------|
| **User UID (Anonymous)** | Yes | Yes | Low | Acceptable | UID is not PII (anonymous). No action needed. |
| **Note Content (Text/Rich Text)** | Yes | Yes | Medium | Requires Encryption | Implement Firestore encryption at rest (Firebase handles this). Recommend TLS for transit (Firebase default). |
| **Note Metadata (Title, Tags, CreatedAt)** | Yes | Yes | Low | Acceptable | Metadata is user-generated and not sensitive. |
| **Theme Preference** | Yes | No | Low | Acceptable | Non-sensitive app preference. |
| **Locale Preference** | Yes | No | Low | Acceptable | Non-sensitive app preference (language selection). |
| **Note Edit History** | No | No | N/A | N/A | Not currently captured. Good. |
| **Auth Tokens / ID Tokens** | Yes | Yes | High | Requires Encryption | Firebase handles token encryption in transit (HTTPS enforced). Tokens are ephemeral and short-lived (Firebase default: 1 hour). No persistent storage. |
| **IP Address / Device Info** | Implicit | No | Medium | Requires Consent | Firebase logs may capture IPs in Cloud Logging. Ensure logging is configured minimally. |

---

### Data Collection Details

#### 1. **Anonymous User ID (UID)**
- **What:** Firestore UID from Firebase Authentication (anonymous).
- **Why Collected:** To segregate notes by user.
- **Necessary:** Yes.
- **PDPA Risk:** **Low** — Anonymous UID is not Personally Identifiable Information (PII). It doesn't identify a real person.
- **Action:** No action needed.

---

#### 2. **Note Content (User-Generated Text)**
- **What:** Rich-text notes created via Quill editor.
- **Why Collected:** Core app functionality.
- **Necessary:** Yes.
- **PDPA Risk:** **Medium** — Notes may contain personal/sensitive information (diary, passwords, etc.).
- **Safeguards:**
  - ✅ Firestore encrypts data at rest (Google-managed keys by default).
  - ✅ Firestore enforces HTTPS/TLS in transit.
  - ✅ Security rules enforce per-user access (no unauthorized reads).
  - ❌ Missing: End-to-end encryption (notes are decrypted server-side before storage).
  - ❌ Missing: User-controlled encryption keys (users cannot encrypt notes client-side).
- **Action:** 
  - Consider adding a client-side encryption layer (e.g., AES via `encrypt` package) if users store highly sensitive data.
  - Update privacy policy to state: *"Notes are encrypted at rest by Google Cloud. We recommend not storing highly sensitive information (e.g., passwords, credit card numbers) in notes."*

---

#### 3. **Note Metadata (Title, Tags, Creation Timestamp)**
- **What:** User-provided strings and server timestamps.
- **Why Collected:** For organization and sorting.
- **Necessary:** Yes.
- **PDPA Risk:** **Low** — Metadata is typically non-sensitive.
- **Action:** No action needed (covered by same Firestore encryption as content).

---

#### 4. **Theme & Locale Preferences**
- **What:** Stored in `shared_preferences` locally (not transmitted to server).
- **Why Collected:** To persist UI preferences.
- **Necessary:** No (the app would work with system defaults).
- **PDPA Risk:** **Low** — Non-sensitive app settings.
- **Action:** No action needed.

---

#### 5. **Auth Tokens & ID Tokens**
- **What:** Firebase ID tokens and refresh tokens.
- **Why Collected:** For authentication.
- **Necessary:** Yes.
- **PDPA Risk:** **High (in theory, but mitigated):**
  - ID tokens are short-lived (1 hour default).
  - Firebase doesn't persist tokens on disk by default (only in memory during session).
  - ✅ TLS/HTTPS enforces encrypted transit.
  - ❌ Risk: If device is compromised, attacker can steal in-memory tokens.
- **Action:**
  - Current setup is acceptable for anonymous auth.
  - If implementing named/email auth in the future, ensure tokens are never logged or exposed.
  - Document in privacy policy: *"Authentication tokens are managed securely by Firebase and not persisted to disk."*

---

#### 6. **IP Addresses & Device Information (Implicit)**
- **What:** Firestore and Firebase Authentication may log client IPs and device info.
- **Why Collected:** For audit, analytics, and abuse prevention.
- **Necessary:** Yes (for Firebase infrastructure).
- **PDPA Risk:** **Medium** — IP addresses can be considered quasi-identifiers.
- **Action:**
  - Ensure Firebase Cloud Logging is configured minimally (enable only if needed for debugging).
  - Review Firebase Console > Logs to ensure sensitive data isn't logged.
  - Update privacy policy: *"Firebase logs may capture IP addresses for security monitoring."*

---

### PDPA Compliance Recommendations

**Thailand's Personal Data Protection Act (PDPA) Requirements:**
1. **Informed Consent:** Users must consent to data collection before use.
   - Add a terms/privacy dialog on first launch.
2. **Data Minimization:** Only collect necessary data.
   - Current app is minimal. ✅
3. **Transparency:** Clearly state what data is collected and why.
   - Add a "Privacy Policy" link in the app (settings screen).
4. **Security:** Implement reasonable safeguards.
   - Firestore encryption: ✅
   - TLS/HTTPS: ✅
   - Access controls: ✅
5. **Retention:** Specify data retention period.
   - E.g., *"Notes are retained indefinitely until user deletion."*
6. **User Rights:** Allow users to request/delete their data.
   - Implement a "Delete All Notes" function in settings.

**Suggested Privacy Policy Text (Thai users):**
```
**ความเป็นส่วนตัว**

ข้อมูลที่เรารวบรวม:
- User ID (ไม่ระบุตัวตน)
- บันทึกของคุณ (ชื่อเรื่อง แท็ก เนื้อหา)
- ลักษณะการตั้งค่า (ภาษา มีมา)

ข้อมูลของคุณถูกเข้ารหัสลับและปกป้องโดยกฎ Firestore Security

คุณสามารถลบบันทึกทั้งหมดได้ตลอดเวลา
```

---

## 4. DECOMPILATION & SECRETS EXPOSURE ANALYSIS

### If a hacker decompiles the app, what can they extract?

#### **Easy to Extract:**
1. ✅ **Firebase API Key** (`AIzaSyC-xiFGjR5w-cpUIcJV2x31FMishGp88YA`)
   - Visible in strings table of APK/IPA.
   - Visible in Flutter web app's JavaScript.
   - **Risk:** Can make unauthorized Firestore queries (mitigated by Security Rules).

2. ✅ **Project ID** (`anonnote-47650`)
   - Visible in strings and Firebase configuration.
   - **Risk:** Attacker knows which Firebase project to target.

3. ✅ **Auth Domain** (`anonnote-47650.firebaseapp.com`)
   - Hardcoded in `firebase_options.dart`.
   - **Risk:** Low (it's meant to be public).

4. ✅ **App Logic**
   - All Dart source can be partially reconstructed from compiled APK (Dart VM bytecode is readable).
   - Note structure, Quill format usage, and Firestore paths are exposed.
   - **Risk:** Attacker understands app functionality.

5. ✅ **Hardcoded Strings**
   - Localization strings (English, Thai) are visible.
   - Error messages and UI text.
   - **Risk:** Low.

#### **Hard to Extract (Not Present):**
1. ❌ **Private Keys / Secrets** — None embedded (good!).
2. ❌ **Database Credentials** — Not in app (good; rules-based access).
3. ❌ **API Keys for 3rd-party services** — Not used.
4. ❌ **Hardcoded Passwords/Tokens** — None present (good!).

---

### Decompilation Mitigation Recommendations

1. **For Android:**
   - Enable **Proguard/R8 obfuscation** in `android/app/build.gradle.kts`:
     ```gradle
     buildTypes {
       release {
         minifyEnabled true
         shrinkResources true
         proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
       }
     }
     ```
   - This obscures class/method names but won't hide the Firebase API key (it's a string).

2. **For iOS:**
   - Xcode automatically strips symbols in release builds.
   - No additional obfuscation is standard practice (iOS apps are binary-native).

3. **For Web:**
   - Minify/uglify JavaScript (Flutter's `--release` flag does this).
   - API key is still visible in network requests (inherent to web).

4. **For All Platforms:**
   - ✅ Rely on **Firebase Security Rules** to prevent unauthorized access (already implemented).
   - ✅ Implement **API Key Restrictions** in Firebase Console (recommended above).
   - ✅ Use **Cloud Armor** if available to block suspicious traffic patterns.

---

## Summary & Recommendations

### Priority 1 (Do Now):
1. **Restrict Firebase API Key** in Console (HTTP referrers, API restrictions).
2. **Add input validation** to note creation (title, tag, content size limits).
3. **Move content extraction logic** to a shared utility method.

### Priority 2 (Do Soon):
1. Add a **Privacy Policy** to the app (required for PDPA compliance).
2. Implement **"Delete All Notes"** function in settings (user rights).
3. Replace **global `appKey`** with InheritedWidget pattern.
4. Extract **debug auth UI** into a separate widget.

### Priority 3 (Nice to Have):
1. Add **client-side encryption** for highly sensitive notes.
2. Implement **server-side validation** in Firestore rules (redundant but defense-in-depth).
3. Enable **Code Obfuscation** for Android builds.
4. Monitor **Firestore quota usage** to detect abuse.

---

**Report Generated:** March 27, 2026  
**Status:** Ready for academic submission
