package cz.slowdownradijo.app.player

import android.media.AudioDeviceInfo
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class AudioOutputsTest {
    @Test fun `phone and wired headphones are home, the rest is elsewhere`() {
        assertEquals(AudioOutputInfo.phone, AudioOutputs.describe(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, "speaker"))
        assertEquals(AudioOutputInfo.phone, AudioOutputs.describe(null, null))
        assertEquals(AudioOutputInfo("Sennheiser", "wired", false), AudioOutputs.describe(AudioDeviceInfo.TYPE_WIRED_HEADPHONES, "Sennheiser"))
        assertEquals(AudioOutputInfo("JBL Charge 3", "bluetooth", true), AudioOutputs.describe(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, "JBL Charge 3"))
        assertEquals(AudioOutputInfo("TV", "hdmi", true), AudioOutputs.describe(AudioDeviceInfo.TYPE_HDMI, "TV"))
    }

    @Test fun `a nameless device is named after the phone`() {
        assertEquals(AudioOutputInfo.phone.name, AudioOutputs.describe(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, " ").name)
    }

    @Test fun `the phone plays by default`() {
        assertEquals("phone", AudioOutputs.current(ApplicationProvider.getApplicationContext()).kind)
    }
}
