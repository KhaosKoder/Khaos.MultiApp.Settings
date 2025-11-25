using FluentAssertions;
using Khaos.Settings.Util;
using Xunit;

namespace Khaos.Settings.Tests.Util;

public class RowVersionUtilTests
{
    [Fact]
    public void ToHexAndFromHex_RoundTrip()
    {
        var bytes = new byte[] { 0, 1, 2, 255 };
        var hex = RowVersionUtil.ToHex(bytes);
        hex.Should().Be("000102FF");
        RowVersionUtil.FromHex(hex).Should().Equal(bytes);
    }
}
