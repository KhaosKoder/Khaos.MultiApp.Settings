using Khaos.Settings.Options;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Khaos.Settings.Interfaces;
using Khaos.Settings.Metrics;
using Khaos.Settings.Encryption;
using Khaos.Settings.Core.Services;
using Khaos.Settings.Data;
using Microsoft.EntityFrameworkCore;
using Khaos.Settings.Provider.Configuration;
using Khaos.Settings.Provider.Validation;
using Microsoft.Extensions.Options;
using Khaos.Settings.Provider.Reload;

namespace Khaos.Settings.Provider.Extensions;

public static class ConfigurationBuilderExtensions
{
    public static IConfigurationBuilder AddKhaosMultiAppSettings(this IConfigurationBuilder builder, Action<KhaosSettingsOptions>? configure)
    {
        var opts = new KhaosSettingsOptions();
        configure?.Invoke(opts);
        var source = new KhaosSettingsConfigurationSource();
        builder.Add(source);
        builder.Properties[nameof(KhaosSettingsOptions)] = (opts, source);
        return builder;
    }

    private static string? ResolveConnectionString(IConfiguration config, KhaosSettingsOptions opts)
    {
        if (!string.IsNullOrWhiteSpace(opts.ConnectionString)) return opts.ConnectionString;
        // config key hierarchy
        var fromConfig = config["Khaos:Settings:ConnectionString"] ?? config["ConnectionStrings:KhaosSettings"];
        if (!string.IsNullOrWhiteSpace(fromConfig)) return fromConfig;
        var fromEnv = Environment.GetEnvironmentVariable("KHAOS_SETTINGS_CONNECTIONSTRING");
        if (!string.IsNullOrWhiteSpace(fromEnv)) return fromEnv;
        return null; // caller will throw if still null
    }

    public static IServiceCollection AddKhaosSettingsServices(this IServiceCollection services, IConfiguration configuration)
    {
        KhaosSettingsOptions opts;
        KhaosSettingsConfigurationSource? src = null;
        if (configuration is IConfigurationBuilder cb && cb.Properties.TryGetValue(nameof(KhaosSettingsOptions), out var stored) && stored is ValueTuple<KhaosSettingsOptions, KhaosSettingsConfigurationSource> tuple)
        {
            opts = tuple.Item1;
            src = tuple.Item2;
        }
        else
        {
            opts = new KhaosSettingsOptions();
        }
        opts.ConnectionString = ResolveConnectionString(configuration, opts) ?? throw new InvalidOperationException("Settings connection string not resolved.");

        services.TryAddSingleton(opts);
        if (src != null) services.TryAddSingleton(src.Provider);
        services.AddSingleton<IValidateOptions<KhaosSettingsOptions>, OptionsValidator>();
        if (opts.EnableDecryption && services.All(d => d.ServiceType != typeof(IEncryptionProvider)))
        {
            throw new InvalidOperationException("EnableDecryption=true but no encryption provider registered.");
        }
        services.TryAddSingleton<IEncryptionProvider, NoOpEncryptionProvider>();
        services.TryAddSingleton<IMetricsRecorder>(sp => opts.EnableMetrics ? new InMemoryMetricsRecorder() : new NoOpMetricsRecorder());
        services.AddDbContextFactory<KhaosSettingsDbContext>(o => o.UseSqlServer(opts.ConnectionString));
        services.TryAddScoped<ISettingsService, SettingsService>();
        services.TryAddScoped<IHistoryService, HistoryService>();
        services.TryAddSingleton<BinarySettingsAccessor>();
        services.TryAddSingleton<IBinarySettingsAccessor>(sp => sp.GetRequiredService<BinarySettingsAccessor>());
        services.TryAddSingleton<IHealthReporter, HealthReporter>();
        services.AddHostedService<SettingsReloadBackgroundService>();
        return services;
    }
}
