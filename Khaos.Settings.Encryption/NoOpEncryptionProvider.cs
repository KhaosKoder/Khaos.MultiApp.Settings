using Khaos.Settings.Interfaces;

namespace Khaos.Settings.Encryption;

public sealed class NoOpEncryptionProvider : IEncryptionProvider
{
    public string Encrypt(string plaintext) => plaintext;
    public string Decrypt(string ciphertext) => ciphertext;
}
