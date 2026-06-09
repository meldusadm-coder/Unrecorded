import 'detection_signature.dart';

/// Local catalogue of known smart-glasses / wearable recording indicators.
///
/// Update this list to add brands or refine keywords — scoring rules read from
/// here instead of hard-coded lists in rule classes.
const List<DetectionSignature> detectionSignatures = [
  DetectionSignature(
    id: 'meta-ray-ban',
    brandFamily: 'Meta / Ray-Ban',
    nameKeywords: [
      'ray-ban',
      'meta smart glasses',
      'meta glasses',
      'stories',
    ],
    macPrefixHints: ['000b9a', 'e45f01'],
    confidenceWeight: 35,
    matchExplanation:
        'A nearby device may match Meta or Ray-Ban smart glasses based on '
        'its advertised name or address pattern.',
    macPrefixExplanation:
        'A nearby Bluetooth address prefix may match Meta or Ray-Ban smart '
        'glasses. Address hints are not proof of a specific device.',
    sourceNote:
        'Address-prefix hints from existing repo catalogue; weak supporting '
        'evidence only, not proof of identity or recording.',
  ),
  DetectionSignature(
    id: 'snap-spectacles',
    brandFamily: 'Snap / Spectacles',
    nameKeywords: [
      'spectacles',
      'snap stories',
      'snap glasses',
    ],
    macPrefixHints: ['acbc32', 'f4a739'],
    confidenceWeight: 35,
    matchExplanation:
        'A nearby device may match Snap Spectacles based on its advertised '
        'name or address pattern.',
    macPrefixExplanation:
        'A nearby Bluetooth address prefix may match Snap Spectacles. '
        'Address hints are not proof of a specific device.',
    sourceNote:
        'Address-prefix hints from existing repo catalogue; weak supporting '
        'evidence only, not proof of identity or recording.',
  ),
  DetectionSignature(
    id: 'even-realities',
    brandFamily: 'Even Realities',
    nameKeywords: ['even realities'],
    confidenceWeight: 35,
    matchExplanation:
        'A nearby device name may match Even Realities smart glasses.',
  ),
  DetectionSignature(
    id: 'focals',
    brandFamily: 'Focals',
    nameKeywords: ['focals'],
    confidenceWeight: 35,
    matchExplanation: 'A nearby device name may match Focals smart glasses.',
  ),
  DetectionSignature(
    id: 'vuzix',
    brandFamily: 'Vuzix',
    nameKeywords: ['vuzix'],
    confidenceWeight: 35,
    matchExplanation: 'A nearby device name may match Vuzix smart glasses.',
  ),
  DetectionSignature(
    id: 'xreal',
    brandFamily: 'Xreal',
    nameKeywords: ['xreal', 'nreal'],
    confidenceWeight: 35,
    matchExplanation: 'A nearby device name may match Xreal smart glasses.',
  ),
  DetectionSignature(
    id: 'inmo',
    brandFamily: 'INMO',
    nameKeywords: ['inmo'],
    confidenceWeight: 35,
    matchExplanation: 'A nearby device name may match INMO smart glasses.',
  ),
  DetectionSignature(
    id: 'tcl-rayneo',
    brandFamily: 'TCL RayNeo',
    nameKeywords: ['tcl rayneo', 'rayneo'],
    confidenceWeight: 30,
    matchExplanation:
        'A nearby device name may match TCL RayNeo smart glasses.',
  ),
  DetectionSignature(
    id: 'solos',
    brandFamily: 'Solos',
    nameKeywords: ['solos'],
    confidenceWeight: 35,
    matchExplanation: 'A nearby device name may match Solos smart glasses.',
  ),
  DetectionSignature(
    id: 'generic-smart-glasses',
    brandFamily: 'Smart glasses (generic)',
    nameKeywords: ['smart glasses'],
    confidenceWeight: 25,
    matchExplanation:
        'A nearby device name includes a generic smart-glasses phrase. '
        'This may indicate a wearable camera but could also be unrelated.',
  ),
  DetectionSignature(
    id: 'generic-recording-wearable',
    brandFamily: 'Wearable camera (generic)',
    nameKeywords: [
      'camera glasses',
      'glasses camera',
      'wearable camera',
    ],
    confidenceWeight: 20,
    matchExplanation:
        'A nearby device name suggests a wearable camera. The match is '
        'generic and may not indicate smart glasses specifically.',
  ),
];

/// Name keywords that commonly indicate headphones, speakers, or other
/// benign peripherals. Checked before catalogue matching to reduce false
/// positives from broad phrases.
const List<String> benignNameKeywords = [
  'earbud',
  'earbuds',
  'airpod',
  'airpods',
  'headphone',
  'headphones',
  'beats',
  'jbl',
  'bose',
  'sony wh',
  'speaker',
  'soundbar',
  'sound bar',
  'keyboard',
  'mouse',
  'trackpad',
  'television',
  ' smart tv',
  ' roku',
  'chromecast',
  'fitbit',
  'garmin',
  'whoop',
];
