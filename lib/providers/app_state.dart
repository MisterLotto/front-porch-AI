import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  // Placeholder for global app state
  bool _darkMode = true;
  bool get darkMode => _darkMode;

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void toggleTheme() {
    _darkMode = !_darkMode;
    notifyListeners();
  }
}
