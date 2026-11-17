// Firebase settings for Animal Book AR (project animal-book-ar).
// Made from android/app/google-services.json and ios/Runner/GoogleService-Info.plist.
// These identify the app to Firebase; they are not secrets (security comes
// from the Firestore rules in firestore.rules).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => ios,
        _ => android,
      };

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBKYOxNs6GarPPt6md4jUXZ6r9aN-Ty-cc',
    appId: '1:295967345525:android:270e1e8ed03efc9fada13c',
    messagingSenderId: '295967345525',
    projectId: 'animal-book-ar',
    storageBucket: 'animal-book-ar.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCONYK5dqN0AHCCg88f5ETu39wA7dPcsAs',
    appId: '1:295967345525:ios:9d9a2f0a682ebbebada13c',
    messagingSenderId: '295967345525',
    projectId: 'animal-book-ar',
    storageBucket: 'animal-book-ar.firebasestorage.app',
    iosClientId: '295967345525-aetr5836sa88rq1qg2fk4q1kbu13uh4a.apps.googleusercontent.com',
    iosBundleId: 'com.synapexa.animalBookAr',
  );

  /// The "web" OAuth client: Google sign-in needs it to get an ID token for Firebase.
  static const googleServerClientId = '295967345525-4ep8l3ap09qi95alvivp419hhsec4c7e.apps.googleusercontent.com';
}
