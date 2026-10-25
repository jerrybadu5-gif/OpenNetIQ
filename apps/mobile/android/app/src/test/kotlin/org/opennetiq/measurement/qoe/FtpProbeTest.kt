package org.opennetiq.measurement.qoe

import org.apache.ftpserver.FtpServer
import org.apache.ftpserver.FtpServerFactory
import org.apache.ftpserver.ftplet.Authority
import org.apache.ftpserver.listener.ListenerFactory
import org.apache.ftpserver.usermanager.PropertiesUserManagerFactory
import org.apache.ftpserver.usermanager.impl.BaseUser
import org.apache.ftpserver.usermanager.impl.WritePermission
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.net.ServerSocket
import kotlin.random.Random

class FtpProbeTest {
    @get:Rule val tmp = TemporaryFolder()

    private lateinit var server: FtpServer
    private lateinit var root: File
    private var port = 0
    private val probe = FtpProbe()

    private fun freePort() = ServerSocket(0).use { it.localPort }

    @Before
    fun start() {
        root = tmp.newFolder("ftp")
        File(root, "download").mkdirs()
        File(root, "upload").mkdirs()
        File(root, "download/5MB.bin").writeBytes(Random.nextBytes(5 * 1024 * 1024))
        port = freePort()
        val factory = FtpServerFactory()
        factory.addListener("default", ListenerFactory().apply { this.port = this@FtpProbeTest.port }.createListener())
        val users = PropertiesUserManagerFactory().apply { file = tmp.newFile("users.properties") }.createUserManager()
        users.save(
            BaseUser().apply {
                name = "onq"
                password = "secret-pass-123"
                homeDirectory = root.absolutePath
                authorities = listOf<Authority>(WritePermission())
            },
        )
        factory.userManager = users
        server = factory.createServer().also { it.start() }
    }

    @After
    fun stop() = server.stop()

    private fun url() = "ftp://127.0.0.1:$port/"

    @Test
    fun `download reports bytes timings and rate`() {
        val r = probe.run(url(), "onq", "secret-pass-123", upload = false, sizeMib = 5, maxMs = 60_000)
        assertNull(r["error"])
        assertEquals("ftp", r["protocol"])
        assertEquals("download", r["direction"])
        assertEquals(5L * 1024 * 1024, r["bytes"])
        assertTrue((r["rate_mbps"] as Double) > 0)
        assertNotNull(r["connect_ms"])
        assertNotNull(r["ttfb_ms"])
        assertTrue((r["total_ms"] as Double) >= (r["ttfb_ms"] as Double))
    }

    @Test
    fun `upload stores the file then deletes it`() {
        val r = probe.run(url(), "onq", "secret-pass-123", upload = true, sizeMib = 5, maxMs = 60_000)
        assertNull(r["error"])
        assertEquals("upload", r["direction"])
        assertEquals(5L * 1024 * 1024, r["bytes"])
        assertTrue((r["rate_mbps"] as Double) > 0)
        assertEquals(0, File(root, "upload").listFiles()!!.size)
    }

    @Test
    fun `wrong password missing file and bad input fail with a reason`() {
        assertEquals("Login failed", probe.run(url(), "onq", "nope", false, 5, 10_000)["error"])
        val missing = probe.run(url(), "onq", "secret-pass-123", false, 10, 10_000)["error"] as String
        assertTrue(missing, missing.startsWith("Download refused"))
        assertEquals("Invalid FTP URL", probe.run("http://x/", "u", "p", false, 5, 1_000)["error"])
        assertTrue((probe.run(url(), "u", "p", false, 7, 1_000)["error"] as String).startsWith("Size must be"))
        val closed = probe.run("ftp://127.0.0.1:${freePort()}/", "u", "p", false, 5, 1_000)
        assertNotNull(closed["error"])
    }

    @Test
    fun `slow transfer is cut off with partial bytes`() {
        var t = 0L
        val slow = FtpProbe(clock = { t += 50_000_000; t }) // every clock read: +50 ms
        val r = slow.run(url(), "onq", "secret-pass-123", false, 5, maxMs = 1_000)
        assertTrue(r["error"] as String, (r["error"] as String).startsWith("Cut off after"))
        assertTrue((r["bytes"] as Long) < 5L * 1024 * 1024)
    }

    @Test
    fun `url parsing and rate`() {
        assertEquals(FtpProbe.Target("h", 21, "/"), FtpProbe.parse("ftp://h"))
        assertEquals(FtpProbe.Target("h", 2121, "/onq/"), FtpProbe.parse("FTP://h:2121/onq"))
        assertNull(FtpProbe.parse("ftp://user:pw@h/"))
        assertNull(FtpProbe.parse("ftp:// bad"))
        assertEquals(8.0, FtpProbe.mbps(1_000_000, 1000.0), 1e-9)
    }
}
