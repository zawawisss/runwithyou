import 'package:flutter_riverpod/flutter_riverpod.dart';

class TabIndexNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  set state(int value) => super.state = value;
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);
