/*
 * A comment above the package declaration.
 */
@Deprecated
package lab;

import org.testng.annotations.Test;

public class AccumulateTest {
    @Test
    public void sumsTenTerms() {
        if (Accumulate.upTo(10) != 55) {
            throw new AssertionError("expected 55");
        }
    }
}
