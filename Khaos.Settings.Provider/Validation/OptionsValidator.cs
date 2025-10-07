using Khaos.Settings.Options;
using Microsoft.Extensions.Options;
using Khaos.Settings.Errors;

namespace Khaos.Settings.Provider.Validation;

internal sealed class OptionsValidator : IValidateOptions<KhaosSettingsOptions>
{
    public ValidateOptionsResult Validate(string? name, KhaosSettingsOptions options)
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(options.ApplicationId)) errors.Add("ApplicationId is required");
        if (options.PollingInterval < TimeSpan.FromSeconds(30)) errors.Add("PollingInterval must be >= 30s");
        if (errors.Count == 0) return ValidateOptionsResult.Success;
        if (options.FailOnValidationErrors)
            throw new ValidationFailureException(nameof(KhaosSettingsOptions), errors);
        return ValidateOptionsResult.Fail(errors);
    }
}
