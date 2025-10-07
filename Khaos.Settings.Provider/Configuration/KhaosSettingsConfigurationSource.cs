using Microsoft.Extensions.Configuration;

namespace Khaos.Settings.Provider.Configuration;

public sealed class KhaosSettingsConfigurationSource : IConfigurationSource
{
    public KhaosSettingsConfigurationProvider Provider { get; } = new();
    public IConfigurationProvider Build(IConfigurationBuilder builder) => Provider;
}
