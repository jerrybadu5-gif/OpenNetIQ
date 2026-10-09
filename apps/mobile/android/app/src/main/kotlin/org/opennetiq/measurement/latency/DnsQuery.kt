package org.opennetiq.measurement.latency

import java.io.ByteArrayOutputStream

/** Minimal DNS wire format for latency probes (RFC 1035): one A query. */
object DnsQuery {
    fun build(id: Int, name: String): ByteArray {
        val out = ByteArrayOutputStream()
        fun u16(v: Int) {
            out.write((v shr 8) and 0xFF)
            out.write(v and 0xFF)
        }
        u16(id)
        u16(0x0100) // standard query, recursion desired
        u16(1) // QDCOUNT
        u16(0)
        u16(0)
        u16(0)
        for (label in name.trimEnd('.').split('.')) {
            val bytes = label.toByteArray(Charsets.US_ASCII)
            require(bytes.size in 1..63) { "Invalid DNS label" }
            out.write(bytes.size)
            out.write(bytes)
        }
        out.write(0)
        u16(1) // QTYPE A
        u16(1) // QCLASS IN
        return out.toByteArray()
    }

    /** True when [packet] is a response (QR set) to query [id]. Any RCODE counts as an answer. */
    fun isResponseTo(packet: ByteArray, length: Int, id: Int): Boolean =
        length >= 12 &&
            (((packet[0].toInt() and 0xFF) shl 8) or (packet[1].toInt() and 0xFF)) == id &&
            (packet[2].toInt() and 0x80) != 0
}
