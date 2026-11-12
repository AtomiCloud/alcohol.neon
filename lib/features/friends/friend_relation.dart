/// What the app offers for a search hit, from zinc's relation.
enum FriendAction {
  /// `none`: send a request.
  add,

  /// `outgoing`: you asked them; cancel the request.
  cancel,

  /// `incoming`: they asked you; accept.
  accept,

  /// `friend` (or a relation this build doesn't know): nothing to do.
  none,
}

FriendAction friendActionFor(String relation) => switch (relation) {
  'none' => FriendAction.add,
  'outgoing' => FriendAction.cancel,
  'incoming' => FriendAction.accept,
  _ => FriendAction.none,
};

/// Where invite links point; the code is the last path segment.
const inviteLinkBase = 'https://lazytax.club/f/';

String inviteLink(String code) => '$inviteLinkBase$code';

/// A pasted invite code or link (`https://lazytax.club/f/{code}`, with or
/// without the scheme) → the code, lower-cased like zinc stores it. Null when
/// nothing code-like is left.
String? inviteCodeFrom(String input) {
  var s = input.trim();
  final i = s.toLowerCase().lastIndexOf('/f/');
  if (i >= 0) s = s.substring(i + 3);
  s = s.split(RegExp(r'[/?#\s]')).first.toLowerCase();
  return RegExp(r'^[a-z0-9]{4,32}$').hasMatch(s) ? s : null;
}
