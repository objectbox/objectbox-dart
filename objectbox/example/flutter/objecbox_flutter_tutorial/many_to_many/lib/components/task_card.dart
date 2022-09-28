import 'package:flutter/material.dart';

import '../main.dart';
import '../model.dart';
import 'delete_menu.dart';

/// Styling for an event card. Includes the task name, owner and a checkmark.
/// A card can be deleted through the delete button inside the menu bar.
class TaskCard extends StatefulWidget {
  final Task? task;

  const TaskCard({Key? key, this.task}) : super(key: key);

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  List<Owner> owners = [];
  String assignedString = "";
  bool? taskStatus;

  void toggleCheckBox() {
    bool newStatus = widget.task!.setFinished();
    objectbox.taskBox.put(widget.task!);

    setState(() {
      taskStatus = newStatus;
    });
  }

  @override
  void initState() {
    super.initState();
    setState(() {});

    owners.addAll(widget.task!.owner);

    assignedString = owners.map((owner) => owner.name).join(', ');
    taskStatus = widget.task!.status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      margin: const EdgeInsets.all(5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 243, 243, 243),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(255, 168, 168, 168),
                    blurRadius: 5,
                    offset: Offset(1, 2),
                  )
                ],
              ),
              child: Row(
                children: <Widget>[
                  Transform.scale(
                    scale: 1.3,
                    child: Checkbox(
                      shape: const CircleBorder(),
                      value: taskStatus,
                      onChanged: (bool? value) {
                        toggleCheckBox();
                      },
                    ),
                  ),
                  Flexible(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              widget.task!.text,
                              style: taskStatus!
                                  ? const TextStyle(
                                      fontSize: 20.0,
                                      height: 1.0,
                                      color: Color.fromARGB(255, 73, 73, 73),
                                      overflow: TextOverflow.ellipsis,
                                      decoration: TextDecoration.lineThrough)
                                  : const TextStyle(
                                      fontSize: 20.0,
                                      height: 1.0,
                                      overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Assigned to: $assignedString",
                                style: taskStatus!
                                    ? const TextStyle(
                                        fontSize: 15.0,
                                        height: 1.0,
                                        color:
                                            Color.fromARGB(255, 106, 106, 106),
                                        fontStyle: FontStyle.italic,
                                        decoration: TextDecoration.lineThrough,
                                        overflow: TextOverflow.visible)
                                    : const TextStyle(
                                        fontSize: 15.0,
                                        height: 1.0,
                                        overflow: TextOverflow.visible,
                                        fontStyle: FontStyle.italic,
                                      )),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<DeleteMenu>(
                    onSelected: (item) => onSelected(context, widget.task!),
                    itemBuilder: (BuildContext context) =>
                        [...MenuItems.itemsFirst.map(buildItem).toList()],
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(color: Colors.grey, Icons.more_horiz),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<DeleteMenu> buildItem(DeleteMenu item) =>
      PopupMenuItem<DeleteMenu>(value: item, child: Text(item.text!));

  void onSelected(BuildContext context, Task task) {
    objectbox.taskBox.remove(task.id);
    debugPrint(
        "Task ${task.text} deleted and had owners: ${task.owner.map((owner) => owner.name).join(", ")}");
  }
}
