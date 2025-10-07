using FluentAssertions;
using Khaos.Settings.Provider.Configuration;

namespace Khaos.Settings.Tests.Provider;

public class ConfigurationProviderTests
{
    [Fact]
    public void Given_Publish_When_NewValues_Then_CurrentValuesReflect()
    {
        var provider = new KhaosSettingsConfigurationProvider();
        provider.Publish(new Dictionary<string, string?> { { "A", "1" }, { "B", "2" } });
        provider.CurrentValues.Should().ContainKeys("A", "B");
        provider.CurrentValues["A"].Should().Be("1");
    }
}
