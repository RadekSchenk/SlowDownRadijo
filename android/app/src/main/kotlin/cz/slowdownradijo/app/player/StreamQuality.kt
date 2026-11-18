package cz.slowdownradijo.app.player

/**
 * The two live mounts on play.cz, both over HTTPS, as `LiveStream` on iOS.
 * The `-fallback` mounts next to them are Icecast's own backup sources, not
 * for listeners.
 */
enum class LiveStream(val id: String, val url: String) {
    /** MP3, 160 kbps, 44.1 kHz stereo (~72 MB an hour). */
    MP3("mp3", "https://icecast9.play.cz/slowdown.mp3"),

    /** HE-AAC, 32 kbps (~14 MB an hour). */
    AAC("aac", "https://icecast5.play.cz/slowdown.aac");

    val other: LiveStream get() = if (this == MP3) AAC else MP3
}

/**
 * Settings ▸ Kvalita zvuku, as `StreamQuality` on iOS. [AUTO] plays the MP3
 * on a network that isn't metered (Wi-Fi, Ethernet) and the AAC on mobile
 * data or a hotspot.
 */
enum class StreamQuality(val id: String) {
    AUTO("auto"), HIGH("high"), LOW("low");

    fun stream(metered: Boolean): LiveStream = when (this) {
        AUTO -> if (metered) LiveStream.AAC else LiveStream.MP3
        HIGH -> LiveStream.MP3
        LOW -> LiveStream.AAC
    }

    companion object {
        fun fromId(id: String?): StreamQuality = entries.firstOrNull { it.id == id } ?: AUTO
    }
}
