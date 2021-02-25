. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <app-dir>"
  echo "e.g. $0 example/objectbox_demo"
  exit 1
fi

set -x

cd "${root}/$1"
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter drive --verbose --target=test_driver/app.dart