using System;
using Xunit;

namespace Geometry.Tests;

public readonly struct Point
{
    public Point(double x, double y) => (X, Y) = (x, y);

    public double X { get; }

    public double Y { get; }

    public double DistanceTo(Point other) => Math.Sqrt(Square(other.X - X) + Square(other.Y - Y));

    private static double Square(double value) => value * value;
}

public record Segment(Point Start, Point End)
{
    public double Length() => Start.DistanceTo(End);
}

public record struct Range(double Low, double High)
{
    public bool Contains(double value) => Low <= value && value <= High;

    public struct Enumerator
    {
        public bool MoveNext() => false;
    }
}

public record class Polygon(Point[] Corners)
{
    public int Sides() => Corners.Length;
}

public record Marker;

public class PointTests
{
    [Fact]
    public void MeasuresTheDistanceBetweenTwoPoints() => Assert.Equal(5, new Point(0, 0).DistanceTo(new Point(3, 4)));
}
