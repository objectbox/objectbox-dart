# web_test

Internal test package (not published) for the web implementation of ObjectBox
(`objectbox/lib/src/web/`): Store/Box CRUD, relations, transactions,
IndexedDB persistence and queries, running in a real browser.

## Running

```bash
dart pub get
dart run build_runner build
dart test -p chrome              # dart2js
dart test -p chrome -c dart2wasm # WasmGC
```

Unlike `objectbox_test`, no native ObjectBox library is required: everything
runs in the browser against the IndexedDB-backed web engine.
