import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/manager.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _userRole;

  User? get user => _user;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get userRole => _userRole;

  bool get isLoggedIn => _user != null;

  // =========================
  // LOGIN
  // =========================

  Future<bool> login(
      String email,
      String password,
      ) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _authService.login(
        email,
        password,
      );

      final user = credential.user;

      if (user == null) {
        _errorMessage = 'Login failed';
        _setLoading(false);
        return false;
      }

      _user = user;

      // Check Student collection
      final studentData = await _firestoreService.get(
        'students',
        user.uid,
      );

      if (studentData != null) {
        _userRole = 'student';

        _setLoading(false);
        return true;
      }

      // Check Manager collection
      final managerData = await _firestoreService.get(
        'managers',
        user.uid,
      );

      if (managerData != null) {
        _userRole = 'manager';

        _setLoading(false);
        return true;
      }

      // Authentication succeeded,
      // but no student/manager profile exists.
      await _authService.logout();

      _user = null;
      _userRole = null;
      _errorMessage = 'User profile not found';

      _setLoading(false);
      return false;
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

  // =========================
  // STUDENT REGISTRATION
  // =========================

  Future<bool> registerStudent(
      Student student,
      String password,
      ) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _authService.register(
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
      _userRole = 'student';
      _errorMessage = null;

      // Registration is complete.
      // Sign out so the user can login normally.
      await _authService.logout();

      _user = null;
      _userRole = null;

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

  // =========================
  // MANAGER REGISTRATION
  // =========================

  Future<bool> registerManager(
      Manager manager,
      String password,
      ) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _authService.register(
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
      _userRole = 'manager';
      _errorMessage = null;

      // Registration is complete.
      // Sign out so the user can login normally.
      await _authService.logout();

      _user = null;
      _userRole = null;

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

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
    await _authService.logout();

    _user = null;
    _userRole = null;
    _errorMessage = null;

    notifyListeners();
  }

  // =========================
  // LOADING
  // =========================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}