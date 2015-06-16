import Benchmarks

Benchmarks.@benchmarkable(
    sin_benchmark!,
    nothing,
    sin(2.0),
    nothing
)

n_calls = Benchmarks.build_plan(sin_benchmark!)
n_samples = 100
p = Benchmarks.Plan(n_calls, n_samples)
s = Benchmarks.Samples(p)

sin_benchmark!(p, s)

Benchmarks.summarize(p, s)

# Samples are clearly non-independent, so CI's are probably anti-conservative
cor(s.elapsed_times[1:(n_samples - 1)], s.elapsed_times[2:n_samples])
