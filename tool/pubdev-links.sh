. "$(dirname "$0")"/common.sh

echo "Setting pub.dev specific links"

update objectbox/README.md "s|example/README.md|https://pub.dev/packages/objectbox/example|g"
update objectbox/README.md "s|CHANGELOG.md|https://pub.dev/packages/objectbox/changelog|g"
update objectbox/README.md "s|../CONTRIBUTING.md|https://github.com/objectbox/objectbox-dart/blob/main/CONTRIBUTING.md|g"