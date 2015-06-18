import Benchmarks

Benchmarks.@benchmarkable(
    sin_benchmark!,
    nothing,
    sin(2.0),
    nothing
)

r = Benchmarks.execute(sin_benchmark!)

e = Benchmarks.Environment()

writecsv("environment.csv", e)

writecsv("samples.csv", r.samples)

Benchmarks.@benchmarkable(
    digamma_benchmark!,
    nothing,
    digamma(2.0),
    nothing
)

r = Benchmarks.execute(digamma_benchmark!)

# Samples are clearly non-independent, so CI's are probably anti-conservative
x, y = r.samples.n_evals, r.samples.elapsed_times
idx = find(x .== maximum(x))
x = x[idx]
y = y[idx]
n = length(idx)
cor(y[1:(n - 1)], y[2:n])

Benchmarks.@benchmarkable(
    svd2_benchmark!,
    nothing,
    svd(randn(100, 100)),
    nothing
)

r = Benchmarks.execute(svd2_benchmark!)

Benchmarks.@benchmarkable(
    sleep_benchmark!,
    nothing,
    sleep(7.5),
    nothing
)

r = Benchmarks.execute(sleep_benchmark!)

Benchmarks.@benchmark(sin(2.0))
Benchmarks.@benchmark(svd(rand(1000, 1000)))

using Benchmarks

@benchmark svd(rand(1, 1))
