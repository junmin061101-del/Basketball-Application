// PLACEHOLDER — replace this entire file by running `flutterfire configure`
// in the project root once your Firebase project is set up. See the setup
// guide for the exact steps. The values below are not real and will not
// connect to any Firebase project; the app runs with Firebase features
// disabled until this file is regenerated.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform. '
          'Run `flutterfire configure` to generate real options.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDCfdYE79aerAt5cNsqE2yQy86HBTfttZM',
    appId: '1:85596612349:web:bec7563de7d9ae77cc0094',
    messagingSenderId: '85596612349',
    projectId: 'basket-it-kbl',
    authDomain: 'basket-it-kbl.firebaseapp.com',
    storageBucket: 'basket-it-kbl.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAnSull6Zt3cIx0OMLUqx_XAMkXPxnrtpM',
    appId: '1:85596612349:android:97c6b0f7d6e0bc69cc0094',
    messagingSenderId: '85596612349',
    projectId: 'basket-it-kbl',
    storageBucket: 'basket-it-kbl.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA29Ul4KVOoy8BzgwxHuHGCValoU7w1JKk',
    appId: '1:85596612349:ios:7e66d1bbb9521a82cc0094',
    messagingSenderId: '85596612349',
    projectId: 'basket-it-kbl',
    storageBucket: 'basket-it-kbl.firebasestorage.app',
    iosBundleId: 'com.basketit.basketIt',
  );
}
