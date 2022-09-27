import 'package:flutter/material.dart';
import '../main.dart';
import '../model.dart';
import './owner_select.dart';

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

  List<Owner> currentOwner = [];
  @override
  void initState() {
    super.initState();
  }

  void _addOwner(String ownerName) {
    Owner newOwner = Owner(ownerName);
    objectbox.ownerBox.put(newOwner);
    setState(() {
      currentOwner = [newOwner];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Add Task")),
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
                Expanded(child: Card(child: buildSingleOwner(context))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
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
                                _addOwner(ownerInputController.text);
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
          Row(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: ElevatedButton(
                  child: const Text(
                    "Save",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    if (inputController.text.isNotEmpty) {
                      objectbox.addTask(
                          inputController.text, currentOwner, widget.event);

                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          )
        ]));
  }

  Widget buildSingleOwner(context) {
    dynamic onTap() async {
      final selectedOwners = await Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => const OwnerList()));

      if (selectedOwners == null) return;
      setState(() {
        currentOwner = selectedOwners;
      });

      return selectedOwners;
    }

    return currentOwner.isEmpty
        ? buildListTile(title: "No Owner", onTap: onTap)
        : buildListTile(
            title: currentOwner.map((owners) => owners.name).join(", "),
            onTap: onTap);
  }

  Widget buildListTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.black, fontSize: 18),
      ),
      trailing:
          const Icon(Icons.arrow_drop_down, color: Colors.black, size: 20),
    );
  }
}
