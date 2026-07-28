import 'dart:convert';
import 'dart:typed_data';

import 'package:alcohol_neon/features/nfc/ndef_uri.dart';
import 'package:flutter_test/flutter_test.dart';

/// The NDEF URI codec + tag-id extraction: the pure logic between a physical
/// tag's bytes and the tagId we hand to zinc, and the same parser the deep-link
/// handler uses for /t/{tagId} links.
void main() {
  Uint8List payload(int code, String rest) =>
      Uint8List.fromList([code, ...utf8.encode(rest)]);

  final base = Uri.parse('https://t.lazytax.club/t/');
  const tagId = '3f9c2b7e-1a2b-4c3d-8e9f-0a1b2c3d4e5f';

  group('decodeNdefUriPayload', () {
    test('expands the https:// abbreviation (0x04)', () {
      expect(
        decodeNdefUriPayload(payload(0x04, 't.lazytax.club/t/$tagId')),
        'https://t.lazytax.club/t/$tagId',
      );
    });

    test('handles the no-abbreviation code (0x00)', () {
      expect(
        decodeNdefUriPayload(payload(0x00, 'https://t.lazytax.club/t/$tagId')),
        'https://t.lazytax.club/t/$tagId',
      );
    });

    test('returns null for an empty payload', () {
      expect(decodeNdefUriPayload(Uint8List(0)), isNull);
    });
  });

  group('tagIdFromUrl', () {
    test('extracts the id from our canonical URL', () {
      expect(tagIdFromUrl('https://t.lazytax.club/t/$tagId', base), tagId);
    });

    test('tolerates trailing slash, http, and www', () {
      expect(tagIdFromUrl('https://t.lazytax.club/t/$tagId/', base), tagId);
      expect(tagIdFromUrl('http://t.lazytax.club/t/$tagId', base), tagId);
      expect(tagIdFromUrl('https://www.t.lazytax.club/t/$tagId', base), tagId);
    });

    test('rejects other hosts, paths, and malformed ids', () {
      expect(tagIdFromUrl('https://evil.example/t/$tagId', base), isNull);
      expect(
        tagIdFromUrl('https://lazytax.club/t/$tagId', base),
        isNull,
        reason:
            'pre-release domain — dropped when t.lazytax.club became '
            'the single tag domain; those test stickers were binned',
      );
      expect(tagIdFromUrl('https://t.lazytax.club/x/$tagId', base), isNull);
      expect(tagIdFromUrl('https://t.lazytax.club/t/', base), isNull);
      expect(
        tagIdFromUrl('https://t.lazytax.club/t/ab', base),
        isNull,
        reason: 'too short',
      );
      expect(
        tagIdFromUrl('https://t.lazytax.club/t/$tagId/extra', base),
        isNull,
        reason: 'extra path segments',
      );
      expect(tagIdFromUrl('not a url at all ://', base), isNull);
    });

    test('rejects ids with characters outside zinc validation', () {
      expect(
        tagIdFromUrl('https://t.lazytax.club/t/abc_def_ghi', base),
        isNull,
        reason: 'underscores are outside ^[A-Za-z0-9-]{8,64}\$',
      );
    });
  });
}
