import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';

class NewTag extends StatefulWidget {
  final void Function(int) updateTags;

  const NewTag({Key? key, required this.updateTags}) : super(key: key);

  @override
  State<NewTag> createState() => _NewTagState();
}

class _NewTagState extends State<NewTag> {
  final _tagInputController = TextEditingController();

  void _addTag(String newTagText) {
    if (newTagText.isEmpty) return;

    final existingTags = objectbox.tagBox.getAll();

    //iterate over the list to avoid duplicate tag
    var myListIter = existingTags.iterator;
    while (myListIter.moveNext()) {
      if (myListIter.current.name == newTagText) return;
    }

    final newTagId = objectbox.tagBox.put(Tag(newTagText));
    debugPrint("New Added Tag: ${objectbox.tagBox.get(newTagId)?.name}");

    widget.updateTags(newTagId);
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      label: const Text('New Tag'),
      heroTag: null,
      onPressed: () => {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('New tag'),
            content: TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Enter the tag name'),
              controller: _tagInputController,
            ),
            actions: [
              TextButton(
                child: const Text('Submit'),
                onPressed: () {
                  _addTag(_tagInputController.text);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        )
      },
    );
  }
}
