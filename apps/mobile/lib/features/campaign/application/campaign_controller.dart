import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/campaign_tags.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

/// `app_settings` key of the current [CampaignTags] JSON.
const String campaignTagsKey = 'campaign.tags.v1';

/// Tags given to every new session (recordings and stand-alone tests).
class CampaignTagsController extends AsyncNotifier<CampaignTags> {
  @override
  Future<CampaignTags> build() async {
    final raw = await ref
        .watch(settingsRepositoryProvider)
        .getSetting(campaignTagsKey);
    if (raw == null || raw.isEmpty) return CampaignTags.none;
    try {
      return CampaignTags.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return CampaignTags.none;
    }
  }

  Future<void> save(CampaignTags tags) async {
    final clean = tags.normalised();
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(campaignTagsKey, jsonEncode(clean.toJson()));
    state = AsyncData(clean);
  }
}

final campaignTagsProvider =
    AsyncNotifierProvider<CampaignTagsController, CampaignTags>(
      CampaignTagsController.new,
    );

/// Current tags for a new session; untagged if they cannot be read, so a
/// settings problem never blocks a measurement.
Future<CampaignTags> currentCampaignTags(Ref ref) async {
  try {
    return await ref.read(campaignTagsProvider.future);
  } on Object {
    return CampaignTags.none;
  }
}
