using Khaos.Settings.Data;
using Microsoft.EntityFrameworkCore;

namespace Khaos.Settings.Tests.Helpers;

internal sealed class InMemoryDbContextFactory : IDbContextFactory<KhaosSettingsDbContext>
{
    private readonly DbContextOptions<KhaosSettingsDbContext> _options;
    public InMemoryDbContextFactory(string name)
    { _options = new DbContextOptionsBuilder<KhaosSettingsDbContext>().UseInMemoryDatabase(name).Options; }
    public KhaosSettingsDbContext CreateDbContext() => new(_options);
    public Task<KhaosSettingsDbContext> CreateDbContextAsync(CancellationToken cancellationToken = default) => Task.FromResult(new KhaosSettingsDbContext(_options));
}
