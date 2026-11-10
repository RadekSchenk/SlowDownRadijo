package cz.slowdownradijo.app.news

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Against real posts from slowdownradijo.cz (fixture saved 10 Nov 2026). */
class NewsTest {
    private val posts = NewsService.parse(javaClass.classLoader!!.getResource("web/posts.json")!!.readText())

    @Test fun `posts parse with plain titles, dates and photos`() {
        assertEquals(5, posts.size)
        assertEquals("Vyhraj vinyl Thundercat – Distracted", posts[0].title)
        assertTrue(posts.all { it.dateGmt.epochSecond > 1_700_000_000 })
        assertTrue(posts.any { it.imageUrl != null })
    }

    @Test fun `content splits into paragraphs, images and videos`() {
        val blocks = posts.flatMap { it.blocks }
        assertTrue(blocks.any { it is NewsBlock.Paragraph })
        assertTrue(blocks.any { it is NewsBlock.Image })
        assertTrue(blocks.any { it is NewsBlock.Video })
        assertTrue(blocks.filterIsInstance<NewsBlock.Paragraph>().none { it.text.contains("<") || it.text.contains("&#") })
    }

    @Test fun `parser by hand`() {
        val blocks = NewsContentParser.parse("""<p>One &amp; two</p><p><img src="https://x/a.jpg" alt=""></p><p>Line<br/>break</p><iframe src="https://youtube.com/embed/1"></iframe>""")
        assertEquals(
            listOf(NewsBlock.Paragraph("One & two"), NewsBlock.Image("https://x/a.jpg"), NewsBlock.Paragraph("Line\nbreak"), NewsBlock.Video("https://youtube.com/embed/1")),
            blocks,
        )
    }
}
