using Khaos.Settings.Interfaces;
using Khaos.Settings.Models;
using Khaos.Settings.Options;
using Khaos.Settings.Core.Services;
using Khaos.Settings.Data;
using Khaos.Settings.Encryption;
using Khaos.Settings.Metrics;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Minimal manual registration (no provider extension dependency)
var opts = new KhaosSettingsOptions { ApplicationId = "sample-app", ConnectionString = builder.Configuration.GetConnectionString("SettingsDb") };
builder.Services.AddSingleton(opts);
builder.Services.AddSingleton<IEncryptionProvider, NoOpEncryptionProvider>();
builder.Services.AddSingleton<IMetricsRecorder, NoOpMetricsRecorder>();
builder.Services.AddDbContextFactory<KhaosSettingsDbContext>(o => o.UseSqlServer(opts.ConnectionString));
builder.Services.AddScoped<ISettingsService, SettingsService>();
builder.Services.AddScoped<IHistoryService, HistoryService>();

builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapGet("/settings", async (ISettingsService svc, CancellationToken ct) =>
{
    var rows = await svc.QueryAsync(new SettingQuery { ApplicationId = opts.ApplicationId }, ct);
    return rows.Select(r => new { r.Key, r.Value, Binary = r.BinaryValue != null, r.ModifiedDateUtc });
});

app.Run();
