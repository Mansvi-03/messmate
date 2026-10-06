import 'package:flutter_test/flutter_test.dart';
import 'package:messmate/services/bill_calculator.dart';

void main() {
  group('BillCalculator (Student Meal Attendance and Bill)', () {
    test('Calculates exact bill according to example', () {
      final student = {
        'id': 'student_1',
        'name': 'Mansvi',
        'email': 'mansvi@example.com',
      };

      // 20 breakfasts at ₹40
      // 22 lunches at ₹60
      // 18 dinners at ₹50
      final List<Map<String, dynamic>> attendance = [];

      for (int i = 1; i <= 20; i++) {
        attendance.add({
          'id': 'att_b_$i',
          'studentId': 'student_1',
          'date': '2026-10-${i.toString().padLeft(2, '0')}',
          'meal': 'breakfast',
          'present': true,
          'price': 40.0,
          'menu': 'Coffee & Snack',
        });
      }

      for (int i = 1; i <= 22; i++) {
        attendance.add({
          'id': 'att_l_$i',
          'studentId': 'student_1',
          'date': '2026-10-${i.toString().padLeft(2, '0')}',
          'meal': 'lunch',
          'present': true,
          'price': 60.0,
          'menu': 'Dal, Rice, Roti',
        });
      }

      for (int i = 1; i <= 18; i++) {
        attendance.add({
          'id': 'att_d_$i',
          'studentId': 'student_1',
          'date': '2026-10-${i.toString().padLeft(2, '0')}',
          'meal': 'dinner',
          'present': true,
          'price': 50.0,
          'menu': 'Paneer & Roti',
        });
      }

      final summary = BillCalculator.calculateStudentBill(
        student: student,
        attendanceList: attendance,
        billsList: [],
        menusByDay: {},
        billingPeriod: '2026-10',
      );

      // Calculate Number of Meals
      expect(summary.breakfastCount, 20);
      expect(summary.lunchCount, 22);
      expect(summary.dinnerCount, 18);
      expect(summary.totalMeals, 60);

      // Calculate Student Bill
      expect(summary.breakfastTotal, 800.0);
      expect(summary.lunchTotal, 1320.0);
      expect(summary.dinnerTotal, 900.0);
      expect(summary.totalBill, 3020.0);
      expect(summary.status, 'unpaid');
    });

    test('Filters by selected billing period', () {
      final student = {
        'id': 'student_1',
        'name': 'Palak',
        'email': 'palak@example.com',
      };

      final attendance = [
        {
          'studentId': 'student_1',
          'date': '2026-09-29',
          'meal': 'lunch',
          'present': true,
          'price': 60.0,
          'menu': 'Lunch meal',
        },
        {
          'studentId': 'student_1',
          'date': '2026-10-04',
          'meal': 'dinner',
          'present': true,
          'price': 50.0,
          'menu': 'Dinner meal',
        },
      ];

      final octSummary = BillCalculator.calculateStudentBill(
        student: student,
        attendanceList: attendance,
        billsList: [],
        menusByDay: {},
        billingPeriod: '2026-10',
      );

      expect(octSummary.totalMeals, 1);
      expect(octSummary.dinnerCount, 1);
      expect(octSummary.totalBill, 50.0);

      final sepSummary = BillCalculator.calculateStudentBill(
        student: student,
        attendanceList: attendance,
        billsList: [],
        menusByDay: {},
        billingPeriod: '2026-09',
      );

      expect(sepSummary.totalMeals, 1);
      expect(sepSummary.lunchCount, 1);
      expect(sepSummary.totalBill, 60.0);

      final allSummary = BillCalculator.calculateStudentBill(
        student: student,
        attendanceList: attendance,
        billsList: [],
        menusByDay: {},
        billingPeriod: 'all',
      );

      expect(allSummary.totalMeals, 2);
      expect(allSummary.totalBill, 110.0);
    });

    test('Reflects paid status when bill record is paid', () {
      final student = {
        'id': 'student_1',
        'name': 'Krupa',
        'email': 'krupa@example.com',
      };

      final attendance = [
        {
          'studentId': 'student_1',
          'date': '2026-10-04',
          'meal': 'lunch',
          'present': true,
          'price': 80.0,
          'menu': 'Lunch',
        },
      ];

      final bills = [
        {
          'id': 'student_1_2026-10',
          'studentId': 'student_1',
          'period': '2026-10',
          'status': 'paid',
        },
      ];

      final summary = BillCalculator.calculateStudentBill(
        student: student,
        attendanceList: attendance,
        billsList: bills,
        menusByDay: {},
        billingPeriod: '2026-10',
      );

      expect(summary.status, 'paid');
      expect(summary.totalBill, 80.0);
    });
  });
}
