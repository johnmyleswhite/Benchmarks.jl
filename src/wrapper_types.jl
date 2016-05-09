# A Benchmark object represents a single "benchmarkable" that has an associated
# name for logging purposes.
#
# Fields:
#
#    name::String: The name of the benchmark.
#
#    f!::Function: A function that implements the "benchmarkable" protocol.

immutable Benchmark
    name::Compat.String
    f!::Function
end

# A BenchmarkSuite object represents a suite of related benchmarks.
#
# Fields:
#
#     name::String: The name of the suite of benchmarks.
#
#     benchmarks::Vector{Benchmark}: A vector of the benchmarks in the suite.

immutable BenchmarkSuite
    name::Compat.String
    benchmarks::Vector{Benchmark}
end
