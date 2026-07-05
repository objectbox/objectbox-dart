/// Helper for the web platform stubs: every API that requires the native
/// ObjectBox library throws via this function until the web implementation
/// is available.
Never throwUnsupportedOnWeb() => throw UnsupportedError(
    'ObjectBox for web is not yet available: this API requires the native '
    'ObjectBox library. Track progress at '
    'https://github.com/objectbox/objectbox-dart/issues/185.');
