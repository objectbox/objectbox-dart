import 'store.dart';
import 'sync.dart';

// ignore_for_file: public_member_api_docs

/// Global internal storage of sync clients - one client per store.
final Map<Store, SyncClient> syncClientsStorage = {};
