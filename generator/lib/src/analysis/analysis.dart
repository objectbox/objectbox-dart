import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:pubspec_parse/pubspec_parse.dart';

import '../version.dart';
import 'build_properties.dart';

/// Sends anonymous data to analyze usage of this package.
///
/// Requires [tokenFilePath] to exist, otherwise does nothing. See the
/// associated test (analysis_test.dart) on how to create this file.
class ObjectBoxAnalysis {
  static const _debug = false;

  /// Path is relative to lib folder.
  static const tokenFilePath = "assets/analysis-token.txt";

  static const _url = "api.mixpanel.com";
  static const _path = "track";

  /// Builds a Build event and sends it with [sendEvent]. May not send if it
  /// fails to store a unique identifier and last time sent, or if no valid API
  /// token is found.
  Future<void> sendBuildEvent(Pubspec? pubspec) async {
    var buildProperties = await BuildProperties.get();
    if (buildProperties == null) {
      buildProperties = BuildProperties.create();
    } else {
      // Send at most one event per day.
      if (DateTime.now().millisecondsSinceEpoch <
          buildProperties.lastSentMs + Duration(days: 1).inMilliseconds) {
        if (_debug) {
          print("[ObjectBox] Analysis event sent within last day, skip.");
        }
        return;
      }
      buildProperties = BuildProperties.updateLastSentMs(buildProperties);
    }
    if (!await buildProperties.write()) {
      if (_debug) {
        print("[ObjectBox] Analysis failed to save build properties.");
      }
      return;
    }

    final event = buildEvent("Build", buildProperties.uid, pubspec);

    try {
      final response = await sendEvent(event);
      if (_debug && response != null) {
        print(
            "[ObjectBox] Analysis response: ${response.statusCode} ${response.body}");
      }
    } catch (e, s) {
      // E.g. connection can not be established (offline, TLS issue, ...).
      // Just swallow the exception, sending the event is not required for the
      // build to succeed.
      if (_debug) {
        print("[ObjectBox] Analysis send failed: $e");
        print("[ObjectBox] Analysis stack trace:\n$s");
      }
    }
  }

  /// Sends an [Event] and returns the response.
  ///
  /// May return null if the API token could not be obtained.
  ///
  /// May throw if establishing a connection fails.
  Future<http.Response?> sendEvent(Event event) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      print("[ObjectBox] Analysis disabled, would have sent event: $event");
      return null;
    }
    event.properties["token"] = token;

    // https://developer.mixpanel.com/reference/track-event
    final body = "[${event.toJson()}]";
    final url = Uri.https(_url, _path);
    if (_debug) print("[ObjectBox] Analysis sending to $url: $body");
    return http.post(url,
        headers: {'Accept': 'text/plain', 'Content-Type': 'application/json'},
        body: body);
  }

  /// Uses the given values to gather properties and return them as an [Event].
  Event buildEvent(String eventName, String distinctId, Pubspec? pubspec) {
    final properties = <String, String>{};
    properties["distinct_id"] = distinctId;

    properties["Tool"] = "Dart Generator";
    properties["Version"] = Version.current;

    final dartVersion = RegExp('([0-9]+).([0-9]+).([0-9]+)')
        .firstMatch(Platform.version)
        ?.group(0);
    properties["Dart"] = dartVersion ?? "unknown";
    // true or false is enough as Dart version above is tied closely to a
    // specific Flutter release (see https://docs.flutter.dev/development/tools/sdk/releases).
    final hasFlutter = pubspec?.dependencies["flutter"] != null;
    properties["Flutter"] = hasFlutter.toString();

    properties["BuildOS"] = Platform.operatingSystem;
    properties["BuildOSVersion"] = Platform.operatingSystemVersion;

    // Note: If no CI detected, do not set CI property.
    final ci = Platform.environment["CI"];
    if (ci != null) {
      properties["CI"] = ci;
    }

    final langAndRegion = LanguageAndRegion();
    properties["lang"] = langAndRegion.lang;
    properties["c"] = langAndRegion.region;

    return Event(eventName, properties);
  }

  Future<String?> _getToken() async {
    final uri = Uri.parse("package:objectbox_generator/$tokenFilePath");
    final resolvedUri = await Isolate.resolvePackageUri(uri);
    if (resolvedUri != null) {
      final file = File.fromUri(resolvedUri);
      try {
        if (await file.exists()) {
          final lines = await file.readAsLines();
          if (lines.length >= 2) {
            return decryptToken(lines[0], lines[1]);
          }
        }
      } catch (e) {
        // Ignore.
      }
    }
    return null;
  }

  /// Takes a Base64 encoded secret key and secret text (which is a [SecretBox]
  /// concatenation) and returns the decrypted text.
  Future<String> decryptToken(
      String secretKeyBase64, String secretTextBase64) async {
    final algorithm = Chacha20.poly1305Aead();
    var secretKeyBytes = base64Decode(secretKeyBase64);
    final secretKey = SecretKeyData(secretKeyBytes);

    final secretBox = SecretBox.fromConcatenation(
        base64Decode(secretTextBase64),
        nonceLength: algorithm.nonceLength,
        macLength: algorithm.macAlgorithm.macLength);

    final clearText = await algorithm.decrypt(secretBox, secretKey: secretKey);

    return utf8.decode(clearText);
  }
}

/// Wrapper for data to be sent for analysis. Use [toJson] to return a
/// JSON object representation.
class Event {
  final String name;
  final Map<String, String> properties;

  /// See class documentation.
  Event(this.name, this.properties);

  /// Return this as a JSON object.
  String toJson() {
    final map = {'event': name, 'properties': properties};
    return jsonEncode(map);
  }

  @override
  String toString() => toJson();
}

class LanguageAndRegion {
  final String lang;
  final String region;

  /// Extracts language and region classifier from a locale String.
  ///
  /// If [localeOrNull] is null, uses [Platform.localeName].
  factory LanguageAndRegion({String? localeOrNull}) {
    var locale = localeOrNull ?? Platform.localeName;
    // Drop .UTF-8 suffix, e.g. of C.UTF-8 or en_US.UTF-8
    locale = locale.replaceAll(RegExp(RegExp.escape(".UTF-8")), "");
    // If ISO code (xx-XX or xx_XX format), split into lang and region.
    // Otherwise set to unknown.
    var splitLocale =
        locale.contains("_") ? locale.split("_") : locale.split("-");
    final lang = splitLocale.isNotEmpty ? splitLocale[0] : "unknown";
    final region = splitLocale.length >= 2 ? splitLocale[1] : "unknown";
    return LanguageAndRegion._(lang, region);
  }

  LanguageAndRegion._(this.lang, this.region);
}
