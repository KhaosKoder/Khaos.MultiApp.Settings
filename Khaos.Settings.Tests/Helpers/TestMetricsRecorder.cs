using Khaos.Settings.Interfaces;
using System.Collections.Concurrent;

namespace Khaos.Settings.Tests.Helpers;

internal sealed class TestMetricsRecorder : IMetricsRecorder
{
    public ConcurrentDictionary<string, long> Counters { get; } = new();
    public ConcurrentDictionary<string, double> Gauges { get; } = new();
    public void Increment(string name, long value = 1) => Counters.AddOrUpdate(name, value, (_, old) => old + value);
    public void SetGauge(string name, double value) => Gauges[name] = value;
    public IDisposable Time(string name) => new Noop();
    private sealed class Noop : IDisposable { public void Dispose() { } }
}
