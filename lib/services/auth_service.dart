import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> register(
      String email,
      String password,
      ) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> login(
      String email,
      String password,
      ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? get currentUser {
    return _auth.currentUser;
  }

  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  /// Creates a student Firebase Auth account on behalf of the manager
  /// without logging out or altering the manager's active auth session.
  Future<String> createStudentAccount({
    required String email,
    required String password,
  }) async {
    final String appName = 'StudentCreation_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'null-uid',
          message: 'Failed to create student account.',
        );
      }

      await secondaryAuth.signOut();
      return uid;
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }
}