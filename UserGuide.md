# Khaos Settings User Guide

Version: 1.0
Target Framework: .NET 9

---
## 1. Overview
Khaos Settings is a hierarchical, multi-application configuration store with:
- Global / Application / Instance scoping (last scope wins)
- High?concurrency optimistic updates (ROWVERSION)
- Atomic Upsert (SQL Server)
- Binary + textual value support
- Append?only audit history + rollback
- Periodic background reload into `IConfiguration` + change tokens
- Metrics & health reporting hooks

You own the database (no embedded EF migrations) � run the provided SQL script then wire the provider into your host.

---
## 2. Install Packages
Add references depending on how you consume the stack:
- **NuGet**: `KhaosCode.MultiApp.Settings` (bundles the provider plus abstractions, data, core, encryption, and metrics assemblies).
- **Source projects**: `Khaos.Settings.Abstractions`, `Khaos.Settings.Data`, `Khaos.Settings.Core`, `Khaos.Settings.Provider`, optional `Khaos.Settings.Encryption`, `Khaos.Settings.Metrics`, `Khaos.Settings.Cli`.

---
## 3. Create Database Schema
Run the script `scripts/create_tables.sql` against a SQL Server DB:
```bash
sqlcmd -S . -d YourDb -i scripts/create_tables.sql
```
This creates:
- dbo.Settings (current values)
- dbo.SettingsHistory (audit trail)
- Filtered unique indexes enforcing scope/key uniqueness

---
## 4. Basic ASP.NET Host Integration
```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddKhaosMultiAppSettings(o =>
{
    o.ConnectionString = builder.Configuration.GetConnectionString("SettingsDb");
    o.ApplicationId = "orders-service";          // optional if only global keys
    o.InstanceId = Environment.MachineName;       // optional instance layer
    o.PollingInterval = TimeSpan.FromMinutes(1);  // >= 30s recommended 60s
    o.EnableDecryption = false;                   // set true + register real IEncryptionProvider
    o.EnableDetailedLogging = false;              // secrets masked when false
});

builder.Services.AddKhaosSettingsServices(builder.Configuration);

var app = builder.Build();
app.MapGet("/feature", (IConfiguration cfg) => new { Enabled = cfg.GetValue<bool>("FeatureX:Enabled") });
app.Run();
```
`AddKhaosMultiAppSettings` attaches a configuration source + stores options; `AddKhaosSettingsServices` registers services + background poller.

---
## 5. Generic Host / Worker Example
```csharp
HostApplicationBuilder hb = Host.CreateApplicationBuilder(args);

hb.Configuration.AddKhaosMultiAppSettings(o =>
{
    o.ConnectionString = hb.Configuration["ConnStrings:Settings"]; // or supply directly
    o.ApplicationId = "batch-jobs";
    o.InstanceId = Environment.MachineName;
});

hb.Services.AddKhaosSettingsServices(hb.Configuration);

hb.Services.AddHostedService<Worker>();
await hb.Build().RunAsync();

class Worker : BackgroundService
{   private readonly IConfiguration _cfg; public Worker(IConfiguration c) => _cfg=c;
    protected override async Task ExecuteAsync(CancellationToken ct)
    {   while(!ct.IsCancellationRequested){
            bool enabled = _cfg.GetValue("FeatureX:Enabled", false);
            // use setting...
            await Task.Delay(TimeSpan.FromSeconds(30), ct);
        }
    }
}
```

---
## 6. Working With Strongly Typed Options
Because Khaos injects keys into the unified `IConfiguration`, you can bind via standard `IOptions<T>` patterns.

### 6.1 Register POCO + binding
```csharp
public sealed class FeatureXOptions
{   public bool Enabled { get; set; }
    public int CacheSeconds { get; set; } = 60;
}

builder.Services.Configure<FeatureXOptions>(builder.Configuration.GetSection("FeatureX"));
```
### 6.2 Consumption
```csharp
public class Handler
{   private readonly IOptionsSnapshot<FeatureXOptions> _snap; // or IOptionsMonitor<FeatureXOptions>
    public Handler(IOptionsSnapshot<FeatureXOptions> snap) => _snap = snap;
    public void Execute(){ var opts = _snap.Value; if (opts.Enabled) { /* ... */ } }
}
```
`IOptionsSnapshot<T>` updates per scope (per request in ASP.NET). `IOptionsMonitor<T>` raises change callbacks. Both react automatically when the background reload publishes a new configuration snapshot.

### 6.3 Monitoring Changes
```csharp
var monitor = app.Services.GetRequiredService<IOptionsMonitor<FeatureXOptions>>();
monitor.OnChange((opts, name) =>
{
    app.Logger.LogInformation("FeatureX updated: Enabled={Enabled} Cache={CacheSeconds}", opts.Enabled, opts.CacheSeconds);
});
```

---
## 7. Periodic Reload Mechanics
1. Background service wakes every `PollingInterval`.
2. Fast signature check (count, max rowversion, key checksum) � if unchanged => skip.
3. On change, full deterministic hash built. If hash differs => rebuild snapshot.
4. Provider publishes dictionary; change token triggers; options + `IConfiguration` readers see new values.
5. `IBinarySettingsAccessor` updated atomically for binary entries.

No manual refresh call needed. To force quicker reaction temporarily, reduce `PollingInterval` (warn if < 60s). Minimum enforced = 30s.

---
## 8. Creating & Updating Settings (CRUD)
Inject `ISettingsService`.
```csharp
public class AdminApi
{   private readonly ISettingsService _svc; public AdminApi(ISettingsService svc) => _svc=svc;
    public async Task CreateOrUpdate(CancellationToken ct)
    {
        // Insert
        var created = await _svc.UpsertAsync(new SettingUpsert {
            Key = "FeatureX:Enabled",
            Value = "true",
            ChangedBy = "admin"
        }, ct);

        // Update (must include ExpectedRowVersion)
        var updated = await _svc.UpsertAsync(new SettingUpsert {
            Key = created.Key,
            Value = "false",
            ChangedBy = "admin",
            ExpectedRowVersion = created.RowVersion
        }, ct);
    }
}
```
Concurrency: If rowversion mismatch, a `ConcurrencyConflictException` (domain) is thrown. Always re-read before retrying.

### 8.1 Deleting
```csharp
await _svc.DeleteAsync(id: created.Id, changedBy: "admin", expectedRowVersion: created.RowVersion, ct);
```

### 8.2 Binary Values
Provide exactly one of `Value` or `BinaryValue`.
```csharp
await _svc.UpsertAsync(new SettingUpsert {
    Key = "Certificates:RootCA",
    BinaryValue = File.ReadAllBytes("rootCA.cer"),
    IsSecret = true,
    ChangedBy = "security"
}, ct);
```
Retrieve at runtime:
```csharp
var binAccessor = provider.GetRequiredService<IBinarySettingsAccessor>();
if (binAccessor.TryGet("Certificates:RootCA", out var bytes)) { /* use */ }
```

---
## 9. History & Rollback
```csharp
var historySvc = scope.ServiceProvider.GetRequiredService<IHistoryService>();
var hist = await historySvc.GetHistoryAsync(settingId, ct); // newest first
// Roll back to an earlier version by index in descending list (e.g., version 2)
await historySvc.RollbackAsync(key: "FeatureX:Enabled", versionIndex: 2, changedBy: "admin", ct);
```
Rollback validates rowversion chain; conflict throws `RollbackConflictException`.

---
## 10. Secrets & Encryption
- Mark secret via `IsSecret=true`.
- If `EnableDecryption=true`, register an `IEncryptionProvider` implementation before `AddKhaosSettingsServices` (otherwise exception). The included `NoOpEncryptionProvider` echoes values.
- Encrypted values stored ciphertext in DB; provider decrypts into `IConfiguration` (plaintext never logged when `EnableDetailedLogging=false`).

---
## 11. Metrics & Health
Implement `IMetricsRecorder` to push to Prometheus / OpenTelemetry. Built-in in-memory recorder accumulates counts.
`IHealthReporter` exposes: `LastSuccessfulReloadUtc`, `ConsecutiveFailures`, `LastRowCount`, `LastHashSnippet`.

---
## 12. CLI (Optional)
After packing the CLI:
```bash
settings-cli --application orders --connection "Server=.;Database=Settings;Trusted_Connection=True;TrustServerCertificate=True" list
settings-cli ... set --key FeatureX:Enabled --value true --changed-by admin
settings-cli ... history --key FeatureX:Enabled
settings-cli ... rollback --key FeatureX:Enabled --version 2 --changed-by admin
```

---
## 13. Typical Production Guidelines
- Keep `PollingInterval` >= 60s unless strong need.
- Treat rowversion errors as normal racing; re-fetch + retry.
- Separate secrets from non-secrets for easier auditing.
- Monitor `khaos_settings_reload_failure_total` and `khaos_settings_poll_failures_consecutive`.

---
## 14. Troubleshooting
| Symptom | Cause | Action |
|---------|-------|--------|
| ConcurrencyConflictException | Row changed since fetch | Re-query row + retry with new rowversion |
| MissingRowVersionException | Update/delete without ExpectedRowVersion | Supply the last known rowversion |
| RollbackConflictException | Row mutated after target history version | Review newer history; decide new rollback target |
| ValidationFailureException | Both Value & BinaryValue set or both null | Supply exactly one |
| No encryption provider error | EnableDecryption=true but none registered | Register custom provider | 

---
## 15. Man Page Style Reference
### 15.1 ISettingsService
NAME
  ISettingsService - CRUD over hierarchical settings with optimistic concurrency.
SYNOPSIS
  QueryAsync(filter, ct)
  GetAsync(id, ct)
  UpsertAsync(request, ct)
  DeleteAsync(id, changedBy, expectedRowVersion, ct)
DESCRIPTION
  Provides atomic upsert + rowversion guarded updates. Enforces Value XOR BinaryValue.

### 15.2 SettingUpsert
FIELDS
  Key (string, required) logical setting key.
  ApplicationId / InstanceId (string?) optional scoping.
  Value (string?) textual value (mutually exclusive with BinaryValue).
  BinaryValue (byte[]?) binary payload.
  IsSecret (bool) marks secret for masked logging.
  EncryptValue (bool) indicates value stored encrypted.
  ExpectedRowVersion (byte[]?) required on update/delete.
  Comment (string?) short description.
  Notes (string?) long form notes.
  ChangedBy (string) actor id.

### 15.3 IHistoryService
NAME
  IHistoryService - Audit history access + rollback.
SYNOPSIS
  GetHistoryAsync(settingId, ct)
  RollbackAsync(key, versionIndex, changedBy, ct)
DESCRIPTION
  Produces descending chronological history entries. Rollback enforces rowversion continuity.

### 15.4 IBinarySettingsAccessor
NAME
  IBinarySettingsAccessor - Access binary setting snapshots.
SYNOPSIS
  TryGet(key, out bytes)
  GetAsBase64Url(key)
  GetAsUuencode(key)
DESCRIPTION
  Reads from immutable snapshot swapped on successful reload. Textual tree excludes binaries.

### 15.5 KhaosSettingsOptions
KEY FIELDS
  ConnectionString (string) required resolved.
  ApplicationId / InstanceId (string?) scope selectors.
  PollingInterval (TimeSpan) default 1m.
  EnableDecryption (bool) decrypt encrypted values.
  EnableMetrics (bool) publish metrics.
  EnableDetailedLogging (bool) disable masking.
  ThrowOnConcurrencyViolation (bool) influences service exceptions (future use).

### 15.6 Exceptions
  ConcurrencyConflictException - Rowversion mismatch on update/delete.
  MissingRowVersionException - ExpectedRowVersion not supplied for existing row.
  DuplicateKeyException - Parallel insert race produced uniqueness violation.
  RollbackConflictException - Rollback aborted due to intervening change.
  ValidationFailureException - Input contract violations.

### 15.7 IOptions / Monitoring
USE
  Configure<T>(section) then inject `IOptionsSnapshot<T>` or `IOptionsMonitor<T>`.
CHANGE EVENTS
  Background reload publishes change token causing bound options to refresh atomically.
CALLBACK
  IOptionsMonitor<T>.OnChange registers side-effect hook (avoid heavy logic; debounce if needed).

### 15.8 HealthReporter (IHealthReporter)
FIELDS
  LastSuccessfulReloadUtc (DateTime?) last success.
  ConsecutiveFailures (int) consecutive failure count.
  LastRowCount (long?) last loaded row count.
  LastHashSnippet (string?) first 8 hex of hash aiding diff correlation.

---
## 16. Example: Reactive Component
```csharp
public sealed class FeatureGate : IDisposable
{
    private volatile bool _enabled;
    private readonly IDisposable _sub;
    public FeatureGate(IOptionsMonitor<FeatureXOptions> mon)
    {   _enabled = mon.CurrentValue.Enabled;
        _sub = mon.OnChange(o => _enabled = o.Enabled);
    }
    public bool IsEnabled => _enabled;
    public void Dispose() => _sub.Dispose();
}
```

---
## 17. Example: Safe Update Loop
```csharp
async Task Toggle(ISettingsService svc, string key, CancellationToken ct)
{
    // read existing (query by prefix or known id elsewhere)
    var existing = (await svc.QueryAsync(new SettingQuery{ KeyPrefix = key }, ct)).FirstOrDefault();
    if (existing == null)
    {
        await svc.UpsertAsync(new SettingUpsert { Key = key, Value = "true", ChangedBy = "ops" }, ct);
        return;
    }
    bool cur = bool.TryParse(existing.Value, out var b) && b;
    await svc.UpsertAsync(new SettingUpsert {
        Key = key,
        Value = (!cur).ToString().ToLowerInvariant(),
        ChangedBy = "ops",
        ExpectedRowVersion = existing.RowVersion
    }, ct);
}
```

---
## 18. Binary Access Example
```csharp
var bin = sp.GetRequiredService<IBinarySettingsAccessor>();
string certB64 = bin.GetAsBase64Url("Certificates:RootCA");
```

---
## 19. Security Notes
- Grant app `SELECT` rights if read-only scenario; CRUD service requires `SELECT/INSERT/UPDATE/DELETE` on tables.
- Consider Always Encrypted / TDE for at-rest secrecy.
- For secret rotation, write new value (with encryption flag) -> reload picks up -> old value still in history (consider purge policy).

---
## 20. Performance Notes
- Fast path skip avoids heavy hashing unless rowcount/max rowversion/checksum changed.
- Poll interval trade-off: lower = fresher config but more DB load.
- Binary hashing cost: O(N rows). Keep large binaries minimal where possible.

---
## 21. Extensibility
- Replace metrics recorder by registering custom `IMetricsRecorder` before `AddKhaosSettingsServices`.
- Provide alternate encryption provider implementing `IEncryptionProvider`.
- Add additional validation by decorating services or hooking into reload pipeline (future hook).

---
## 22. Changelog (initial)
1.0 - Initial public schema & provider.

---
END OF GUIDE
