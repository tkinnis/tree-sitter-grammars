package main

import "math"

type Point struct {
	X float64
}

func greet() {}

func (p Point) Norm() float64 {
	greet()
	n := len(p.Name())
	return math.Sqrt(p.X) + float64(n)
}
