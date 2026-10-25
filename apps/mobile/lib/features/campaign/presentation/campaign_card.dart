import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/campaign_tags.dart';
import 'package:opennetiq_mobile/features/campaign/application/campaign_controller.dart';

/// Shows and edits the campaign tags applied to new sessions.
class CampaignTagsCard extends ConsumerWidget {
  const CampaignTagsCard({this.enabled = true, super.key});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(campaignTagsProvider).value ?? CampaignTags.none;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.place_outlined),
        title: Text(
          tags.isEmpty ? 'Measurement location not set' : tags.summary,
        ),
        subtitle: const Text(
          'Region, area and location saved with new sessions for reports',
        ),
        trailing: TextButton(
          onPressed: enabled ? () => edit(context, ref, tags) : null,
          child: const Text('Edit'),
        ),
      ),
    );
  }

  static Future<void> edit(
    BuildContext context,
    WidgetRef ref,
    CampaignTags current,
  ) async {
    final saved = await showDialog<CampaignTags>(
      context: context,
      builder: (context) => CampaignTagsDialog(initial: current),
    );
    if (saved != null) {
      await ref.read(campaignTagsProvider.notifier).save(saved);
    }
  }
}

class CampaignTagsDialog extends StatefulWidget {
  const CampaignTagsDialog({required this.initial, super.key});

  final CampaignTags initial;

  @override
  State<CampaignTagsDialog> createState() => _CampaignTagsDialogState();
}

class _CampaignTagsDialogState extends State<CampaignTagsDialog> {
  late final TextEditingController _region = TextEditingController(
    text: widget.initial.region ?? '',
  );
  late final TextEditingController _location = TextEditingController(
    text: widget.initial.location ?? '',
  );
  late AreaClass? _area = widget.initial.areaClass;

  @override
  void dispose() {
    _region.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Measurement location'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _region,
            decoration: const InputDecoration(labelText: 'Region'),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final r in pngRegions)
                ActionChip(
                  label: Text(r),
                  onPressed: () => setState(() => _region.text = r),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Area', style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 6,
            children: [
              for (final a in AreaClass.values)
                ChoiceChip(
                  label: Text(a.label),
                  selected: _area == a,
                  onSelected: (on) => setState(() => _area = on ? a : null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Location name',
              hintText: 'e.g. Waigani',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(CampaignTags.none),
        child: const Text('Clear'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(
          CampaignTags(
            region: _region.text,
            areaClass: _area,
            location: _location.text,
          ).normalised(),
        ),
        child: const Text('Save'),
      ),
    ],
  );
}
