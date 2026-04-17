import '../models/session.dart';

/// SessionStateResolver — computes a [SessionPillState] from task completions.
abstract final class SessionStateResolver {
  static SessionPillState resolve(
      List<String> taskIds, Map<String, bool> taskStates) {
    if (taskIds.isEmpty) return SessionPillState.empty;
    final total = taskIds.length;
    final done = taskIds.where((id) => taskStates[id] == true).length;

    if (done == 0) return SessionPillState.empty;
    if (done < total / 2) return SessionPillState.started;
    if (done < total) return SessionPillState.halfway;
    return SessionPillState.complete;
  }
}
