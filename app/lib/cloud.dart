import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'progress.dart';

/// Parent account (Firebase Authentication) and progress sync (Firestore).
///
/// Data: users/{uid}/children/{childId} = ChildData.toJson(). Each change on
/// this phone is written (debounced); changes from other devices arrive by a
/// live listener and are merged in (union of what was found, the larger of
/// each counter), so nothing a child earned is lost. Works offline: Firestore
/// keeps its own local cache and sends changes later.
class Cloud extends ChangeNotifier {
  Cloud._(this.progress);

  final Progress progress;
  User? user;
  bool syncing = false;
  String? lastError;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final _pending = <String, Timer>{};

  /// Null when Firebase can't start (e.g. in widget tests): the app then runs local-only.
  static Future<Cloud?> start(Progress progress) async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase not available: $e');
      return null;
    }
    final cloud = Cloud._(progress);
    progress.onChildChanged = cloud._queueWrite;
    progress.onChildDeleted = cloud._deleteRemote;
    FirebaseAuth.instance.authStateChanges().listen(cloud._onUser);
    return cloud;
  }

  CollectionReference<Map<String, dynamic>> get _children =>
      FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('children');

  // ---- sign in / out ----
  Future<void> signInWithGoogle() => _guard(() async {
        final google = GoogleSignIn(serverClientId: DefaultFirebaseOptions.googleServerClientId);
        final account = await google.signIn();
        if (account == null) return; // cancelled
        final auth = await account.authentication;
        await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: auth.idToken, accessToken: auth.accessToken),
        );
      });

  Future<void> signInWithEmail(String email, String password) =>
      _guard(() => FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password));

  Future<void> createAccount(String email, String password) =>
      _guard(() => FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password));

  Future<void> resetPassword(String email) =>
      _guard(() => FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() => _guard(() async {
        await _sub?.cancel();
        _sub = null;
        try {
          await GoogleSignIn().signOut();
        } catch (_) {}
        await FirebaseAuth.instance.signOut();
      });

  /// Runs an auth call; keeps a readable error for the parents' page.
  Future<void> _guard(Future<void> Function() call) async {
    lastError = null;
    notifyListeners();
    try {
      await call();
    } on FirebaseAuthException catch (e) {
      lastError = e.code; // shown translated by the parents' page
    } catch (e) {
      lastError = 'error';
      if (kDebugMode) debugPrint('auth error: $e');
    }
    notifyListeners();
  }

  // ---- sync ----
  Future<void> _onUser(User? u) async {
    user = u;
    await _sub?.cancel();
    _sub = null;
    notifyListeners();
    if (u == null) return;
    syncing = true;
    notifyListeners();
    try {
      // 1. Bring the account's children in, 2. send this phone's (merged) children up.
      final snap = await _children.get();
      final remoteIds = <String>{};
      for (final d in snap.docs) {
        remoteIds.add(d.id);
        progress.applyRemote(ChildData.fromJson(d.id, d.data()));
      }
      progress.dropEmptyLocalChildren(remoteIds);
      for (final c in progress.children) {
        await _children.doc(c.id).set(c.toJson());
      }
      // 3. Keep listening for changes from other devices.
      _sub = _children.snapshots().listen((s) {
        for (final ch in s.docChanges) {
          if (ch.type == DocumentChangeType.removed || ch.doc.metadata.hasPendingWrites) continue;
          final data = ch.doc.data();
          if (data != null) progress.applyRemote(ChildData.fromJson(ch.doc.id, data));
        }
      });
    } catch (e) {
      lastError = 'sync';
      if (kDebugMode) debugPrint('sync error: $e');
    }
    syncing = false;
    notifyListeners();
  }

  void _queueWrite(ChildData c) {
    if (user == null) return;
    _pending[c.id]?.cancel();
    _pending[c.id] = Timer(const Duration(milliseconds: 1500), () {
      _pending.remove(c.id);
      _children.doc(c.id).set(c.toJson()).catchError((Object e) {
        if (kDebugMode) debugPrint('write error: $e');
      });
    });
  }

  void _deleteRemote(String childId) {
    if (user == null) return;
    _children.doc(childId).delete().catchError((Object e) {
      if (kDebugMode) debugPrint('delete error: $e');
    });
  }
}
