package app.unrecorded.unrecorded_mobile.protocol

import android.content.Context
import android.content.SharedPreferences

/** Persistence surface used by [ProtectionProtocolRepository] (Android or in-memory test double). */
interface ProtectionProtocolPersistence {
    fun hasSchemaMarker(): Boolean
    fun readLegacySnapshot(): LegacySnapshot
    fun readTuple(): ProtectionProtocolTuple?
    fun writeFullTuple(tuple: ProtectionProtocolTuple): Boolean
}

/**
 * Reads/writes the Flutter SharedPreferences file with `flutter.`-prefixed keys.
 * Every accepted mutation must go through a single [SharedPreferences.Editor.commit].
 */
class AndroidProtectionProtocolPersistence(
    context: Context,
) : ProtectionProtocolPersistence {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(
            PREFS_FILE,
            Context.MODE_PRIVATE,
        )

    override fun hasSchemaMarker(): Boolean = prefs.contains(KEY_SCHEMA_VERSION)

    fun readSchemaVersion(): Int? {
        if (!prefs.contains(KEY_SCHEMA_VERSION)) return null
        return prefs.getLong(KEY_SCHEMA_VERSION, 0L).toInt()
    }

    override fun readLegacySnapshot(): LegacySnapshot {
        return LegacySnapshot(
            protectionEnabled = prefs.getBoolean(KEY_PROTECTION_ENABLED, false),
            backgroundProtectionEnabled =
                prefs.getBoolean(KEY_LEGACY_BACKGROUND_PROTECTION_ENABLED, false),
            explicitlyStopped =
                prefs.getBoolean(KEY_LEGACY_BACKGROUND_EXPLICITLY_STOPPED, false),
        )
    }

    override fun readTuple(): ProtectionProtocolTuple? {
        if (!hasSchemaMarker()) return null
        val schemaVersion = prefs.getLong(KEY_SCHEMA_VERSION, 0L).toInt()
        if (schemaVersion < 1) return null
        return ProtectionProtocolTuple(
            schemaVersion = schemaVersion,
            revision = prefs.getLong(KEY_REVISION, 0L),
            backgroundModePreferred = prefs.getBoolean(KEY_BACKGROUND_MODE_PREFERRED, false),
            protectionEnabled = prefs.getBoolean(KEY_PROTECTION_ENABLED, false),
            backgroundRuntimeEnabled = prefs.getBoolean(KEY_BACKGROUND_RUNTIME_ENABLED, false),
            explicitlyStopped = prefs.getBoolean(KEY_EXPLICITLY_STOPPED, false),
            activeTaskSessionId = prefs.getString(KEY_ACTIVE_TASK_SESSION_ID, null),
            activeTaskEpoch = optionalLong(KEY_ACTIVE_TASK_EPOCH),
            activeTaskIncarnationId = prefs.getString(KEY_ACTIVE_TASK_INCARNATION_ID, null),
            nextTaskGeneration = prefs.getLong(KEY_NEXT_TASK_GENERATION, 1L),
            activeStartAttemptId = prefs.getString(KEY_ACTIVE_START_ATTEMPT_ID, null),
            activeStartProcessId = prefs.getString(KEY_ACTIVE_START_PROCESS_ID, null),
            taskPhase = TaskPhase.fromWire(prefs.getString(KEY_TASK_PHASE, TaskPhase.NONE.wireName)),
            nativeStartUnresolved = prefs.getBoolean(KEY_NATIVE_START_UNRESOLVED, false),
        )
    }

    /**
     * Writes every canonical field plus legacy compatibility mirrors in one editor commit.
     * @return the Boolean result of [SharedPreferences.Editor.commit]
     */
    override fun writeFullTuple(tuple: ProtectionProtocolTuple): Boolean {
        val editor = prefs.edit()
        editor.putLong(KEY_SCHEMA_VERSION, tuple.schemaVersion.toLong())
        editor.putLong(KEY_REVISION, tuple.revision)
        editor.putBoolean(KEY_BACKGROUND_MODE_PREFERRED, tuple.backgroundModePreferred)
        editor.putBoolean(KEY_PROTECTION_ENABLED, tuple.protectionEnabled)
        editor.putBoolean(KEY_BACKGROUND_RUNTIME_ENABLED, tuple.backgroundRuntimeEnabled)
        editor.putBoolean(KEY_EXPLICITLY_STOPPED, tuple.explicitlyStopped)
        putNullableString(editor, KEY_ACTIVE_TASK_SESSION_ID, tuple.activeTaskSessionId)
        putNullableLong(editor, KEY_ACTIVE_TASK_EPOCH, tuple.activeTaskEpoch)
        putNullableString(editor, KEY_ACTIVE_TASK_INCARNATION_ID, tuple.activeTaskIncarnationId)
        editor.putLong(KEY_NEXT_TASK_GENERATION, tuple.nextTaskGeneration)
        putNullableString(editor, KEY_ACTIVE_START_ATTEMPT_ID, tuple.activeStartAttemptId)
        putNullableString(editor, KEY_ACTIVE_START_PROCESS_ID, tuple.activeStartProcessId)
        editor.putString(KEY_TASK_PHASE, tuple.taskPhase.wireName)
        editor.putBoolean(KEY_NATIVE_START_UNRESOLVED, tuple.nativeStartUnresolved)

        // Legacy mirrors: runtime permission + explicit Stop for older task code.
        editor.putBoolean(KEY_LEGACY_BACKGROUND_PROTECTION_ENABLED, tuple.backgroundRuntimeEnabled)
        editor.putBoolean(KEY_LEGACY_BACKGROUND_EXPLICITLY_STOPPED, tuple.explicitlyStopped)

        return editor.commit()
    }

    private fun optionalLong(key: String): Long? {
        if (!prefs.contains(key)) return null
        return prefs.getLong(key, 0L)
    }

    private fun putNullableString(editor: SharedPreferences.Editor, key: String, value: String?) {
        if (value == null) {
            editor.remove(key)
        } else {
            editor.putString(key, value)
        }
    }

    private fun putNullableLong(editor: SharedPreferences.Editor, key: String, value: Long?) {
        if (value == null) {
            editor.remove(key)
        } else {
            editor.putLong(key, value)
        }
    }

    companion object {
        const val PREFS_FILE = "FlutterSharedPreferences"

        const val KEY_SCHEMA_VERSION = "flutter.protection_protocol_schema_version"
        const val KEY_REVISION = "flutter.protection_protocol_revision"
        const val KEY_BACKGROUND_MODE_PREFERRED = "flutter.background_mode_preferred"
        const val KEY_PROTECTION_ENABLED = "flutter.protection_enabled"
        const val KEY_BACKGROUND_RUNTIME_ENABLED = "flutter.background_runtime_enabled"
        const val KEY_EXPLICITLY_STOPPED = "flutter.explicitly_stopped"
        const val KEY_ACTIVE_TASK_SESSION_ID = "flutter.active_task_session_id"
        const val KEY_ACTIVE_TASK_EPOCH = "flutter.active_task_epoch"
        const val KEY_ACTIVE_TASK_INCARNATION_ID = "flutter.active_task_incarnation_id"
        const val KEY_NEXT_TASK_GENERATION = "flutter.next_task_generation"
        const val KEY_ACTIVE_START_ATTEMPT_ID = "flutter.active_start_attempt_id"
        const val KEY_ACTIVE_START_PROCESS_ID = "flutter.active_start_process_id"
        const val KEY_TASK_PHASE = "flutter.task_phase"
        const val KEY_NATIVE_START_UNRESOLVED = "flutter.native_start_unresolved"

        const val KEY_LEGACY_BACKGROUND_PROTECTION_ENABLED =
            "flutter.background_protection_enabled"
        const val KEY_LEGACY_BACKGROUND_EXPLICITLY_STOPPED =
            "flutter.background_protection_explicitly_stopped"
    }
}
