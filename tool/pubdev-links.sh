. "$(dirname "$0")"/common.sh

echo "Setting pub.dev specific links"

update objectbox/README.md "s|example/README.md|https://pub.dev/packages/objectbox/example|g"
update objectbox/README.md "s|CHANGELOG.md|https://pub.dev/packages/objectbox/changelog|g"
update objectbox/README.md "s|../CONTRIBUTING.md|https://github.com/objectbox/objectbox-dart/blob/main/CONTRIBUTING.md|g"
# Link generated by pub.dev is missing "objectbox" path, so replace with absolute link.
update objectbox/example/README.md "s|flutter/objectbox_demo_relations|https://github.com/objectbox/objectbox-dart/tree/main/objectbox/example/flutter/objectbox_demo_relations|g"