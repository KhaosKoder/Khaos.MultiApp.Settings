using Khaos.Settings.Provider.Extensions;
using Khaos.Settings.Options;
using Khaos.Settings.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Primitives;
using Microsoft.Extensions.Logging;

var host = Host.CreateDefaultBuilder(args)
    .ConfigureAppConfiguration((ctx, cfg) =>
    {
        cfg.AddJsonFile("appsettings.json", optional: true, reloadOnChange: true);
        cfg.AddEnvironmentVariables();
        cfg.AddKhaosMultiAppSettings(o =>
        {
            o.ApplicationId = ctx.HostingEnvironment.ApplicationName ?? "console-app";
            o.InstanceId = Environment.MachineName;
            o.ConnectionString = Environment.GetEnvironmentVariable("KHAOS_SETTINGS_CS");
            o.PollingInterval = TimeSpan.FromSeconds(45);
            o.EnableMetrics = true;
        });
    })
    .ConfigureServices((ctx, services) =>
    {
        services.AddKhaosSettingsServices(ctx.Configuration);
        services.AddHostedService<SampleRunner>();
    })
    .Build();

await host.RunAsync();

public sealed class SampleRunner : BackgroundService
{
    private readonly IConfiguration _config;
    private readonly ILogger<SampleRunner> _logger;
    private readonly ISettingsService _svc;
    private readonly ISettingsSnapshotSource _snapshot;
    private IReadOnlyDictionary<string, string?> _last = new Dictionary<string, string?>();

    public SampleRunner(IConfiguration config, ILogger<SampleRunner> logger, ISettingsService svc, ISettingsSnapshotSource snapshot)
    { _config = config; _logger = logger; _svc = svc; _snapshot = snapshot; }

    protected override Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Sample runner starting. Current FeatureX:Enabled={Val}", _config["FeatureX:Enabled"]);
        // Observe reloads via change token
        ChangeToken.OnChange(() => _config.GetReloadToken(), OnReload);
        // Also poll every minute just to print a status line
        _ = Task.Run(async () =>
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                _logger.LogInformation("Heartbeat FeatureX:Enabled={Val}", _config["FeatureX:Enabled"]);
            }
        }, stoppingToken);
        return Task.CompletedTask;
    }

    private void OnReload()
    {
        var current = _snapshot.CurrentValues;
        var added = current.Keys.Except(_last.Keys, StringComparer.OrdinalIgnoreCase).ToList();
        var removed = _last.Keys.Except(current.Keys, StringComparer.OrdinalIgnoreCase).ToList();
        var updated = current.Where(kv => _last.TryGetValue(kv.Key, out var oldVal) && oldVal != kv.Value).Select(kv => kv.Key).ToList();
        if (added.Count == 0 && removed.Count == 0 && updated.Count == 0)
        {
            _logger.LogInformation("Reload detected (no changes)");
        }
        else
        {
            _logger.LogInformation("Reload changes: Added[{Added}] Updated[{Updated}] Removed[{Removed}]", string.Join(',', added), string.Join(',', updated), string.Join(',', removed));
        }
        _last = new Dictionary<string, string?>(current, StringComparer.OrdinalIgnoreCase);
    }
}
