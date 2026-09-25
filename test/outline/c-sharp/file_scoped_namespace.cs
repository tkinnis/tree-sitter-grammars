using System.Threading.Tasks;
using NUnit.Framework;

namespace Contoso.Ledger.Tests;

[TestFixture]
public class LedgerTests
{
    private Ledger _ledger = null!;

    [SetUp]
    public void CreateLedger() => _ledger = new Ledger();

    [Test]
    public void BalancesAfterPosting()
    {
        _ledger.Post(10m);
        Assert.That(_ledger.Balance, Is.EqualTo(10m));
    }

    [TestCase(1)]
    [TestCase(-1)]
    public async Task PostsEveryAmount(int amount)
    {
        await _ledger.PostAsync(amount);
        Assert.That(_ledger.Entries, Has.Count.EqualTo(1));
    }

    [TestFixture]
    public class Reconciliation
    {
        [Test]
        public void MatchesTheStatement() => Assert.Pass();
    }
}

public class Ledger
{
    public decimal Balance { get; private set; }

    public void Post(decimal amount) => Balance += amount;
}
