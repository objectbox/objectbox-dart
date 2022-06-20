import 'dart:async';

import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';

import 'task_elements.dart';

class TaskList extends StatefulWidget {
  const TaskList({Key? key}) : super(key: key);

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  Dismissible Function(BuildContext, int) _itemBuilder(List<Task> tasks) =>
      (BuildContext context, int index) => Dismissible(
            background: Container(
              color: Colors.red,
            ),
            key: UniqueKey(), //Key('dismissed_$index'),
            onDismissed: (direction) {
              // Remove the task from the store.
              objectbox.taskBox.remove(tasks[index].id);
              // List updated via watched query stream.
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(bottom: 0, right: 70, left: 70),
                  padding: const EdgeInsets.all(5),
                  duration: const Duration(milliseconds: 800),
                  content: Container(
                      alignment: Alignment.center,
                      height: 35,
                      child: Text('Task ${tasks[index].id} deleted'))));
            },
            child: Row(
              children: <Widget>[
                Checkbox(
                    value: tasks[index].isFinished(),
                    onChanged: (bool? value) {
                      final task = tasks[index];
                      task.toggleFinished();
                      objectbox.taskBox.put(task);
                      // List updated via watched query stream.
                    }),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.black12))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18.0, horizontal: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${tasks[index].text} (tag: ${tasks[index].tag.target!.name})',
                            style: tasks[index].isFinished()
                                ? const TextStyle(
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough)
                                : const TextStyle(fontSize: 15.0),
                            // Provide a Key for the integration test
                            key: Key('list_item_$index'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(
                              tasks[index].getStateText(),
                              style: const TextStyle(
                                fontSize: 12.0,
                              ),
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
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TaskInput(
                                taskId: tasks[index].id,
                              ) //passing Id to access Task in new page
                          ));
                    }),
              ],
            ),
          );

  final _taskListController = StreamController<List<Task>>(sync: true);

  @override
  void initState() {
    super.initState();
    setState(() {});

    _taskListController.addStream(objectbox.tasksStream.map((q) => q.find()));
  }

  @override
  void dispose() {
    _taskListController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: StreamBuilder<List<Task>>(
            stream: _taskListController.stream,
            builder: (context, snapshot) => ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: snapshot.hasData ? snapshot.data!.length : 0,
                itemBuilder: _itemBuilder(snapshot.data ?? []))));
  }
}

class SwipeLeftNotification extends StatelessWidget {
  const SwipeLeftNotification({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 20.0, bottom: 10.0),
      child: Align(
        alignment: Alignment.topRight,
        child: Center(
          child: Text(
            'Delete a task by swiping it.',
            style: TextStyle(
              fontSize: 11.0,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
