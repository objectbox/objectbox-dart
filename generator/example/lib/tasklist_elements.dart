import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';
import 'task_elements.dart';

/// Displays the current list of tasks by listening to a stream.
///
/// Each task has a check button to mark it completed and an edit button to
/// update it. A task can also be swiped away to remove it.
class TaskList extends StatefulWidget {
  const TaskList({super.key});

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  Dismissible Function(BuildContext, int) _itemBuilder(List<Task> tasks) =>
      (BuildContext context, int index) => Dismissible(
        background: Container(color: Colors.red),
        key: UniqueKey(), //Key('dismissed_$index'),
        onDismissed: (direction) {
          // Remove the task from the store.
          objectbox.removeTask(tasks[index].id);
          // List updated via watched query stream.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 0, right: 70, left: 70),
              padding: const EdgeInsets.all(5),
              duration: const Duration(milliseconds: 800),
              content: Container(
                alignment: Alignment.center,
                height: 35,
                child: Text('Task ${tasks[index].id} deleted'),
              ),
            ),
          );
        },
        child: Row(
          children: <Widget>[
            Checkbox(
              value: tasks[index].isFinished(),
              onChanged: (bool? value) {
                final task = tasks[index];
                objectbox.finishTask(task);
                // List updated via watched query stream.
              },
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18.0,
                    horizontal: 10.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${tasks[index].text} (tag: ${tasks[index].tag.target!.name})',
                        style: tasks[index].isFinished()
                            ? const TextStyle(
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              )
                            : const TextStyle(fontSize: 15.0),
                        // Provide a Key for the integration test
                        key: Key('list_item_$index'),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Text(
                          tasks[index].getStateText(),
                          style: const TextStyle(fontSize: 12.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(
              child: const Text('Edit'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TaskInput(
                      taskId: tasks[index].id,
                    ), //passing Id to access Task in new page
                  ),
                );
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<List<Task>>(
        stream: objectbox.getTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Print the stack trace and show the error message.
            // An actual app would display a user-friendly error message
            // and report the error behind the scenes.
            debugPrintStack(stackTrace: snapshot.stackTrace);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  child: Text('Error: ${snapshot.error}'),
                ),
              ],
            );
          } else {
            return ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: snapshot.hasData ? snapshot.data!.length : 0,
              itemBuilder: _itemBuilder(snapshot.data ?? []),
            );
          }
        },
      ),
    );
  }
}

class SwipeLeftNotification extends StatelessWidget {
  const SwipeLeftNotification({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 20.0, bottom: 10.0),
      child: Align(
        alignment: Alignment.topRight,
        child: Center(
          child: Text(
            'Delete a task by swiping it.',
            style: TextStyle(fontSize: 11.0, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
