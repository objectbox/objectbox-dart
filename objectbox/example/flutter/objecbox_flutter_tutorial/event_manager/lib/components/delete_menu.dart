class MenuElement {
  final String? text;

  const MenuElement({required this.text});
}

class MenuItems {
  static const List<MenuElement> itemsFirst = [itemDelete];
  static const itemDelete = MenuElement(text: "Delete");
}
