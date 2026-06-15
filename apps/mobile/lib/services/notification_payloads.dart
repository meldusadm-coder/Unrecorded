// Notification tap payloads shared across main and background isolates.
// Router-free: no navigation imports.

/// Payload for taps on a possible-risk alert notification.
const notificationAlertPayload = 'alert-details';

/// Payload for taps on the ongoing protection-status notification.
const notificationProtectionStatusPayload = 'protection-status';

/// Payload for taps when the protection notification shows a recent-risk reminder.
const notificationRecentRiskPayload = 'recent-risk';
