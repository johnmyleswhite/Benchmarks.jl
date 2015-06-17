import Benchmarks
using Base.Test

res = Benchmarks.estimate_clock_resolution()

@test isa(res, Float64)
@test 1 <= res <= 100_000

res_2 = Benchmarks.estimate_clock_resolution(1_000_000)

@test res_2 <= res

p = Benchmarks.Plan(1, 1)

@test isa(p, Benchmarks.Plan)
@test p.n_calls === 1
@test p.n_samples === 1

s = Benchmarks.Samples(p)

@test isa(s.elapsed_times, Vector{Float64})
@test length(s.elapsed_times) == p.n_samples

@test isa(s.bytes_allocated, Vector{Int})
@test length(s.bytes_allocated) == p.n_samples

@test isa(s.gc_times, Vector{Float64})
@test length(s.gc_times) == p.n_samples

@test isa(s.num_allocations, Vector{Int})
@test length(s.num_allocations) == p.n_samples

p = Benchmarks.Plan(1, 10)

e = Benchmarks.Environment()
