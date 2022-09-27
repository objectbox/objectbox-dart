import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';

/// Adds a new event
class AddEvent extends StatefulWidget {
  const AddEvent({Key? key}) : super(key: key);

  @override
  State<AddEvent> createState() => _AddEventState();
}

class _AddEventState extends State<AddEvent> {
  final eventNameController = TextEditingController();
  final eventLocationController = TextEditingController();

  DateTime? currentDate;

  void createEvent() {
    if (eventLocationController.text.isNotEmpty &&
        eventNameController.text.isNotEmpty &&
        currentDate != null) {
      objectbox.addEvent(
          eventNameController.text, currentDate!, eventLocationController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Event"),
      ),
      body: Column(children: <Widget>[
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              controller: eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
              ),
            )),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              controller: eventLocationController,
              decoration: const InputDecoration(
                labelText: 'Location',
              ),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  currentDate != null
                      ? "Date: ${DateFormat.yMd().format(currentDate!)}"
                      : "Date: Not Selected",
                ),
              ),
              const Spacer(),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: TextButton(
                    child: const Text("Select a date",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2022),
                              lastDate: DateTime(2050))
                          .then((date) {
                        setState(() {
                          currentDate = date;
                        });
                      });
                    },
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton(
                  child: const Text(
                    "Save",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    createEvent();
                    Navigator.pop(context);
                  })
            ],
          ),
        ),
      ]),
    );
  }
}
