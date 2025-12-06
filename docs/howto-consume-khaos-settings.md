# How to Consume Khaos Settings Packages

This guide is for developers integrating the Khaos Settings libraries or CLI into their own applications.

## Choose the NuGet packages

| Scenario | Recommended packages |
| --- | --- |
| Configuration provider for apps | `KhaosCode.MultiApp.Settings` (NuGet package bundling the abstractions/core/data/encryption/metrics/provider assemblies)
| Access shared abstractions only | `Khaos.Settings.Abstractions`
| Command-line management | `Khaos.Settings.Cli` (global or local tool)

> One `KhaosCode.MultiApp.Settings` reference copies every runtime assembly (Abstractions, Core, Data, Encryption, Metrics, Provider) into your app output so you never chase multiple package versions.

```bash
# Example: add the provider package to a web app
 dotnet add package KhaosCode.MultiApp.Settings

# Example: install the CLI as a local tool
 dotnet tool install --local Khaos.Settings.Cli
```

## Configure your application

1. **Connection string** – supply it explicitly, via `appsettings.json`, or using the `KHAOS_SETTINGS_CONNECTIONSTRING` environment variable.
2. **Add the configuration source** during host builder setup.
3. **Register services** so consumers can request `ISettingsService`, `IHistoryService`, etc.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddKhaosMultiAppSettings(opts =>
{
    opts.ConnectionString = builder.Configuration.GetConnectionString("KhaosSettings");
    opts.EnableDecryption = false;
    opts.EnableMetrics = true;
});

builder.Services.AddKhaosSettingsServices(builder.Configuration);
```

> The provider automatically resolves the connection string using `Khaos:Settings:ConnectionString`, `ConnectionStrings:KhaosSettings`, or the `KHAOS_SETTINGS_CONNECTIONSTRING` environment variable, so you only need to set it if the defaults do not apply.

## Using the CLI

After installing `Khaos.Settings.Cli`, point it at the same connection string:

```bash
# List current settings
khaos-settings list --connection "Server=.;Database=KhaosSettings;Trusted_Connection=True"

# Update a value
khaos-settings set --app Sample --key FeatureFlag --value true
```

## Best practices

- **Centralize options** – keep the `KhaosSettingsOptions` initialization in one place (usually `Program.cs`) so connection strings and feature flags stay consistent between the host and CLI.
- **Enable metrics intentionally** – leave `EnableMetrics` off unless you have a collector reading the in-memory recorder or plan to swap in a custom `IMetricsRecorder`.
- **Encrypt sensitive values** – register a custom `IEncryptionProvider` and set `EnableDecryption=true` before storing secrets. Default `NoOpEncryptionProvider` leaves content in plain text.
- **Watch row versions** – the provider enforces optimistic concurrency; handle `ConcurrencyConflictException` in your calling code if you manipulate settings directly.
- **Keep packages aligned** – reference the same version of every `Khaos.Settings.*` package in your solution to avoid binding issues. All packages ship together, so upgrade them as a set.

## Common pitfalls

| Pitfall | How to avoid it |
| --- | --- |
| Missing connection string | Either set `opts.ConnectionString`, add `ConnectionStrings:KhaosSettings`, or export `KHAOS_SETTINGS_CONNECTIONSTRING`. The service registration throws if nothing resolves.
| `EnableDecryption=true` without a provider | Register an `IEncryptionProvider` implementation before calling `AddKhaosSettingsServices` or leave encryption disabled.
| Running migrations manually | The data layer handles EF Core migrations internally. Use the CLI or application bootstrapper; do not apply schema changes outside coordinated releases.
| Multiple configuration builders | Always call `AddKhaosMultiAppSettings` on the same `ConfigurationManager` instance you pass into `AddKhaosSettingsServices`. Copying configuration objects loses the options tuple stored in `builder.Properties`.
| Divergent package versions | Do not mix versions from different tags. Use `dotnet list package --outdated` to confirm everything shares the same SemVer.

## Next steps

- Review `docs/versioning-guide.md` for release/tagging instructions.
- See `docs/build-publish.md` for the scripts that build, test, and pack this solution.
