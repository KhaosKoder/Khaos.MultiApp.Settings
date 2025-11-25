using FluentAssertions;
using Khaos.Settings.Encryption;

namespace Khaos.Settings.Tests.Encryption;

public class NoOpEncryptionProviderTests
{
    [Fact]
    public void EncryptDecrypt_ArePassThrough()
    {
        var provider = new NoOpEncryptionProvider();
        provider.Encrypt("secret").Should().Be("secret");
        provider.Decrypt("cipher").Should().Be("cipher");
    }
}
