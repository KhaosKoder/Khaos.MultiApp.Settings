# Khaos Settings

High-concurrency, multi-application hierarchical settings store + EF Core provider + dynamic configuration reload for .NET 9.

> Global < Application < Instance precedence; optimistic concurrency enforced with SQL Server `rowversion` + filtered unique indexes (NULL?safe) preventing duplicate logical rows.

## Key Features

- Hierarchical scoping: Global / Application / Instance layering with overwrite semantics (no deep merge; last writer wins by scope precedence).
- Optimistic concurrency: Mandatory `RowVersion` for every update/delete (lost update protection).
- Atomic Upsert (SQL Server): `UPDLOCK, HOLDLOCK` guarded update-or-insert with retry semantics (insert collision returns `MissingRowVersion` to force client revise path).
- Deterministic reload detection: Fast triplet signature (RowCount, MaxRowVersion, KeyChecksum) + full SHA2-256 hash with ordered aggregation of value + metadata.
- Binary payload support separated from text tree (efficient `IConfiguration` binding + dedicated `IBinarySettingsAccessor`).
- Append-only audit history (old/new value + rowversion before/after) with safe rollback semantics.
- Scoped secret handling + masked logging (no plaintext secrets in structured logs unless opted in).
- Metrics hooks (`IMetricsRecorder`) & health reporter (last success, failure streak, snapshot hash snippet).
- CLI for CRUD, history, rollback, export/import.

## Projects

| Project | Purpose |
|---------|---------|
| Khaos.Settings.Abstractions | Public contracts, models, errors, options |
| Khaos.Settings.Data | EF Core entities & DbContext (no migrations) |
| Khaos.Settings.Core | Domain services (CRUD, history, binary accessor) |
| Khaos.Settings.Provider | Configuration provider + background reload |
| Khaos.Settings.Encryption | Placeholder encryption provider (NoOp) |
| Khaos.Settings.Metrics | In-memory & no-op metrics recorder |
| Khaos.Settings.Cli | Console CLI for managing settings |
| Khaos.Settings.Sample | Minimal ASP.NET sample |
| Khaos.Settings.ConsoleSample | Generic Host console sample (snapshot monitor) |

## SQL Schema

See `scripts/create_tables.sql` (excerpt below):

```sql
-- Filtered unique indexes for NULL-safe natural key enforcement
CREATE UNIQUE INDEX UX_Settings_Global_Key ON dbo.Settings([Key]) WHERE ApplicationId IS NULL AND InstanceId IS NULL;
CREATE UNIQUE INDEX UX_Settings_App_Key ON dbo.Settings(ApplicationId, [Key]) WHERE ApplicationId IS NOT NULL AND InstanceId IS NULL;
CREATE UNIQUE INDEX UX_Settings_Instance_Key ON dbo.Settings(ApplicationId, InstanceId, [Key]) WHERE ApplicationId IS NOT NULL AND InstanceId IS NOT NULL;
```

Full script includes audit table `dbo.SettingsHistory` and indices for history traversal.

## Getting Started

1. **Create tables** (run script):
   ```bash
   sqlcmd -S . -d YourDb -i scripts/create_tables.sql
   ```
2. **Register provider (ASP.NET)**:
   ```csharp
   builder.Configuration.AddKhaosMultiAppSettings(o =>
   {
       o.ApplicationId = "orders-service";
       o.InstanceId = Environment.MachineName;
       o.ConnectionString = builder.Configuration.GetConnectionString("SettingsDb");
       o.EnableDecryption = false; // enable + register real provider when ready
   });
   builder.Services.AddKhaosSettingsServices(builder.Configuration);
   ```
3. **Consume settings**:
   - Bind via `IConfiguration` (text values only) or strongly typed options.
   - Fetch binary with `IBinarySettingsAccessor`.
4. **Perform CRUD** via `ISettingsService` (must supply `ExpectedRowVersion` on update/delete):
   ```csharp
   var created = await svc.UpsertAsync(new SettingUpsert { Key = "FeatureX:Enabled", Value = "true", ChangedBy = user });
   var updated = await svc.UpsertAsync(new SettingUpsert { Key = created.Key, Value = "false", ChangedBy = user, ExpectedRowVersion = created.RowVersion });
   ```
5. **Rollback** a change:
   ```csharp
   await history.RollbackAsync("FeatureX:Enabled", versionIndex: 2, changedBy: user);
   ```

## Console Sample (Generic Host)

`Khaos.Settings.ConsoleSample` demonstrates:
- Adding the provider to a generic host.
- Monitoring snapshot reloads with `ISettingsSnapshotSource` + change token.
- Printing diffs (added/updated/removed keys).

Run:
```bash
cd Khaos.Settings.ConsoleSample
dotnet run -- --application demo --connection "Server=.;Database=DemoSettings;Trusted_Connection=True;TrustServerCertificate=True"
```

## Metrics

| Metric | Description |
|--------|-------------|
| `khaos_settings_reload_success_total` | Successful reloads |
| `khaos_settings_reload_skipped_total` | Fast-path unchanged |
| `khaos_settings_reload_failure_total` | Reload failures |
| `khaos_settings_validation_failure_total` | Validation failures (reload) |
| `khaos_settings_reload_concurrency_conflict_total` | CRUD concurrency conflicts |
| `khaos_settings_poll_failures_consecutive` | Consecutive poll failures (gauge) |

## Error Codes

| Code | Scenario |
|------|----------|
| `MissingRowVersion` | Update/delete attempted without expected rowversion |
| `ConcurrencyConflict` | Rowversion mismatch on update/delete |
| `DuplicateKey` | Natural key uniqueness violated |
| `RollbackConflict` | Current row changed beyond rollback target |
| `ValidationFailure` | Invalid request or rollback XOR violation |

## Export / Import (CLI)

```bash
# export (secrets masked by default)
settings-cli --application app --connection "..." export --file out.json
# import dry-run
settings-cli --application app --connection "..." import --file out.json
# apply
settings-cli --application app --connection "..." import --file out.json --apply
```

## Roadmap (Abbrev.)
- Deterministic encryption & plaintext hash column.
- Push notifications for near-real-time reload.
- Health endpoint & status CLI command.
- Manifest/schema generator & advanced export (binary / rowversion).

## License
TBD.

---
Created from implementation spec in `Specification.md`.
