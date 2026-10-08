package org.opennetiq.measurement.radio

/** Derived cell identities (MEASUREMENT-METHODOLOGY.md section 3). */
object CellIdentityMath {
    /** gNB ID length is operator-configured (22–32 bits, TS 38.413); 24 is the common default. */
    const val DEFAULT_GNB_ID_LENGTH = 24

    /** LTE eNB ID: upper 20 bits of the 28-bit ECI. */
    fun enbId(eci: Int): Int = eci ushr 8

    /** LTE local cell ID: lower 8 bits of the ECI. */
    fun localCellId(eci: Int): Int = eci and 0xFF

    /** NR gNB ID: upper [gnbIdLengthBits] bits of the 36-bit NCI. */
    fun gnbId(nci: Long, gnbIdLengthBits: Int = DEFAULT_GNB_ID_LENGTH): Long {
        require(gnbIdLengthBits in 22..32) { "gNB ID length must be 22..32 bits, was $gnbIdLengthBits" }
        return nci ushr (36 - gnbIdLengthBits)
    }
}
