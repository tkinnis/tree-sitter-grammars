package com.example.ledger;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

class LedgerTest {
    private final Ledger ledger = new Ledger();

    @Test
    void balancesAfterPosting() {
        ledger.post(10);
        assertEquals(10, ledger.balance());
    }

    @Nested
    class WhenEmpty {
        @Test
        void hasNoBalance() {
            assertEquals(0, new Ledger().balance());
        }
    }
}

interface Posting {
    int amount();
}

class Ledger {
    private int balance;

    Ledger() {
        balance = 0;
    }

    void post(int amount) {
        balance += amount;
    }

    int balance() {
        return balance;
    }
}
