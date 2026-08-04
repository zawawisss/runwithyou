import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class ProfileState {
  final String name;
  final int stepGoal;

  ProfileState({
    required this.name,
    required this.stepGoal,
  });

  ProfileState copyWith({
    String? name,
    int? stepGoal,
  }) {
    return ProfileState(
      name: name ?? this.name,
      stepGoal: stepGoal ?? this.stepGoal,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  late final Box _box;
  static const _nameKey = 'profile_name';
  static const _goalKey = 'step_goal';

  @override
  ProfileState build() {
    _box = Hive.box('settings_box');
    final name = _box.get(_nameKey, defaultValue: '') as String;
    final stepGoal = _box.get(_goalKey, defaultValue: 8000) as int;
    return ProfileState(name: name, stepGoal: stepGoal);
  }

  void updateProfile({String? name, int? stepGoal}) {
    final updated = state.copyWith(name: name, stepGoal: stepGoal);
    state = updated;
    if (name != null) {
      _box.put(_nameKey, name);
    }
    if (stepGoal != null) {
      _box.put(_goalKey, stepGoal);
    }
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);
