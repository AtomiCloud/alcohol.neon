import 'package:alcohol_neon/data/inbox_repository.dart';
import 'package:alcohol_neon/features/friends/friend_relation.dart';
import 'package:alcohol_neon/features/inbox/inbox_kind.dart';
import 'package:alcohol_neon/features/strava/strava_link.dart';
import 'package:alcohol_neon/features/strava/strava_settings.dart';
import 'package:alcohol_neon/features/subscription/tier.dart';
import 'package:flutter_test/flutter_test.dart';

const scheme = 'cloud.atomi.pichu.alcohol.neon.app';

InboxNotificationRes note(String kind, {String? data, String? actor}) =>
    InboxNotificationRes(
      id: '1',
      kind: kind,
      title: 't',
      body: 'b',
      data: data,
      actorUserId: actor,
    );

void main() {
  group('stravaResultFromUri', () {
    StravaLinkResult? parse(String s) =>
        stravaResultFromUri(Uri.parse(s), scheme);

    test('maps every zinc result', () {
      expect(
        parse('$scheme://strava?result=connected'),
        StravaLinkResult.connected,
      );
      expect(parse('$scheme://strava?result=denied'), StravaLinkResult.denied);
      expect(
        parse('$scheme://strava?result=scope_missing'),
        StravaLinkResult.scopeMissing,
      );
      expect(
        parse('$scheme://strava?result=athlete_taken'),
        StravaLinkResult.athleteTaken,
      );
      expect(
        parse('$scheme://strava?result=expired'),
        StravaLinkResult.expired,
      );
      expect(parse('$scheme://strava?result=error'), StravaLinkResult.error);
    });

    test('unknown or missing result is an error', () {
      expect(
        parse('$scheme://strava?result=new_thing'),
        StravaLinkResult.error,
      );
      expect(parse('$scheme://strava'), StravaLinkResult.error);
    });

    test('ignores the Logto callback, other schemes and tag links', () {
      expect(parse('$scheme://callback?code=abc'), isNull);
      expect(
        parse('cloud.atomi.raichu.alcohol.neon.app://strava?result=connected'),
        isNull,
      );
      expect(parse('https://t.lazytax.club/t/abc'), isNull);
    });
  });

  group('Strava settings', () {
    const schema =
        '{"type":"object","properties":{"sportTypes":{"type":"array",'
        '"minItems":1,"items":{"type":"string","enum":'
        '["AlpineSki","Ride","Run","TrailRun","Yoga"]}}},'
        '"required":["sportTypes"],"additionalProperties":false}';

    test('reads allowed sport types from the manifest, popular first', () {
      expect(sportTypesFromSchema(schema), [
        'Run',
        'TrailRun',
        'Ride',
        'Yoga',
        'AlpineSki',
      ]);
      expect(sportTypesFromSchema('not json'), isEmpty);
      expect(sportTypesFromSchema(null), isEmpty);
    });

    test('round-trips the settings JSON zinc expects', () {
      final json = encodeStravaSettings(['Run', 'TrailRun']);
      expect(json, '{"sportTypes":["Run","TrailRun"]}');
      expect(sportTypesFromSettings(json), ['Run', 'TrailRun']);
      expect(sportTypesFromSettings('{}'), isEmpty);
    });

    test('labels sport types', () {
      expect(sportTypeLabel('Run'), 'Run');
      expect(sportTypeLabel('TrailRun'), 'Trail run');
      expect(sportTypeLabel('EBikeRide'), 'E bike ride');
      expect(
        sportTypeLabel('HighIntensityIntervalTraining'),
        'High intensity interval training',
      );
    });
  });

  test('tierMeets gates on free < pro < ultimate, unknown allowed', () {
    expect(tierMeets('free', 'pro'), isFalse);
    expect(tierMeets('pro', 'pro'), isTrue);
    expect(tierMeets('ultimate', 'pro'), isTrue);
    expect(tierMeets('Pro', 'pro'), isTrue);
    expect(tierMeets('enterprise', 'pro'), isTrue);
    expect(tierMeets(null, 'pro'), isTrue);
    expect(tierMeets('free', null), isTrue);
  });

  test('friendActionFor maps relations to actions', () {
    expect(friendActionFor('none'), FriendAction.add);
    expect(friendActionFor('outgoing'), FriendAction.cancel);
    expect(friendActionFor('incoming'), FriendAction.accept);
    expect(friendActionFor('friend'), FriendAction.none);
    expect(friendActionFor('blocked'), FriendAction.none);
  });

  test('inviteCodeFrom accepts codes and links', () {
    expect(inviteCodeFrom(' ab23cdefgh '), 'ab23cdefgh');
    expect(inviteCodeFrom('AB23CDEFGH'), 'ab23cdefgh');
    expect(inviteCodeFrom('https://lazytax.club/f/ab23cdefgh'), 'ab23cdefgh');
    expect(inviteCodeFrom('lazytax.club/f/ab23cdefgh?x=1'), 'ab23cdefgh');
    expect(
      inviteCodeFrom('Join me https://lazytax.club/f/ab23cdefgh'),
      'ab23cdefgh',
    );
    expect(inviteCodeFrom(''), isNull);
    expect(inviteCodeFrom('https://lazytax.club/f/'), isNull);
    expect(inviteLink('ab23cdefgh'), 'https://lazytax.club/f/ab23cdefgh');
  });

  group('inboxKindOf', () {
    test('decodes the friend kinds from data JSON', () {
      final req = inboxKindOf(
        note('friend_request', data: '{"fromUserId":"u1"}'),
      );
      expect(req, isA<FriendRequestNotice>());
      expect((req as FriendRequestNotice).fromUserId, 'u1');

      final acc = inboxKindOf(
        note('friend_accepted', data: '{"friendUserId":"u2"}'),
      );
      expect((acc as FriendAcceptedNotice).friendUserId, 'u2');

      final missed = inboxKindOf(
        note(
          'friend_missed',
          data: '{"habitId":"h","userId":"u3","localDate":"2026-11-11"}',
        ),
      );
      expect((missed as FriendMissedNotice).userId, 'u3');
      expect(missed.localDate, '2026-11-11');
    });

    test('falls back to the actor, then to plain text', () {
      final req = inboxKindOf(note('friend_request', data: 'oops', actor: 'a'));
      expect((req as FriendRequestNotice).fromUserId, 'a');
      expect(inboxKindOf(note('friend_request')), isA<PlainNotice>());
      expect(
        inboxKindOf(note('weekly_digest', data: '{}')),
        isA<PlainNotice>(),
      );
    });
  });
}
