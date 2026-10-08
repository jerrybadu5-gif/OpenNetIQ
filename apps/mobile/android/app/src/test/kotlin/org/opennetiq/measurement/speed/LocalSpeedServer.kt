package org.opennetiq.measurement.speed

import mockwebserver3.Dispatcher
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import mockwebserver3.RecordedRequest
import okio.Buffer
import java.io.Closeable

/**
 * In-process LibreSpeed-compatible server for engine tests:
 * `/backend/garbage.php?ckSize=N` and `/backend/empty.php`.
 */
class LocalSpeedServer(private val failWith: Int? = null) : Closeable {
    private val server = MockWebServer()

    @Volatile
    var uploadedBytes = 0L
        private set

    init {
        val chunk = ByteArray(1024 * 1024) { (it * 31 + 7).toByte() }
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                val failure = failWith
                if (failure != null) {
                    return MockResponse.Builder().code(failure).build()
                }

                return when (request.url.encodedPath) {
                    "/backend/garbage.php" -> {
                        val mib = request.url.queryParameter("ckSize")?.toIntOrNull() ?: 1
                        val body = Buffer()
                        repeat(mib) { body.write(chunk) }
                        MockResponse.Builder().code(200).body(body).build()
                    }
                    "/backend/empty.php" -> {
                        synchronized(this@LocalSpeedServer) {
                            uploadedBytes += request.body?.size?.toLong() ?: 0L
                        }
                        MockResponse.Builder().code(200).build()
                    }
                    else -> MockResponse.Builder().code(404).build()
                }
            }
        }
        server.start()
    }

    val baseUrl: String
        get() = "http://127.0.0.1:${server.port}/backend/"

    override fun close() {
        server.close()
    }
}
