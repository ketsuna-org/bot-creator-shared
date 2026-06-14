import 'package:nyxx/nyxx.dart';

/// A custom [MessageUpdateBuilder] that allows appending or setting custom message flags.
/// This is necessary because the default [MessageUpdateBuilder] in nyxx does not expose
/// a parameter to specify custom flags (such as the IS_COMPONENTS_V2 flag).
class CustomMessageUpdateBuilder extends MessageUpdateBuilder {
  final int? customFlags;

  CustomMessageUpdateBuilder({
    super.content,
    super.embeds,
    super.suppressEmbeds,
    super.allowedMentions,
    super.components,
    super.attachments,
    super.poll,
    this.customFlags,
  });

  @override
  Map<String, Object?> build() {
    final base = Map<String, Object?>.from(super.build());
    if (customFlags != null) {
      base['flags'] = (base['flags'] as int? ?? 0) | customFlags!;
    }
    return base;
  }
}
