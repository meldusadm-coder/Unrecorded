/// How a nearby BLE signal relates to possible recording wearables.
enum DeviceSignalCategory {
  /// Name or address hints match smart glasses / wearable recording patterns.
  possibleRecordingWearable,

  /// No strong match either way (still shown in main nearby list).
  unknown,

  /// Headphones, earbuds, speakers.
  likelyAudio,

  /// Keyboard, mouse, trackpad.
  likelyInput,

  /// TV, streaming, media devices.
  likelyMediaTv,

  /// Fitness trackers, watches (non-recording wearable).
  likelyWearableFitness,

  /// Car audio / vehicle infotainment.
  likelyVehicle,

  /// Legacy alias — maps to [likelyAudio] in UI where needed.
  likelyBenign,
}

extension DeviceSignalCategoryLabels on DeviceSignalCategory {
  String get displayLabel => switch (this) {
        DeviceSignalCategory.possibleRecordingWearable =>
          'Possible recording wearable',
        DeviceSignalCategory.unknown => 'Unknown nearby device',
        DeviceSignalCategory.likelyAudio => 'Likely audio device',
        DeviceSignalCategory.likelyInput => 'Likely input device',
        DeviceSignalCategory.likelyMediaTv => 'Likely TV or media device',
        DeviceSignalCategory.likelyWearableFitness => 'Likely fitness or watch',
        DeviceSignalCategory.likelyVehicle => 'Likely vehicle',
        DeviceSignalCategory.likelyBenign => 'Likely audio device',
      };

  bool get isOtherNearby =>
      this != DeviceSignalCategory.possibleRecordingWearable;
}
