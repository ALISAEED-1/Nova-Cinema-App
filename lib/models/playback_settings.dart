/// Playback preferences from the web profile page's toggles.
class PlaybackSettings {
  const PlaybackSettings({
    this.autoplayNext = true,
    this.autoplayPreviews = true,
  });

  final bool autoplayNext;
  final bool autoplayPreviews;

  PlaybackSettings copyWith({bool? autoplayNext, bool? autoplayPreviews}) =>
      PlaybackSettings(
        autoplayNext: autoplayNext ?? this.autoplayNext,
        autoplayPreviews: autoplayPreviews ?? this.autoplayPreviews,
      );

  Map<String, dynamic> toJson() => {
        'autoplayNext': autoplayNext,
        'autoplayPreviews': autoplayPreviews,
      };

  factory PlaybackSettings.fromJson(Map<String, dynamic> json) =>
      PlaybackSettings(
        autoplayNext: json['autoplayNext'] as bool? ?? true,
        autoplayPreviews: json['autoplayPreviews'] as bool? ?? true,
      );
}
