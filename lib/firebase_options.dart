import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions wurden für diese Plattform nicht konfiguriert.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyChbKUjaMI3arh5MGMnINRBHefkY2TE3xA',
    appId: '1:71948872383:web:032f6775c45565c5cff40a',
    messagingSenderId: '71948872383',
    projectId: 'ideabamberg',
    authDomain: 'ideabamberg.firebaseapp.com',
    databaseURL: 'https://ideabamberg-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'ideabamberg.firebasestorage.app',
    measurementId: 'G-0M86XWT7H4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyChbKUjaMI3arh5MGMnINRBHefkY2TE3xA',
    appId: '1:71948872383:web:032f6775c45565c5cff40a',
    messagingSenderId: '71948872383',
    projectId: 'ideabamberg',
    databaseURL: 'https://ideabamberg-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'ideabamberg.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyChbKUjaMI3arh5MGMnINRBHefkY2TE3xA',
    appId: '1:71948872383:web:032f6775c45565c5cff40a',
    messagingSenderId: '71948872383',
    projectId: 'ideabamberg',
    databaseURL: 'https://ideabamberg-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'ideabamberg.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyChbKUjaMI3arh5MGMnINRBHefkY2TE3xA',
    appId: '1:71948872383:web:032f6775c45565c5cff40a',
    messagingSenderId: '71948872383',
    projectId: 'ideabamberg',
    databaseURL: 'https://ideabamberg-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'ideabamberg.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyChbKUjaMI3arh5MGMnINRBHefkY2TE3xA',
    appId: '1:71948872383:web:032f6775c45565c5cff40a',
    messagingSenderId: '71948872383',
    projectId: 'ideabamberg',
    databaseURL: 'https://ideabamberg-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'ideabamberg.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyChbKUjaMI3arh5MGMnINRBHefkY2TE3xA',
    appId: '1:71948872383:web:032f6775c45565c5cff40a',
    messagingSenderId: '71948872383',
    projectId: 'ideabamberg',
    databaseURL: 'https://ideabamberg-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'ideabamberg.firebasestorage.app',
  );
}