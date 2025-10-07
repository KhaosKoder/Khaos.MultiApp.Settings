namespace Khaos.Settings.Interfaces;

public interface ISettingsSnapshotSource
{
    IReadOnlyDictionary<string, string?> CurrentValues { get; }
}
