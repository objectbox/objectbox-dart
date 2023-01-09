import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Stores properties to be used by the analysis tool.
class BuildProperties {
  static const _fileName = ".objectbox-dart-build";
  static const _keyUid = "uid";
  static const _keyLastSentMs = "lastSent";

  /// An identifier created from random data.
  final String uid;

  /// The last time an event was sent in milliseconds since epoch.
  final int lastSentMs;

  BuildProperties._(this.uid, this.lastSentMs);

  /// Creates a new UID and last sent time of now.
  BuildProperties.create()
      : uid = _generateUid(),
        lastSentMs = DateTime.now().millisecondsSinceEpoch;

  /// Uses the existing UID and last sent time of now.
  BuildProperties.updateLastSentMs(BuildProperties buildProperties)
      : uid = buildProperties.uid,
        lastSentMs = DateTime.now().millisecondsSinceEpoch;

  /// Returns values read from an existing file. If the file can not be read or
  /// it does not have any of the expected properties, returns null.
  ///
  /// By default uses a file in the users home directory using the default
  /// file name. Supply [filePath] to use that instead.
  static Future<BuildProperties?> get({String? filePath}) async {
    final file = _buildFile(filePath);
    if (file == null) return null;

    dynamic buildPropertiesUnsafe;
    try {
      var json = await file.readAsString();
      buildPropertiesUnsafe = jsonDecode(json);
    } catch (e) {
      buildPropertiesUnsafe = null;
    }

    final Map<String, dynamic> buildProperties;
    if (buildPropertiesUnsafe is Map<String, dynamic>) {
      buildProperties = buildPropertiesUnsafe;
    } else {
      return null;
    }

    final uidOrNull = buildProperties[_keyUid];
    final String uid;
    if (uidOrNull != null && uidOrNull is String && uidOrNull.isNotEmpty) {
      uid = uidOrNull;
    } else {
      return null;
    }

    final lastSentMsOrNull = buildProperties[_keyLastSentMs];
    final int lastSentMs;
    if (lastSentMsOrNull != null &&
        lastSentMsOrNull is int &&
        lastSentMsOrNull > 0) {
      lastSentMs = lastSentMsOrNull;
    } else {
      return null;
    }

    return BuildProperties._(uid, lastSentMs);
  }

  /// Writes the current values to a file. Returns if it was successful.
  ///
  /// By default uses a file in the [getOutDirectoryPath] using the default
  /// [_fileName]. Supply [filePath] to use that instead.
  Future<bool> write({String? filePath}) async {
    final file = _buildFile(filePath);
    if (file == null) {
      return false;
    }
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
          jsonEncode({_keyUid: uid, _keyLastSentMs: lastSentMs}));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Creates a file using the default [_fileName] in the [getOutDirectoryPath].
  /// Supply [filePath] to use that instead.
  static File? _buildFile(String? filePath) {
    if (filePath == null) {
      final outDir = getOutDirectoryPath();
      if (outDir == null) {
        return null;
      }
      filePath = "$outDir/$_fileName";
    }
    return File(filePath);
  }

  /// Gets a directory path to store the file output of this.
  /// Or null on not supported platforms.
  ///
  /// Returns the user home directory on Linux and a local app data (not
  /// roaming, machine specific) directory on Windows.
  static String? getOutDirectoryPath() {
    final env = Platform.environment;
    if (Platform.isLinux || Platform.isMacOS) {
      return env["HOME"];
    } else if (Platform.isWindows) {
      final localAppDataPath = env["LOCALAPPDATA"];
      if (localAppDataPath != null) {
        return "$localAppDataPath/objectbox-dart";
      }
    }
    return null;
  }

  /// Generates a randomly generated 64-bit integer and returns it encoded as a
  /// base64 string with padding characters removed.
  static String _generateUid() {
    // nextInt only supports values up to 1<<32,
    // so concatenate two to get a 64-bit integer.
    final random = Random.secure();
    final rightPart = random.nextInt(1 << 32);
    final leftPart = random.nextInt(1 << 32);
    final uid = (leftPart << 32) | rightPart;

    // Convert to a base64 encoded string.
    final uidBytes = Uint8List(8)..buffer.asInt64List()[0] = uid;
    var uidEncoded = base64Encode(uidBytes);

    // Remove the padding as the value is never decoded.
    while (uidEncoded.endsWith("=")) {
      uidEncoded = uidEncoded.substring(0, uidEncoded.length - 1);
    }
    return uidEncoded;
  }
}
