import Benchmarks
using Base.Test

res = Benchmarks.estimate_clock_resolution()

@test isa(res, Float64)
@test 1 <= res <= 100_000

res_2 = Benchmarks.estimate_clock_resolution(1_000_000)

@test res_2 <= res

s = Benchmarks.Samples()

@test isa(s.elapsed_times, Vector{Float64})
@test length(s.elapsed_times) == 0

@test isa(s.bytes_allocated, Vector{Int})
@test length(s.bytes_allocated) == 0

@test isa(s.gc_times, Vector{Float64})
@test length(s.gc_times) == 0

@test isa(s.num_allocations, Vector{Int})
@test length(s.num_allocations) == 0

e = Benchmarks.Environment()
