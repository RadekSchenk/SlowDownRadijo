package cz.slowdownradijo.app

import android.app.Application
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.l10n.LanguageStore

class SlowDownApp : Application() {
    val schedule by lazy { ScheduleStore(ScheduleStore.bundled(this)) }
    val language by lazy { LanguageStore(this) }
}

val android.content.Context.app get() = applicationContext as SlowDownApp
