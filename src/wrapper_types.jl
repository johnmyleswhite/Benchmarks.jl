# A Benchmark object represents a single "benchmarkable" that has an associated
# name for logging purposes.
#
# Fields:
#
#    name::UTF8String: The name of the benchmark.
#
#    f!::Function: A function that implements the "benchmarkable" protocol.

immutable Benchmark
    name::UTF8String
    f!::Function
end

# A BenchmarkSuite object represents a suite of related benchmarks.
#
# Fields:
#
#     name::UTF8String: The name of the suite of benchmarks.
#
#     benchmarks::Vector{Benchmark}: A vector of the benchmarks in the suite.

immutable BenchmarkSuite
    name::UTF8String
    benchmarks::Vector{Benchmark}
end
