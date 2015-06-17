Benchmarks.jl
=============

A package to make Julia benchmarking both easy and rigorous.

```jl
import Benchmarks
Benchmarks.@benchmark(sin(2.0))
Benchmarks.@benchmark(exp(sin(2.0) + cos(2.0)))
Benchmarks.@benchmark(svd(rand(10, 10)))
```
