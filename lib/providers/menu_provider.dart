import 'package:flutter/foundation.dart';

import '../models/menu.dart';
import '../services/firestore_service.dart';

class MenuProvider extends ChangeNotifier {
  final FirestoreService _firestoreService =
  FirestoreService();

  Menu? _menu;
  bool _isLoading = false;
  String? _errorMessage;

  Menu? get menu => _menu;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<void> loadMenu(String menuId) async {
    _setLoading(true);

    try {
      final data = await _firestoreService.get(
        'menus',
        menuId,
      );

      if (data != null) {
        _menu = Menu.fromMap(data, menuId);
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Unable to load menu';
    }

    _setLoading(false);
  }

  Future<bool> addMenu(Menu menu) async {
    _setLoading(true);

    try {
      await _firestoreService.add(
        'menus',
        menu.id,
        menu.toMap(),
      );

      _menu = menu;
      _errorMessage = null;

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Unable to add menu';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateMenu(Menu menu) async {
    _setLoading(true);

    try {
      await _firestoreService.update(
        'menus',
        menu.id,
        menu.toMap(),
      );

      _menu = menu;
      _errorMessage = null;

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Unable to update menu';
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}