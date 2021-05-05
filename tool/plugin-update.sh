. "$(dirname "$0")"/common.sh

# Begins an update of flutter plugins - you need to manually review the changes and commit what's necessary.
function create() {
  dir=$1
  cd "$root/$dir"

  flutter create \
    --android-language=java \
    --template=plugin \
    --org=io.objectbox \
    --platforms=ios,android \
    --project-name=objectbox_$dir \
    .

  # we don't want any changes to these dirs
  git clean -fxd example
  git clean -fxd test
}

create flutter_libs
create sync_flutter_libs
