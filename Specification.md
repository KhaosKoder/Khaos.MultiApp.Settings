Here’s a single, central, **implementation-ready specification** for the NuGet package and companion CLI. It’s written so an LLM (or a senior engineer) can implement the tables, code, mocks, and tests without ambiguity.

---

# Khaos.EfCore.MultiApp.Settings — Full Product Spec (Revised)

> Revision highlights (critical fixes applied):
> 1. Added uniqueness constraint `(ApplicationId, InstanceId, Key)` and optimistic concurrency (`RowVersion`).
> 2. Split timestamps into immutable `Created*` and mutable `Modified*` (replacing ambiguous `Added*`).
> 3. Strengthened audit: history now records both old & new values and rowversion before/after.
> 4. Defined deterministic reload hash based on `ModifiedDate` + `RowVersion` with scalable fast‑path.
> 5. Clarified Upsert semantics, concurrency handling, and rollback rules.
> 6. Defined binary snapshot refresh semantics.
> 7. Upgraded temporal types to `DATETIME2(3)`. 
> 8. Clarified encryption reload impact & recommendation for deterministic encryption.
> 9. (Additional) Corrected NULL uniqueness issue by replacing single UNIQUE constraint with filtered unique indexes per scope category.
> 10. (Additional) Atomic Upsert pattern & mandatory rowversion for any update/delete; rollback now validates rowversion to prevent overwriting newer changes.

---

## 3) Data model (tables)

> Consumers create these tables. No EF migrations in the package.
> Temporal / concurrency improvements applied.
> NULL uniqueness fix applied (single UNIQUE replaced by filtered unique indexes).

### 3.1 `dbo.Settings`

```sql
CREATE TABLE dbo.Settings (
  ID               BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  ApplicationId    NVARCHAR(200)  NULL,
  InstanceId       NVARCHAR(200)  NULL,
  [Key]            NVARCHAR(2048) NOT NULL,
  [Value]          NVARCHAR(MAX)  NULL,
  BinaryValue      VARBINARY(MAX) NULL,
  IsSecret         BIT            NOT NULL DEFAULT(0),
  ValueEncrypted   BIT            NOT NULL DEFAULT(0),
  CreatedBy        NVARCHAR(50)   NOT NULL,
  CreatedDate      DATETIME2(3)   NOT NULL,
  ModifiedBy       NVARCHAR(50)   NOT NULL,
  ModifiedDate     DATETIME2(3)   NOT NULL,
  [Comment]        VARCHAR(4000)  NULL,
  [Notes]          VARCHAR(MAX)   NULL,
  RowVersion       ROWVERSION     NOT NULL,
  CONSTRAINT CK_Settings_Value_XOR_Binary
      CHECK (([Value] IS NULL) <> (BinaryValue IS NULL))
);
-- Remove former single UNIQUE constraint (would allow multiple NULL scope duplicates)

-- Enforce uniqueness per scope category (SQL Server allows one NULL per filtered index scope)
CREATE UNIQUE INDEX UX_Settings_Global_Key
  ON dbo.Settings([Key])
  WHERE ApplicationId IS NULL AND InstanceId IS NULL;

CREATE UNIQUE INDEX UX_Settings_App_Key
  ON dbo.Settings(ApplicationId, [Key])
  WHERE ApplicationId IS NOT NULL AND InstanceId IS NULL;

CREATE UNIQUE INDEX UX_Settings_Instance_Key
  ON dbo.Settings(ApplicationId, InstanceId, [Key])
  WHERE ApplicationId IS NOT NULL AND InstanceId IS NOT NULL;

CREATE INDEX IX_Settings_Scope_Key INCLUDE (ModifiedDate, RowVersion)
  ON dbo.Settings(ApplicationId, InstanceId, [Key]);
```

**Uniqueness Rationale**

* Prevents duplicate logical rows where NULL comparisons would bypass a composite UNIQUE.
* Natural key resolution deterministic for Upsert.

### 3.2 `dbo.SettingsHistory` (append-only audit)

Captures both sides of a change for direct point-in-time reconstruction without replaying all deltas.

```sql
CREATE TABLE dbo.SettingsHistory (
  HistoryId         BIGINT IDENTITY(1,1) PRIMARY KEY,
  SettingId         BIGINT NULL,                -- may be NULL if original row deleted & ID not reused
  ApplicationId     NVARCHAR(200)  NULL,
  InstanceId        NVARCHAR(200)  NULL,
  [Key]             NVARCHAR(2048) NOT NULL,
  OldValue          NVARCHAR(MAX)  NULL,
  OldBinaryValue    VARBINARY(MAX) NULL,
  NewValue          NVARCHAR(MAX)  NULL,
  NewBinaryValue    VARBINARY(MAX) NULL,
  OldIsSecret       BIT            NULL,
  OldValueEncrypted BIT            NULL,
  NewIsSecret       BIT            NULL,
  NewValueEncrypted BIT            NULL,
  RowVersionBefore  VARBINARY(8)   NULL,
  RowVersionAfter   VARBINARY(8)   NULL,
  ChangedBy         NVARCHAR(50)   NOT NULL,
  ChangedDate       DATETIME2(3)   NOT NULL,  -- UTC
  Operation         NVARCHAR(20)   NOT NULL   -- 'Insert' | 'Update' | 'Delete' | 'Rollback'
);
CREATE INDEX IX_SettingsHistory_SettingId ON dbo.SettingsHistory(SettingId);
CREATE INDEX IX_SettingsHistory_KeyScopeDate
  ON dbo.SettingsHistory(ApplicationId, InstanceId, [Key], ChangedDate DESC);
```

**Invariants / Constraints (updates)**

* Scope/key uniqueness enforced via three filtered unique indexes (Global / App / Instance).

**Rollback Semantics (update)**

* Before applying rollback for a history row where the current row still exists: verify current `RowVersion` equals the history row’s `RowVersionAfter`. If mismatch → concurrency rollback conflict (abort with exception `RollbackConflict`), instruct caller to review newer changes.

---

## 4) Configuration provider behavior

### 4.1 Load scope & precedence

Unchanged precedence: Global < Application < Instance. The provider materializes a snapshot of rows (scoped query) ordered by precedence, overwriting keys as higher scopes appear. No deep merge of objects; arrays replaced wholesale.

### 4.2 Binary handling

* Binary rows are kept outside the textual `IConfiguration` tree.
* A thread-safe in-memory binary cache (dictionary) is refreshed atomically on every successful reload.
* `IBinarySettingsAccessor` reads from the current snapshot reference (copy-on-swap) ensuring lock-minimal concurrent access.

### 4.3 Encryption & secrets

* If `ValueEncrypted = 1`, provider decrypts before injecting plaintext into configuration (when `EnableDecryption` is true).
* To avoid spurious reloads from non-deterministic encryption (e.g., random IV generating different ciphertext for unchanged plaintext), recommendation: use deterministic envelope encryption for config values OR enable optional `DeterministicPlaintextHash` column (future) used in hash computation.
* Secrets logging masked: only key name + value length (and scope) appear when `EnableDetailedLogging = false`.

---

## 5) Reload detection (background poller)

### 5.1 Interval

* Default `PollingInterval = 1 minute`. Minimum allowed 30 seconds (relaxed from earlier) but warn if < 60 seconds for cost.

### 5.2 Scalable change detection

Two-step optimization:

1. **Fast Token Query** — cheap scope signature:

```sql
SELECT 
  COUNT(*)            AS RowCount,
  MAX(RowVersion)     AS MaxRowVersion,
  CONVERT(bigint, CHECKSUM_AGG(CHECKSUM([Key]))) AS KeyChecksum
FROM dbo.Settings
WHERE (ApplicationId IS NULL AND InstanceId IS NULL)
   OR (ApplicationId = @AppId AND InstanceId IS NULL)
   OR (@InstanceId IS NOT NULL AND ApplicationId = @AppId AND InstanceId = @InstanceId);
```

If all three values unchanged since last poll, skip reload.

2. **Deterministic Hash (on change)** — only when fast token differs do we compute full hash over textual + binary fingerprints:

```sql
;WITH ScopeRows AS (
  SELECT [Key], [Value], BinaryValue, ModifiedDate, IsSecret, ValueEncrypted, RowVersion
  FROM dbo.Settings
  WHERE (ApplicationId IS NULL AND InstanceId IS NULL)
     OR (ApplicationId = @AppId AND InstanceId IS NULL)
     OR (@InstanceId IS NOT NULL AND ApplicationId = @AppId AND InstanceId = @InstanceId)
), Normalized AS (
  SELECT
    [Key],
    COALESCE([Value], N'') AS ValueText,
    COALESCE(CONVERT(nvarchar(max), HASHBYTES('SHA2_256', BinaryValue), 1), N'') AS BinHashHex,
    CONVERT(nvarchar(30), ModifiedDate, 126) AS ModifiedIso,
    CONVERT(nvarchar(5), IsSecret) AS IsSecretBit,
    CONVERT(nvarchar(5), ValueEncrypted) AS ValueEncryptedBit,
    CONVERT(varbinary(8), RowVersion) AS Rv
  FROM ScopeRows
)
SELECT HASHBYTES(
  'SHA2_256',
  STRING_AGG(CONVERT(nvarchar(max),
     CONCAT([Key], N'|', ValueText, N'|', BinHashHex, N'|', ModifiedIso, N'|', IsSecretBit, N'|', ValueEncryptedBit, N'|', sys.fn_varbintohexstr(Rv))
  ), N'~') WITHIN GROUP (ORDER BY [Key])
) AS ScopeHash;
```

* Provider caches last `(RowCount, MaxRowVersion, KeyChecksum, ScopeHash)`.
* On hash change → rebuild snapshot → swap dictionaries → raise change token.

### 5.3 Consistency & isolation

* Use `READ COMMITTED SNAPSHOT` database setting recommended. Alternatively wrap full load + hash in a single transaction with `SET TRANSACTION ISOLATION LEVEL SNAPSHOT` to ensure consistent snapshot.

### 5.4 Failure modes

* If DB unreachable: log warning, keep last known configuration, metric increment, retry next interval.
* After N consecutive failures (configurable, default 5) log error with escalation event id.

---

## 6) Options & configuration

### 6.1 Options object

```
KhaosSettingsOptions
- ConnectionString?                  
- ApplicationId                      
- InstanceId?                        
- PollingInterval = 1 minute (min 30s) 
- BinaryEncoding = Base64Url         
- FailFastOnStartup = true           
- Validation:
  - EnableDataAnnotations = true
  - EnableFluentValidation = auto
  - FailOnValidationErrors = true
- Security:
  - EnableDecryption = false
  - EncryptionProviderType = "DPAPI|KeyVault|Custom"
  - RequireDeterministicEncryption = false (warn if false & ciphertext changes w/o plaintext change)
- Diagnostics:
  - EnableMetrics = true
  - EnableDetailedLogging = false
- Concurrency:
  - ThrowOnConcurrencyViolation = true
```

### 6.2 Connection string discovery order

Unchanged (explicit → config key → env var → optional default fallback). Clear exception if unresolved.

### 6.3 Registration API (consumer)

* `builder.Configuration.AddKhaosMultiAppSettings(opts => { ... });`
* `builder.Services.AddKhaosSettingsServices();`
* `builder.Services.ConfigureValidatedOptions<T>();`

---

## 7) Domain services (CRUD, binary, history)

Public abstractions:

```
ISettingsService
- Task<IReadOnlyList<SettingRow>> QueryAsync(SettingQuery filter, CancellationToken ct)
- Task<SettingRow?> GetAsync(long id, CancellationToken ct)
- Task<SettingRow> UpsertAsync(SettingUpsert request, CancellationToken ct)
- Task DeleteAsync(long id, string changedBy, byte[]? expectedRowVersion, CancellationToken ct)

IBinarySettingsAccessor
- bool TryGet(string key, out ReadOnlyMemory<byte> bytes)
- string GetAsBase64Url(string key)
- string GetAsUuencode(string key)

IHistoryService
- Task<IReadOnlyList<SettingsHistoryRow>> GetHistoryAsync(long settingId, CancellationToken ct)
- Task RollbackAsync(long historyId, string changedBy, CancellationToken ct) // history row determines target snapshot

IEncryptionProvider
- string Encrypt(string plaintext)
- string Decrypt(string ciphertext)
```

**Upsert semantics (revised)**

* Any *update* (by ID or natural key) MUST supply `ExpectedRowVersion`. If absent and row exists → reject with `MissingRowVersion` error (prevents silent lost updates). Inserts may omit it.
* Recommended atomic pattern (pseudo T-SQL):
  1. Try parameterized `UPDATE dbo.Settings WITH (UPDLOCK, HOLDLOCK)` WHERE natural key AND `RowVersion = @ExpectedRowVersion`; check `@@ROWCOUNT`.
  2. If `@@ROWCOUNT = 0` and row exists with same natural key but different rowversion → concurrency exception.
  3. If no row exists (not found by key) → `INSERT` new row (in same transaction) — uniqueness guaranteed by filtered indexes; if insert collides (rare race) catch unique index violation and retry step 1 (idempotent loop).
* EF Core implementation: use explicit transaction + raw SQL or concurrency token mapping plus retry policy. Avoid `MERGE` (potential subtle race / Halloween issues) v1.

**Delete semantics (revised)**

* Delete requires non-null `expectedRowVersion`. If mismatch → concurrency exception; no delete performed.

**Rollback (revised)**

* Rollback fetches current row. If history.Operation in ('Update','Rollback','Insert'): ensure current rowversion == history.RowVersionAfter; else abort with concurrency exception.
* For history.Operation = 'Delete': ensure no current row with same scope/key exists; else if exists treat as conflict unless its rowversion matches expected chain (not enforced v1, simpler rule = must not exist).

**Error codes (suggested)**

* `ConcurrencyConflict` (update/delete mismatch)
* `MissingRowVersion` (update/delete without rowversion)
* `RollbackConflict` (rollback rowversion mismatch)

---

## 8) Strong typing & validation

(Behavior unchanged except clarified rejection on reload.)

* Startup: if any bound options invalid and `FailOnValidationErrors = true`, throw.
* Reload: if invalid, retain previous good snapshot; emit metric `khaos_settings_validation_failure_total` and warning log.

---

## 9) Observability (summary)

(Metrics/health not fully expanded here; unchanged except new metrics.)

New metrics:
* `khaos_settings_reload_skipped_total` (fast-path token unchanged)
* `khaos_settings_reload_concurrency_conflict_total`
* `khaos_settings_poll_failures_consecutive` (gauge)

Health check: reports last successful reload age + consecutive failure count.

---

## 10) Reload publishing & change token (note)

* Concurrency guarantees rely on filtered unique indexes + mandatory rowversion for updates/deletes + atomic Upsert transaction pattern.

---

## 11) Security & encryption guidance

* Prefer deterministic envelope encryption (or a stored plaintext hash) to avoid needless reloads on ciphertext churn.
* Secrets masked in logs; CLI export defaults to omitting secret values unless `--include-secrets` provided.

---

## 12) Error handling (summary addendum)

* `MissingRowVersion` → 409 conflict style error (domain).
* `RollbackConflict` → 409 conflict with reference to history id & current rowversion.

---

## 13) Open future extensions (non-blocking for v1)

* Push notifications (SQL dependency / Service Broker / EventGrid).
* Deterministic plaintext hash column for encryption-neutral reload detection.
* Soft delete flag to simplify rollback identity continuity.
* Schema manifest generator (partially sketched in original spec) to export strongly-typed config schemas.

---

## 14) Appendix: Original merging rules (unchanged)

* Scalar overwrite by higher scope.
* Object(root section) replace.
* Array replace.
* New keys simply layer in.

---

## 15) Summary of Critical Fixes Impact (updated)

| Area | Problem Addressed | Change |
|------|-------------------|--------|
| Determinism | Duplicate scope/key with NULLs | Filtered unique indexes (3) |
| Upsert Race | Concurrent insert duplicates | Atomic UPDATE-with-lock then INSERT retry |
| Lost Updates | Optional rowversion allowed | Rowversion mandatory for any update/delete |
| Rollback Safety | Overwriting newer changes | Rowversion equality check before rollback |

---

(End of revised specification.)
