/// How a nearby BLE signal relates to possible recording wearables.
enum DeviceSignalCategory {
  /// Name or address hints match smart glasses / wearable recording patterns.
  possibleRecordingWearable,

  /// No strong match either way (still shown in main nearby list).
  unknown,

  /// Name strongly suggests headphones, speakers, etc. (unlikely recording).
  likelyBenign,
}
