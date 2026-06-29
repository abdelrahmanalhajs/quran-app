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

  // Set when a notification tap (sleep athkar / jumu'ah sunan) needs to land
  // on a specific sub-tab inside [AthkarScreen], which owns its own
  // TabController and isn't otherwise reachable from outside. AthkarScreen
  // consumes and clears this in its build so it only fires once.
  int? _athkarTabRequest;
  int? get athkarTabRequest => _athkarTabRequest;

  void goToAthkarTab(int tabIndex) {
    _athkarTabRequest = tabIndex;
    _index = 2;
    notifyListeners();
  }

  void clearAthkarTabRequest() {
    _athkarTabRequest = null;
  }
}
