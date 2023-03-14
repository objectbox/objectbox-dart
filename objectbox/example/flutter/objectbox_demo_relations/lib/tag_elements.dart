import 'package:flutter/material.dart';

import 'main.dart';

/// Displays a floating action button that opens a dialog to add a new tag.
class NewTag extends StatefulWidget {
  final void Function(int) updateTags;

  /// [updateTags] returns the ID of the added tag.
  const NewTag({Key? key, required this.updateTags}) : super(key: key);

  @override
  State<NewTag> createState() => _NewTagState();
}

class _NewTagState extends State<NewTag> {
  final _tagInputController = TextEditingController();

  Future<void> _addTag(String name) async {
    final newTagId = await objectbox.addTag(name);
    if (newTagId > 0) {
      widget.updateTags(newTagId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      label: const Text('New Tag'),
      heroTag: null,
      onPressed: () async {
        final dialog = await showDialog(
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
        );
        // Clear text after dialog is dismissed.
        _tagInputController.clear();
        return dialog;
      },
    );
  }
}
