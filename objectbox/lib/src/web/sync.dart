// Web stub for the ObjectBox Sync API: mirrors the public API of
// `../native/sync.dart` so that code referencing Sync compiles for web
// (dart2js and dart2wasm). Sync requires the native ObjectBox library, which
// is not available on web, so APIs throw. See tracking issue #185.
// ignore_for_file: public_member_api_docs, unused_element, unused_field

import 'dart:convert' show utf8;
import 'dart:typed_data';

import '../store.dart';
import 'unsupported.dart';

/// Credential type values, matching OBXSyncCredentialsType in the native
/// bindings (objectbox_c.dart).
abstract class _CredentialsType {
  static const int none = 1;
  static const int googleAuth = 3;
  static const int sharedSecretSipped = 4;
  static const int userPassword = 6;
  static const int jwtId = 7;
  static const int jwtAccess = 8;
  static const int jwtRefresh = 9;
  static const int jwtCustom = 10;
}

class SyncCredentials {
  final int _type;

  SyncCredentials._(this._type);

  static SyncCredentials none() => _SyncCredentialsNone._();

  static SyncCredentials sharedSecretUint8List(Uint8List data) =>
      SyncCredentialsSecret._(_CredentialsType.sharedSecretSipped, data);

  static SyncCredentials sharedSecretString(String data) =>
      SyncCredentialsSecret._encode(_CredentialsType.sharedSecretSipped, data);

  static SyncCredentials googleAuthUint8List(Uint8List data) =>
      SyncCredentialsSecret._(_CredentialsType.googleAuth, data);

  static SyncCredentials googleAuthString(String data) =>
      SyncCredentialsSecret._encode(_CredentialsType.googleAuth, data);

  static SyncCredentials userAndPassword(String user, String password) =>
      _SyncCredentialsUserPassword._(
        _CredentialsType.userPassword,
        user,
        password,
      );

  static SyncCredentials jwtIdToken(String jwtIdToken) =>
      SyncCredentialsSecret._encode(_CredentialsType.jwtId, jwtIdToken);

  static SyncCredentials jwtAccessToken(String jwtAccessToken) =>
      SyncCredentialsSecret._encode(_CredentialsType.jwtAccess, jwtAccessToken);

  static SyncCredentials jwtRefreshToken(String jwtRefreshToken) =>
      SyncCredentialsSecret._encode(
        _CredentialsType.jwtRefresh,
        jwtRefreshToken,
      );

  static SyncCredentials jwtCustomToken(String jwtCustomToken) =>
      SyncCredentialsSecret._encode(_CredentialsType.jwtCustom, jwtCustomToken);
}

class _SyncCredentialsNone extends SyncCredentials {
  _SyncCredentialsNone._() : super._(_CredentialsType.none);
}

/// Do not export, internal use only.
class SyncCredentialsSecret extends SyncCredentials {
  /// UTF-8 encoded string.
  final Uint8List data;

  SyncCredentialsSecret._(super.type, this.data) : super._();

  SyncCredentialsSecret._encode(super.type, String data)
      : data = Uint8List.fromList(utf8.encode(data)),
        super._();
}

class _SyncCredentialsUserPassword extends SyncCredentials {
  final String _user;
  final String _password;

  _SyncCredentialsUserPassword._(super._type, this._user, this._password)
      : super._();
}

enum SyncState {
  unknown,
  created,
  started,
  connected,
  loggedIn,
  disconnected,
  stopped,
  dead,
}

enum SyncRequestUpdatesMode { manual, auto, autoNoPushes }

enum SyncConnectionEvent { connected, disconnected }

enum SyncLoginEvent { loggedIn, credentialsRejected, unknownError }

class SyncChange {
  final int entityId;

  final Type entity;

  final List<int> puts;

  final List<int> removals;

  SyncChange._(this.entityId, this.entity, this.puts, this.removals);
}

class SyncClient {
  SyncClient(
    Store store,
    List<String> serverUrls,
    List<SyncCredentials> credentials, {
    Map<String, String>? filterVariables,
    List<String>? certificatePaths,
    int? flags,
  }) {
    throwUnsupportedOnWeb();
  }

  void close() => throwUnsupportedOnWeb();

  bool isClosed() => throwUnsupportedOnWeb();

  static int protocolVersion() => throwUnsupportedOnWeb();

  int protocolVersionServer() => throwUnsupportedOnWeb();

  SyncState state() => throwUnsupportedOnWeb();

  void putFilterVariable(String name, String value) => throwUnsupportedOnWeb();

  void removeFilterVariable(String name) => throwUnsupportedOnWeb();

  void removeAllFilterVariables() => throwUnsupportedOnWeb();

  void applyFilterVariables() => throwUnsupportedOnWeb();

  void setCredentials(SyncCredentials creds) => throwUnsupportedOnWeb();

  void setMultipleCredentials(List<SyncCredentials> credentials) =>
      throwUnsupportedOnWeb();

  void setRequestUpdatesMode(SyncRequestUpdatesMode mode) =>
      throwUnsupportedOnWeb();

  void start() => throwUnsupportedOnWeb();

  void stop() => throwUnsupportedOnWeb();

  bool triggerReconnect() => throwUnsupportedOnWeb();

  bool requestUpdates({required bool subscribeForFuturePushes}) =>
      throwUnsupportedOnWeb();

  bool cancelUpdates() => throwUnsupportedOnWeb();

  int outgoingMessageCount({int limit = 0}) => throwUnsupportedOnWeb();

  Stream<SyncConnectionEvent> get connectionEvents => throwUnsupportedOnWeb();

  Stream<SyncLoginEvent> get loginEvents => throwUnsupportedOnWeb();

  Stream<void> get completionEvents => throwUnsupportedOnWeb();

  Stream<List<SyncChange>> get changeEvents => throwUnsupportedOnWeb();
}

// Note: because in Dart can't have two classes exported with the same name,
// this class doubles as the annotation class (compare annotations.dart) and
// configuration class for Sync.
class Sync {
  final bool sharedGlobalIds;

  const Sync({this.sharedGlobalIds = false});

  /// Sync requires the native ObjectBox library, which is never available on
  /// web, so this honestly answers `false` instead of throwing.
  static bool isAvailable() => false;

  static int syncClockTimestamp(int syncClockValue) => throwUnsupportedOnWeb();

  static int syncClockTimestampCorrected(int syncClockValue) =>
      throwUnsupportedOnWeb();

  @Deprecated('Use the SyncClient constructor instead')
  static SyncClient client(
    Store store,
    String serverUrl,
    SyncCredentials credentials, {
    Map<String, String>? filterVariables,
    List<String>? certificatePaths,
    int? flags,
  }) =>
      throwUnsupportedOnWeb();

  @Deprecated('Use the SyncClient constructor instead')
  static SyncClient clientMultiCredentials(
    Store store,
    String serverUrl,
    List<SyncCredentials> credentials, {
    Map<String, String>? filterVariables,
    List<String>? certificatePaths,
    int? flags,
  }) =>
      throwUnsupportedOnWeb();

  @Deprecated('Use the SyncClient constructor instead')
  static SyncClient clientMultiUrls(
    Store store,
    List<String> serverUrls,
    SyncCredentials credentials, {
    Map<String, String>? filterVariables,
    List<String>? certificatePaths,
    int? flags,
  }) =>
      throwUnsupportedOnWeb();

  @Deprecated('Use the SyncClient constructor instead')
  static SyncClient clientMultiCredentialsMultiUrls(
    Store store,
    List<String> serverUrls,
    List<SyncCredentials> credentials, {
    Map<String, String>? filterVariables,
    List<String>? certificatePaths,
    int? flags,
  }) =>
      throwUnsupportedOnWeb();
}
