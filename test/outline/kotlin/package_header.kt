package com.example.ledger

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class LedgerTest {
    @Test
    fun balancesAfterPosting() {
        val ledger = Ledger()
        ledger.post(10)
        assertEquals(10, ledger.balance)
    }

    @Nested
    inner class WhenEmpty {
        @Test
        fun hasNoBalance() {
            assertEquals(0, Ledger().balance)
        }
    }
}

object Ledgers {
    fun empty() = Ledger()
}

fun main() {
    println(Ledgers.empty().balance)
}
