using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Inventory
{
    [TestClass]
    public sealed class StockTests
    {
        [TestInitialize]
        public void Reset() { }

        [TestMethod]
        [DataRow(0)]
        [DataRow(5)]
        public void CountsWhatWasReceived(int received)
        {
            var stock = new Stock();
            stock.Receive(received);
            Assert.AreEqual(received, stock.Count);
        }
    }

    internal sealed class Stock
    {
        public int Count { get; private set; }

        public void Receive(int quantity) => Count += quantity;
    }
}
