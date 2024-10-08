import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:objectbox_generator/src/analysis/analysis.dart';
import 'package:objectbox_generator/src/analysis/build_properties.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/macs/poly1305.dart';
import 'package:pointycastle/stream/chacha20poly1305.dart';
import 'package:pointycastle/stream/chacha7539.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  // ### Create analysis-token.txt file
  // Obtain the project token from MixPanel project settings,
  // insert below, then manually run this test (set skip to false).
  test("obfuscate token", () async {
    final token = "REPLACE_WITH_TOKEN";

    var obfuscatedToken = _obfuscateToken(token);
    final keyBase64 = obfuscatedToken.keyBase64;
    final dataBase64 = obfuscatedToken.dataBase64;
    print("Store this in generator/lib/${ObjectBoxAnalysis.tokenFilePath}:");
    print("$keyBase64\n$dataBase64");

    final decryptedToken =
        ObjectBoxAnalysis().decryptAndVerifyToken(keyBase64, dataBase64);
    expect(decryptedToken, equals(token));
  }, skip: true);

  test("send test event", () async {
    // Create a token file just for this test (delete right after to avoid
    // CI sending events).
    final token = Platform.environment["DART_ANALYSIS_TOKEN"];
    if (token == null) {
      markTestSkipped("DART_ANALYSIS_TOKEN not set");
      return;
    }
    var obfuscatedToken = _obfuscateToken(token);
    final tokenFile = File("lib/${ObjectBoxAnalysis.tokenFilePath}");
    await tokenFile.writeAsString(
        "${obfuscatedToken.keyBase64}\n${obfuscatedToken.dataBase64}");

    final testPubspec = Pubspec("test", dependencies: {
      "flutter": SdkDependency("flutter"),
      "objectbox": HostedDependency(version: VersionConstraint.parse("^1.2.3"))
    });

    final analysis = ObjectBoxAnalysis();
    final event = analysis.buildEvent("Test Event", "test-uid", testPubspec);
    final response = await analysis.sendEvent(event);

    // Delete token before test may fail to ensure CI does not send events.
    await tokenFile.delete();

    expect(response!.statusCode, 200);
    expect(response.body, "1");
  });

  test("get lang and region", () {
    final cUtf8 = LanguageAndRegion(localeOrNull: "C.UTF-8");
    expect(cUtf8.lang, "C");
    expect(cUtf8.region, "unknown");

    final enUtf8 = LanguageAndRegion(localeOrNull: "xx_XX.UTF-8");
    expect(enUtf8.lang, "xx");
    expect(enUtf8.region, "XX");

    final en = LanguageAndRegion(localeOrNull: "xx");
    expect(en.lang, "xx");
    expect(en.region, "unknown");

    final enUS = LanguageAndRegion(localeOrNull: "xx_XX");
    expect(enUS.lang, "xx");
    expect(enUS.region, "XX");

    final enDashUS = LanguageAndRegion(localeOrNull: "xx-XX");
    expect(enDashUS.lang, "xx");
    expect(enDashUS.region, "XX");
  });

  test("build properties file", () async {
    // Read an existing file.
    final existingTestFile = File("test/analysis_test_uid.json");

    final existingProperties =
        await BuildProperties.get(filePath: existingTestFile.path);

    expect(existingProperties!.uid, "test-uid");
    expect(existingProperties.lastSentMs, 123456789);

    // Create a new file.
    final newTestFile = File("test/analysis_test_uid_new.json");
    if (await newTestFile.exists()) await newTestFile.delete();

    expect(
        await BuildProperties.create().write(filePath: newTestFile.path), true);
    final newProperties = await BuildProperties.get(filePath: newTestFile.path);

    expect(newProperties, isNotNull);
    expect(newProperties!.uid, isNotEmpty);
    expect(newProperties.lastSentMs > 0, true);
    // Base64 value should not have padding.
    expect(newProperties.uid.endsWith("="), false);
  });

  test("get out directory", () {
    var home = BuildProperties.getOutDirectoryPath();
    expect(home, isNotNull);
    expect(home, isNotEmpty);
    // Very simple validity check (yes, paths may differ depending on system
    // configuration, but below is fine for testing).
    if (Platform.isLinux) {
      expect(home!.startsWith("/"), true);
    } else if (Platform.isWindows) {
      expect(home!.startsWith("C:\\Users\\"), true);
    }
  });
}

/// Encrypt to obfuscate token and use MAC to ensure token did not get damaged.
/// This is explicitly not used for security purposes.
ObfuscatedToken _obfuscateToken(String token) {
  // Note: support Dart before 3.2 where encode returns List<int>
  final message = Uint8List.fromList(utf8.encode(token));
  final key = _generateRandomBytes(32);
  final nonce = _generateRandomBytes(ObfuscatedToken.nonceLengthBytes);

  final algorithm = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
  var params = AEADParameters(
      KeyParameter(key), ObfuscatedToken.macLengthBits, nonce, Uint8List(0));
  algorithm.init(true /* encrypt */, params);

  final encrypted = Uint8List(algorithm.getOutputSize(message.length));
  final outLen =
      algorithm.processBytes(message, 0, message.length, encrypted, 0);
  algorithm.doFinal(encrypted, outLen);

  // Store nonce together with encrypted text (which includes the MAC at the end)
  final dataBase64 = base64Encode(nonce + encrypted);
  final keyBase64 = base64Encode(key);

  return ObfuscatedToken(dataBase64, keyBase64);
}

Uint8List _generateRandomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (int i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}
