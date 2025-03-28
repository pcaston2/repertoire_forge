import 'package:flutter/material.dart';
import 'package:repertoire_forge/task.dart';

class TaskBanner extends MaterialBanner {
  Task task;
  Row? row;

  TaskBanner.init(this.task, {super.key, required super.content, required super.actions, super.backgroundColor});

  factory TaskBanner(Task task, {VoidCallback? callback = null}) {
    Color? color;
    Column? column;
    String actionText = "Dismiss";
    Text count = Text("Count: ${task.processedItems}" + (task.totalItems == null ? "" : "/${task.totalItems!}"));
    switch (task.state) {
      case TaskState.error:
        color = Colors.redAccent;
        column = Column(children: [
          Text(task.name),
          Text("Error: ${task.exception.toString()}"),
          count,
        ]);
        break;
      case TaskState.cancelled:
        column = Column(children: [
          Text(task.name),
          const Text("Cancelled"),
          count,
        ]);
        color = Colors.amberAccent;
        break;
      case TaskState.done:
        color = Colors.greenAccent;
        column = Column(children: [
          Text(task.name),
          const Text("Done"),
          count,
        ]);
      default:
        color = null;
        column = Column(children: [
          Text(task.name),
          LinearProgressIndicator(value: task.progress),
          count,
        ]);
        actionText = "Cancel";
    }
    TextButton action = TextButton(
      child: Text(actionText),
      onPressed: (task.state == TaskState.running ? () => task.cancel() : callback),
    );
    return TaskBanner.init(task, content: column, actions: [action], backgroundColor: color);
  }
}