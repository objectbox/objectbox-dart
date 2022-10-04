import 'package:flutter/material.dart';

import '../main.dart';
import '../model.dart';

/// Adds a new task and assigns an owner.
class AddTask extends StatefulWidget {
  final Event event;

  const AddTask({Key? key, required this.event}) : super(key: key);

  @override
  State<AddTask> createState() => _AddTaskState();
}

class _AddTaskState extends State<AddTask> {
  final inputController = TextEditingController();
  final ownerInputController = TextEditingController();
  List<Owner> owners = objectbox.ownerBox.getAll();
  late Owner currentOwner;

  void createOwner(String name) {
    List<Owner> newOwnersList = [];
    Owner newCurrentOwner;

    int newOwner = objectbox.addOwner(name);
    newOwnersList = objectbox.ownerBox.getAll();
    newCurrentOwner = objectbox.ownerBox.get(newOwner)!;

    setState(() {
      owners = newOwnersList;
      currentOwner = newCurrentOwner;
    });
  }

  void updateOwner(int changedOwnerId) {
    Owner newCurrentOwner;

    newCurrentOwner = objectbox.ownerBox.get(changedOwnerId)!;

    setState(() {
      currentOwner = newCurrentOwner;
    });
  }

  void createTask() {
    if (inputController.text.isNotEmpty) {
      objectbox.addTask(inputController.text, currentOwner, widget.event);
    }
  }

  @override
  void initState() {
    currentOwner = owners[0];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Task")),
      key: UniqueKey(),
      body: Column(children: <Widget>[
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              controller: inputController,
            )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              const Text("Assign Owner:", style: TextStyle(fontSize: 17)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButton<int>(
                    value: currentOwner.id,
                    items: owners
                        .map((element) => DropdownMenuItem(
                            value: element.id,
                            child: Text(element.name,
                                style: const TextStyle(
                                    fontSize: 15.0,
                                    height: 1.0,
                                    overflow: TextOverflow.fade))))
                        .toList(),
                    underline: Container(
                      height: 1.5,
                      color: Colors.blueAccent,
                    ),
                    onChanged: (value) => {updateOwner(value!)}),
              ),
              const Spacer(),
              TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('New Owner'),
                        content: TextField(
                          autofocus: true,
                          decoration: const InputDecoration(
                              hintText: 'Enter the owner name'),
                          controller: ownerInputController,
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Submit'),
                            onPressed: () {
                              createOwner(ownerInputController.text);
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    );
                    ownerInputController.clear();
                  },
                  child: const Text(
                    "Add Owner",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: ElevatedButton(
                  child: const Text(
                    "Save",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    createTask();

                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        )
      ]),
    );
  }
}
