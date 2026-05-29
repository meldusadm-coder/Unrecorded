# Detection limitations

Unrecorded detects possible nearby smart glasses or wearable recording devices. It **cannot** prove that any device is recording.

## Why detection is probabilistic

- **Bluetooth visibility varies.** Devices may hide their name, randomise their address, or stop advertising altogether.
- **Android and iOS capabilities differ.** iOS restricts background BLE scanning more than Android. Results may vary between platforms.
- **Device names may be hidden or randomised.** Manufacturers and operating systems can mask device identity at the firmware or OS level.
- **RSSI is noisy.** Signal strength changes with distance, orientation, obstacles, and interference. A strong signal does not guarantee proximity; a weak one does not guarantee distance.
- **Smart glasses may not advertise recognisable names.** Future devices or firmware updates could change advertised names at any time.
- **Alerts are risk signals, not proof of recording.** A high-risk alert means the app found patterns that match known recording devices — it does not confirm that recording is happening.

## What the app can detect

- BLE advertisements from nearby devices.
- Device names, optional BLE service UUID hints, and Bluetooth address prefixes that match a local catalogue of known smart-glasses signatures.
- Each catalogue entry includes a confidence weight and a plain-English explanation. Matches are risk signals, not proof of recording.

## Catalogue limitations

- The catalogue is maintained locally in the app. It cannot cover every device or future firmware rename.
- Generic name phrases (for example “smart glasses”) are weighted lower than brand-specific matches to reduce false positives.
- Service UUID and address-prefix hints are optional and may be missing even for known devices.
- Benign device names (headphones, speakers, fitness trackers) are filtered before catalogue matching where possible.

## What the app cannot detect

- Devices that do not use Bluetooth or that suppress BLE advertising.
- Whether a matched device is actually recording.
- Non-BLE cameras, microphones, or other recording hardware.
