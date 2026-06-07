import 'package:flutter/material.dart';

/// Searchable IANA timezone list. Returns the chosen identifier (e.g.
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

  List<String> get _filtered {
    if (_query.trim().isEmpty) return widget.timezones;
    final q = _query.toLowerCase();
    return widget.timezones.where((t) => t.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your timezone')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search timezones',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No timezones found'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final tz = items[i];
                      final selected = tz == widget.selected;
                      return ListTile(
                        title: Text(tz.replaceAll('_', ' ')),
                        trailing: selected
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, tz),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
