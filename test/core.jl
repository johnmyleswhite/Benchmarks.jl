import Benchmarks

Benchmarks.@benchmarkable(
    sin_benchmark!,
    nothing,
    sin(2.0),
    nothing
)

n_calls = 1
n_samples = 100
p = Benchmarks.Plan(n_calls, n_samples)
s = Benchmarks.Samples(p)

sin_benchmark!(p, s)

Benchmarks.summarize(p, s)

p, s, x, y = Benchmarks.execute(sin_benchmark!)
a, b = linreg(x, y)

Benchmarks.@benchmarkable(
    digamma_benchmark!,
    nothing,
    digamma(2.0),
    nothing
)

p, s, x, y = Benchmarks.execute(digamma_benchmark!)
a, b = linreg(x, y)

# Samples are clearly non-independent, so CI's are probably anti-conservative
idx = find(x .== maximum(x))
calls = x[idx]
times = y[idx]
n = length(idx)
cor(y[1:(n - 1)], y[2:n])
