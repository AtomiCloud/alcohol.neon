/// Pure NDEF "U" (well-known URI) record codec — kept free of plugin types so
/// the parsing logic is unit-testable. NFC Forum URI records store a 1-byte
/// abbreviation code followed by the rest of the URI (RTD-URI spec).
library;

import 'dart:convert';
import 'dart:typed_data';

/// RTD-URI prefix table, indexed by the payload's first byte.
const List<String> ndefUriPrefixes = [
  '', // 0x00: no abbreviation
  'http://www.', // 0x01
  'https://www.', // 0x02
  'http://', // 0x03
  'https://', // 0x04
  'tel:', // 0x05
  'mailto:', // 0x06
  'ftp://anonymous:anonymous@', // 0x07
  'ftp://ftp.', // 0x08
  'ftps://', // 0x09
  'sftp://', // 0x0A
  'smb://', // 0x0B
  'nfs://', // 0x0C
  'ftp://', // 0x0D
  'dav://', // 0x0E
  'news:', // 0x0F
  'telnet://', // 0x10
  'imap:', // 0x11
  'rtsp://', // 0x12
  'urn:', // 0x13
  'pop:', // 0x14
  'sip:', // 0x15
  'sips:', // 0x16
  'tftp:', // 0x17
  'btspp://', // 0x18
  'btl2cap://', // 0x19
  'btgoep://', // 0x1A
  'tcpobex://', // 0x1B
  'irdaobex://', // 0x1C
  'file://', // 0x1D
  'urn:epc:id:', // 0x1E
  'urn:epc:tag:', // 0x1F
  'urn:epc:pat:', // 0x20
  'urn:epc:raw:', // 0x21
  'urn:epc:', // 0x22
  'urn:nfc:', // 0x23
];

/// Decodes a well-known "U" record payload into a URI string, or null when the
/// payload is empty/malformed.
String? decodeNdefUriPayload(Uint8List payload) {
  if (payload.isEmpty) return null;
  final code = payload[0];
  final prefix = code < ndefUriPrefixes.length ? ndefUriPrefixes[code] : '';
  final rest = utf8.decode(payload.sublist(1), allowMalformed: true);
  final uri = '$prefix$rest';
  return uri.isEmpty ? null : uri;
}

/// Extracts the tag id from a URI written on one of our tags: the single path
/// segment after `<base>` (e.g. `https://lazytax.club/t/<id>`). Returns null
/// when the URI isn't ours. Tolerates a trailing slash and http/https +
/// with/without `www.` variations of the same host.
String? tagIdFromUrl(String url, Uri base) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  String canonicalHost(String host) =>
      host.startsWith('www.') ? host.substring(4) : host;
  if (canonicalHost(uri.host) != canonicalHost(base.host)) return null;

  final baseSegments = base.pathSegments.where((s) => s.isNotEmpty).toList();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != baseSegments.length + 1) return null;
  for (var i = 0; i < baseSegments.length; i++) {
    if (segments[i] != baseSegments[i]) return null;
  }

  final id = segments.last;
  // Match zinc's tag id validation so we never round-trip an id it rejects.
  final valid = RegExp(r'^[A-Za-z0-9-]{8,64}$');
  return valid.hasMatch(id) ? id : null;
}
