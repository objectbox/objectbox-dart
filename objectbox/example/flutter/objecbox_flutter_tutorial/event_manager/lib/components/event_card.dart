import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model.dart';
import 'task_page.dart';

/// Styling for an event card. Includes the name, location and date.
/// Clicking a card navigates to a list of tasks related to event.

class EventCard extends StatefulWidget {
  final Event event;

  const EventCard({Key? key, required this.event}) : super(key: key);

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => TaskPage(event: widget.event)));
      },
      child: Container(
        margin: const EdgeInsets.all(5),
        child: Column(
          children: <Widget>[
            Container(
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
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(5),
                          child: Text(
                            widget.event.name,
                            style: const TextStyle(
                                fontSize: 25.0,
                                height: 1.0,
                                overflow: TextOverflow.fade),
                          ),
                        ),
                        Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            children: [
                              Text("Location: ${widget.event.location}",
                                  style: const TextStyle(
                                      fontSize: 15.0,
                                      height: 1.0,
                                      overflow: TextOverflow.fade)),
                              const Spacer(),
                              Text(
                                  "Date: ${DateFormat.yMd().format(widget.event.date!)}",
                                  style: const TextStyle(
                                      fontSize: 15.0,
                                      height: 1.0,
                                      overflow: TextOverflow.fade))
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
