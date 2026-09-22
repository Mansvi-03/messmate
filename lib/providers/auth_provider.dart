import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/student.dart';
import '../models/manager.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService =
  FirestoreService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  bool get isLoggedIn => _user != null;

  Future<bool> login(
      String email,
      String password,
      ) async {
    _setLoading(true);

    try {
      final credential = await _authService.login(
        email,
        password,
      );

      _user = credential.user;
      _errorMessage = null;

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Login failed';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> registerStudent(
      Student student,
      String password,
      ) async {
    _setLoading(true);

    try {
      final credential =
      await _authService.register(
        student.email,
        password,
      );

      final user = credential.user;

      if (user == null) {
        _errorMessage = 'Registration failed';
        _setLoading(false);
        return false;
      }

      final studentData = Student(
        id: user.uid,
        name: student.name,
        email: student.email,
        contactNumber: student.contactNumber,
        college: student.college,
        hostel: student.hostel,
      );

      await _firestoreService.add(
        'students',
        user.uid,
        studentData.toMap(),
      );

      _user = user;
      _errorMessage = null;

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage =
          e.message ?? 'Student registration failed';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> registerManager(
      Manager manager,
      String password,
      ) async {
    _setLoading(true);

    try {
      final credential =
      await _authService.register(
        manager.email,
        password,
      );

      final user = credential.user;

      if (user == null) {
        _errorMessage = 'Registration failed';
        _setLoading(false);
        return false;
      }

      final managerData = Manager(
        id: user.uid,
        name: manager.name,
        email: manager.email,
        contactNumber: manager.contactNumber,
      );

      await _firestoreService.add(
        'managers',
        user.uid,
        managerData.toMap(),
      );

      _user = user;
      _errorMessage = null;

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage =
          e.message ?? 'Manager registration failed';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong';
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();

    _user = null;
    _errorMessage = null;

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}