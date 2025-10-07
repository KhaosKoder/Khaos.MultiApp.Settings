using Khaos.Settings.Interfaces;
using System.Collections.Concurrent;

namespace Khaos.Settings.Metrics;

public static class MetricsNames
{
    public const string ReloadSuccess = "khaos_settings_reload_success_total";
    public const string ReloadSkipped = "khaos_settings_reload_skipped_total";
    public const string ReloadFailure = "khaos_settings_reload_failure_total";
    public const string ValidationFailure = "khaos_settings_validation_failure_total";
    public const string ConcurrencyConflict = "khaos_settings_reload_concurrency_conflict_total";
    public const string PollFailuresConsecutive = "khaos_settings_poll_failures_consecutive";
}

public sealed class NoOpMetricsRecorder : IMetricsRecorder
{
    private sealed class NoOpDisp : IDisposable { public void Dispose() { } }
    public void Increment(string name, long value = 1) { }
    public void SetGauge(string name, double value) { }
    public IDisposable Time(string name) => new NoOpDisp();
}

public sealed class InMemoryMetricsRecorder : IMetricsRecorder
{
    private readonly ConcurrentDictionary<string, long> _counters = new();
    private readonly ConcurrentDictionary<string, double> _gauges = new();

    private sealed class Timing(IMemoryOwner owner) : IDisposable
    {
        private readonly IMemoryOwner _owner = owner;
    private bool _disposed;
    public void Dispose() { if (_disposed) return; _disposed = true; _owner.Dispose(); }
}

private interface IMemoryOwner : IDisposable { }

public void Increment(string name, long value = 1) => _counters.AddOrUpdate(name, value, (_, v) => v + value);
public void SetGauge(string name, double value) => _gauges[name] = value;

public IDisposable Time(string name)
{
    var sw = System.Diagnostics.Stopwatch.StartNew();
    return new Timing(new StopwatchOwner(sw, end => Increment(name + ":ms", (long)end.TotalMilliseconds)));
}

private sealed class StopwatchOwner(System.Diagnostics.Stopwatch sw, Action<TimeSpan> report) : IMemoryOwner
    {
        public void Dispose()
{
    sw.Stop();
    report(sw.Elapsed);
}
}

// Expose copies for diagnostics
public IReadOnlyDictionary<string, long> SnapshotCounters() => new Dictionary<string, long>(_counters);
public IReadOnlyDictionary<string, double> SnapshotGauges() => new Dictionary<string, double>(_gauges);
}
