using Khaos.Settings.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace Khaos.Settings.Data;

public class KhaosSettingsDbContext : DbContext
{
    public DbSet<SettingEntity> Settings => Set<SettingEntity>();
    public DbSet<SettingsHistoryEntity> SettingsHistory => Set<SettingsHistoryEntity>();

    public KhaosSettingsDbContext(DbContextOptions<KhaosSettingsDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Filtered unique indexes cannot be fully expressed via fluent API for filters; use raw SQL in migrations (consumer-managed).
        modelBuilder.Entity<SettingEntity>()
            .HasIndex(x => new { x.Key })
            .HasDatabaseName("UX_Settings_Global_Key")
            .HasFilter("[ApplicationId] IS NULL AND [InstanceId] IS NULL")
            .IsUnique();
        modelBuilder.Entity<SettingEntity>()
            .HasIndex(x => new { x.ApplicationId, x.Key })
            .HasDatabaseName("UX_Settings_App_Key")
            .HasFilter("[ApplicationId] IS NOT NULL AND [InstanceId] IS NULL")
            .IsUnique();
        modelBuilder.Entity<SettingEntity>()
            .HasIndex(x => new { x.ApplicationId, x.InstanceId, x.Key })
            .HasDatabaseName("UX_Settings_Instance_Key")
            .HasFilter("[ApplicationId] IS NOT NULL AND [InstanceId] IS NOT NULL")
            .IsUnique();

        modelBuilder.Entity<SettingEntity>()
            .HasIndex(x => new { x.ApplicationId, x.InstanceId, x.Key })
            .HasDatabaseName("IX_Settings_Scope_Key");

        modelBuilder.Entity<SettingsHistoryEntity>()
            .HasIndex(x => x.SettingId)
            .HasDatabaseName("IX_SettingsHistory_SettingId");

        modelBuilder.Entity<SettingsHistoryEntity>()
            .HasIndex(x => new { x.ApplicationId, x.InstanceId, x.Key, x.ChangedDate })
            .HasDatabaseName("IX_SettingsHistory_KeyScopeDate");
    }
}
