package cz.slowdownradijo.app.ui.theme

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

/**
 * The tablet column ([Theme.Layout.contentColumnWidth]), centred in whatever
 * width there is (`contentColumn()` in `Theme.swift`). Goes before a page's
 * horizontal padding, so the padding is part of the column, and after its
 * `verticalScroll`, so the whole width still scrolls.
 */
fun Modifier.contentColumn(): Modifier = this
    .fillMaxWidth()
    .wrapContentWidth(Alignment.CenterHorizontally)
    .widthIn(max = Theme.Layout.contentColumnWidth)
    .fillMaxWidth()
