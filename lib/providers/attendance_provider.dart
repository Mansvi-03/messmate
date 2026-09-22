import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../services/firestore_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final FirestoreService _firestoreService =
  FirestoreService();

  List<Attendance> _attendance = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<Attendance> get attendance => _attendance;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<bool> markAttendance(
      Attendance attendance,
      ) async {
    _setLoading(true);

    try {
      await _firestoreService.add(
        'attendance',
        attendance.id,
        attendance.toMap(),
      );

      final index = _attendance.indexWhere(
            (item) => item.id == attendance.id,
      );

      if (index >= 0) {
        _attendance[index] = attendance;
      } else {
        _attendance.add(attendance);
      }

      _errorMessage = null;

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage =
      'Unable to save attendance';

      _setLoading(false);
      return false;
    }
  }

  Future<void> loadAttendance(
      String attendanceId,
      ) async {
    _setLoading(true);

    try {
      final data = await _firestoreService.get(
        'attendance',
        attendanceId,
      );

      if (data != null) {
        final attendance = Attendance.fromMap(
          data,
          attendanceId,
        );

        _attendance = [attendance];
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage =
      'Unable to load attendance';
    }

    _setLoading(false);
  }

  void clearAttendance() {
    _attendance = [];
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}