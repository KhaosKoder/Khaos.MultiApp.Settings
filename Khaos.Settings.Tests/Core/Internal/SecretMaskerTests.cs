using FluentAssertions;
using Khaos.Settings.Core.Internal;

namespace Khaos.Settings.Tests.Core.Internal;

public class SecretMaskerTests
{
    [Theory]
    [InlineData(null, "")]
    [InlineData("", "")]
    [InlineData("abc", "***")]
    [InlineData("abcd", "****")]
    [InlineData("abcdef", "ab**ef")]
    [InlineData("abcdefgh", "ab****gh")]
    public void Mask_ReturnsExpectedStrings(string? input, string expected)
    {
        SecretMasker.Mask(input).Should().Be(expected);
    }
}
