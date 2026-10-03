package com.Example.ledger;

import java.util.List;

class LedgerTest {
    static final int OPENING = 0;

    void post(List<Integer> amounts) {
        int balance = OPENING;
        for (int amount : amounts) {
            balance += amount;
        }
    }
}
