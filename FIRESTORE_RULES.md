# Firestore rules for Anonnote

This project includes an example `firestore.rules` file that enforces per-user
access for documents in the `notes` collection.

Key points:
- Only authenticated users (Firebase Auth) can create/read/update/delete notes.
- Each note document must include a `userId` field that equals the authenticated
  user's UID. This prevents users from reading or modifying other users' notes.

To deploy these rules to your Firebase project (from the project folder):

```bash
# make sure you're in the folder with firebase.json (or configure the project)
firebase deploy --only firestore:rules
```

If you use the Firestore emulator for local testing, you can point your app to
the emulator without deploying rules; however, for production the rules must be
deployed to the project that serves your app.
