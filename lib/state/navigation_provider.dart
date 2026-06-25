import 'package:flutter/foundation.dart';

/// Lets a screen pushed on top of [HomeShell] (e.g. the Quran reading
/// page's own embedded bottom-tab bar) switch which main tab is selected
/// without holding a reference to [HomeShell] itself — it just updates
/// [index] here and pops its own route; [HomeShell] watches this provider
/// and shows the requested tab as soon as the pop reveals it again.
class HomeNavigationProvider extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void setIndex(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }
}
