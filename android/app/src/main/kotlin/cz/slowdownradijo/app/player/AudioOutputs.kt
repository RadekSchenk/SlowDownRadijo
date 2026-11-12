package cz.slowdownradijo.app.player

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaRouter2
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Where the radio plays: [name] for "Hraje na: …", [kind] with the iOS
 * analytics names, and [isElsewhere] when it is not the phone or wired
 * headphones (`OutputPickerButton.swift`).
 */
data class AudioOutputInfo(val name: String, val kind: String, val isElsewhere: Boolean) {
    companion object {
        val phone = AudioOutputInfo(Build.MODEL ?: "", "phone", false)
    }
}

object AudioOutputs {
    private val bluetooth = buildSet {
        add(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP); add(AudioDeviceInfo.TYPE_BLUETOOTH_SCO)
        if (Build.VERSION.SDK_INT >= 31) { add(AudioDeviceInfo.TYPE_BLE_HEADSET); add(AudioDeviceInfo.TYPE_BLE_SPEAKER) }
        if (Build.VERSION.SDK_INT >= 33) add(AudioDeviceInfo.TYPE_BLE_BROADCAST)
    }
    private val wired = setOf(
        AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_LINE_ANALOG,
    )
    private val hdmi = setOf(AudioDeviceInfo.TYPE_HDMI, AudioDeviceInfo.TYPE_HDMI_ARC)
    private val other = setOf(AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_ACCESSORY, AudioDeviceInfo.TYPE_DOCK)
    private val car = buildSet { if (Build.VERSION.SDK_INT >= 31) add(AudioDeviceInfo.TYPE_BUS) }

    /** The output media plays on now. */
    fun current(context: Context): AudioOutputInfo {
        val manager = context.getSystemService(AudioManager::class.java) ?: return AudioOutputInfo.phone
        val device = if (Build.VERSION.SDK_INT >= 33) {
            val media = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
            manager.getAudioDevicesForAttributes(media).firstOrNull()
        } else {
            // Before 13 the route isn't public: the output Android prefers for media.
            val outputs = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
            outputs.firstOrNull { it.type in bluetooth } ?: outputs.firstOrNull { it.type in wired }
                ?: outputs.firstOrNull { it.type in hdmi } ?: outputs.firstOrNull { it.type in other }
        }
        return describe(device?.type, device?.productName?.toString())
    }

    /** The output for a device type and name, as `OutputPickerButton.Output.current`. */
    fun describe(type: Int?, productName: String?): AudioOutputInfo {
        val name = productName?.takeIf { it.isNotBlank() && it != Build.MODEL } ?: AudioOutputInfo.phone.name
        return when (type) {
            null, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> AudioOutputInfo.phone
            in wired -> AudioOutputInfo(name, "wired", false)
            in bluetooth -> AudioOutputInfo(name, "bluetooth", true)
            in hdmi -> AudioOutputInfo(name, "hdmi", true)
            in car -> AudioOutputInfo(name, "carplay", true)
            else -> AudioOutputInfo(name, "other", true)
        }
    }

    /**
     * The system's output switcher, where Android has one: the media output
     * panel on 11+ (Bluetooth, and Cast speakers where the phone offers
     * them), else Bluetooth settings. The same steps as AndroidX MediaRouter's
     * `SystemOutputSwitcherDialogController`.
     */
    fun openSwitcher(context: Context) {
        if (Build.VERSION.SDK_INT >= 34 && runCatching { MediaRouter2.getInstance(context).showSystemOutputSwitcher() }.getOrDefault(false)) return
        if (Build.VERSION.SDK_INT >= 31) {
            context.sendBroadcast(
                Intent("com.android.systemui.action.LAUNCH_MEDIA_OUTPUT_DIALOG")
                    .setPackage("com.android.systemui")
                    .putExtra("package_name", context.packageName),
            )
            return
        }
        val panel = Intent("com.android.settings.panel.action.MEDIA_OUTPUT")
            .putExtra("com.android.settings.panel.extra.PACKAGE_NAME", context.packageName)
        for (intent in listOfNotNull(panel.takeIf { Build.VERSION.SDK_INT >= 30 }, Intent(Settings.ACTION_BLUETOOTH_SETTINGS))) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
    }
}

/** [AudioOutputs.current], kept up to date as outputs come and go. */
class AudioOutputWatcher(private val context: Context) {
    private val _output = MutableStateFlow(AudioOutputs.current(context))
    val output: StateFlow<AudioOutputInfo> = _output.asStateFlow()

    private val callback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>?) = refresh()
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>?) = refresh()
    }

    init {
        context.getSystemService(AudioManager::class.java)?.registerAudioDeviceCallback(callback, Handler(Looper.getMainLooper()))
    }

    /** Also on resume and at a picker tap: a switch between outputs already connected adds or removes none. */
    fun refresh() {
        _output.value = AudioOutputs.current(context)
    }
}
