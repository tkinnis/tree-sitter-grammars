using System;
using System.Collections.Generic;
using Xunit;

namespace Contoso.Billing
{
    namespace Tests
    {
        public class InvoiceTests
        {
            private readonly List<Line> _lines = new();

            [Fact]
            public void TotalsEveryLine()
            {
                var invoice = new Invoice(_lines);
                Assert.Equal(0m, invoice.Total);
            }

            [Theory]
            [InlineData(1, 2.50)]
            [InlineData(3, 0.25)]
            public void MultipliesQuantityByPrice(int quantity, double price)
            {
                var line = new Line(quantity, (decimal)price);
                Assert.Equal((decimal)(quantity * price), line.Amount);
            }

            public class WhenEmpty
            {
                [Fact]
                public void HasNoLines() => Assert.Empty(new Invoice(new List<Line>()).Lines);
            }
        }
    }

    public interface IPriced
    {
        decimal Amount { get; }
    }

    public class Invoice
    {
        public Invoice(IReadOnlyList<Line> lines) => Lines = lines;

        public IReadOnlyList<Line> Lines { get; }

        public decimal Total => Sum();

        private decimal Sum()
        {
            var total = 0m;
            foreach (var line in Lines)
            {
                total += line.Amount;
            }
            return total;
        }
    }
}

namespace Contoso.Shipping.Tests
{
    public class ParcelTests
    {
        [Fact]
        public void WeighsNothingEmpty() => Assert.Equal(0, new Parcel().Weight);
    }
}
