import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/payment.dart';
import '../services/firestore_service.dart';

class BillProvider extends ChangeNotifier {
  final FirestoreService _firestoreService =
  FirestoreService();

  Bill? _bill;

  bool _isLoading = false;
  String? _errorMessage;

  Bill? get bill => _bill;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<bool> generateBill(Bill bill) async {
    _setLoading(true);

    try {
      await _firestoreService.add(
        'bills',
        bill.id,
        bill.toMap(),
      );

      _bill = bill;
      _errorMessage = null;

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage =
      'Unable to generate bill';

      _setLoading(false);
      return false;
    }
  }

  Future<void> loadBill(String billId) async {
    _setLoading(true);

    try {
      final data = await _firestoreService.get(
        'bills',
        billId,
      );

      if (data != null) {
        _bill = Bill.fromMap(
          data,
          billId,
        );
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Unable to load bill';
    }

    _setLoading(false);
  }

  Future<bool> recordPayment(
      Payment payment,
      ) async {
    _setLoading(true);

    try {
      await _firestoreService.add(
        'payments',
        payment.id,
        payment.toMap(),
      );

      if (_bill != null &&
          _bill!.id == payment.billId) {
        final newPaidAmount =
            _bill!.paidAmount + payment.amount;

        BillStatus newStatus;

        if (newPaidAmount >= _bill!.totalAmount) {
          newStatus = BillStatus.paid;
        } else if (newPaidAmount > 0) {
          newStatus = BillStatus.partial;
        } else {
          newStatus = BillStatus.unpaid;
        }

        final updatedBill = Bill(
          id: _bill!.id,
          studentId: _bill!.studentId,
          month: _bill!.month,
          breakfastAmount:
          _bill!.breakfastAmount,
          lunchAmount:
          _bill!.lunchAmount,
          dinnerAmount:
          _bill!.dinnerAmount,
          totalAmount:
          _bill!.totalAmount,
          paidAmount:
          newPaidAmount,
          status: newStatus,
        );

        await _firestoreService.update(
          'bills',
          updatedBill.id,
          updatedBill.toMap(),
        );

        _bill = updatedBill;
      }

      _errorMessage = null;

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage =
      'Unable to record payment';

      _setLoading(false);
      return false;
    }
  }

  void clearBill() {
    _bill = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}