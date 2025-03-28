import 'dart:ui';
import 'dart:math';

class Task<T> {
  Stream<T> stream;
  TaskState state = TaskState.stopped;
  int? totalItems;
  int processedItems = 0;
  String name;
  Exception? exception;
  Function(T)? callback;
  bool get success => state == TaskState.done;
  double? get progress => (totalItems == null ? null : (totalItems == 0 ? 0 : min(processedItems / totalItems!, 1)));
  Task(this.stream, {this.totalItems, this.name = "Unnamed Task", this.callback});

  start() async {
    if (state == TaskState.stopped) {
      state = TaskState.running;
      try {
        await for (var s in stream) {
          callback?.call(s);
          processedItems++;
          if (state == TaskState.cancelled) {
            return;
          }
        }
      } on Exception catch (ex) {
        exception = ex;
        state = TaskState.error;
        return;
      }
      state = TaskState.done;
    }
  }

  cancel() {
    if (state == TaskState.running || state == TaskState.stopped) {
      state = TaskState.cancelled;
    }
  }
}

enum TaskState {
  running,
  cancelled,
  stopped,
  error,
  done,
}