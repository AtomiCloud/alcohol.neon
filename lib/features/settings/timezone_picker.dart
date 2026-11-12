import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_page.dart';

/// Offline IANA choices when platform discovery is unavailable.
List<String> bundledTimezones() {
  tzdata.initializeTimeZones();
  return tz.timeZoneDatabase.locations.keys.toList()..sort();
}

const timezoneDiscoveryNotice =
    'Device timezone discovery is unavailable. Choose your region from the '
    'bundled timezone list, or retry discovery. Your selection is kept.';

/// Searchable IANA timezone list, grouped by region (Asia, Europe, …) with
/// the city as each row. Returns the chosen identifier (e.g.
/// `Asia/Singapore`) via `Navigator.pop`.
class TimezonePicker extends StatefulWidget {
  final List<String> timezones;
  final String? selected;
  const TimezonePicker({super.key, required this.timezones, this.selected});

  @override
  State<TimezonePicker> createState() => _TimezonePickerState();
}

class _TimezonePickerState extends State<TimezonePicker> {
  String _query = '';

  /// Matching zones by region, in the list's order. A zone without a region,
  /// such as `UTC`, goes under Other.
  Map<String, List<String>> get _groups {
    final q = _query.trim().toLowerCase().replaceAll(' ', '_');
    final groups = <String, List<String>>{};
    for (final id in widget.timezones) {
      if (q.isNotEmpty && !id.toLowerCase().contains(q)) continue;
      final slash = id.indexOf('/');
      final region = slash < 0 ? 'Other' : id.substring(0, slash);
      groups.putIfAbsent(region, () => []).add(id);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final t = GlassTokens.of(context);
    return GlassPage(
      title: 'Timezone',
      children: [
        const SizedBox(height: 4),
        GlassSearchField(
          hint: 'Search cities',
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Text(
              'No timezones found',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.muted),
            ),
          ),
        for (final MapEntry(key: region, value: ids) in groups.entries)
          GlassSection(
            title: region.replaceAll('_', ' '),
            dividerIndent: 16,
            children: [for (final id in ids) _row(context, id)],
          ),
      ],
    );
  }

  Widget _row(BuildContext context, String id) {
    final parts = id.split('/');
    final city = parts.last.replaceAll('_', ' ');
    final area = parts.length > 2
        ? parts.sublist(1, parts.length - 1).join(', ').replaceAll('_', ' ')
        : null;
    final selected = id == widget.selected;
    return GlassRow(
      key: ValueKey(id),
      title: city,
      subtitle: area,
      chevron: false,
      trailing: selected
          ? Icon(Icons.check_rounded, color: GlassTokens.of(context).accent)
          : null,
      onTap: () => Navigator.pop(context, id),
    );
  }
}
