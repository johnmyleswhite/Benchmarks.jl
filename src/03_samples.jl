# A `Samples` object represents all of the logged information about the
# execution of a benchmark. Each object contains five vectors of equal length.
#
# Fields:
#
#     evaluations::Vector{Float64}: The number of times the expression was
#         evaluated for each sample. NB: We use a `Float64` vector to avoid
#         type conversion when calling the `linreg()` function, although we
#         always evaluate functions an integral number of times.
#
#     elapsed_times::Vector{Float64}: The execution time in nanoseconds for
#         each sample. NB: We use a `Float64` vector to avoid type conversion
#         when calling the `linreg()` function, although the timing functions
#         use `Uint` values to represent nanoseconds.
#
#     gc_times::Vector{Float64}: The GC time in nanoseconds for each sample.
#         NB: We use a `Float64` vector for similarity with `elapsed_times`,
#         although the timing functions use `Uint` values to represent
#         nanoseconds.
#
#     bytes_allocated::Vector{Int}: The total number of bytes allocated during
#         each sample.
#
#     allocations::Vector{Int}: The total number of allocation operations
#         performed during each sample.

immutable Samples
    evaluations::Vector{Float64}
    elapsed_times::Vector{Float64}
    gc_times::Vector{Float64}
    bytes_allocated::Vector{Int}
    allocations::Vector{Int}

    function Samples()
        new(
            Array(Float64, 0),
            Array(Float64, 0),
            Array(Float64, 0),
            Array(Int, 0),
            Array(Int, 0),
        )
    end
end

# Push values for all metrics to a `Samples` object.
#
# Arguments:
#
#     s::Samples: The `Samples` object whose contents should be emptied.
#
#     evaluations::Real: The number of evaluations of the core expression for
#         this core expression.
#
#     elapsed_time::Real: The time in nanoseconds to evaluate the core
#         expression.
#
#     gc_time::Real: The time spent in the GC while evaluating the core
#         expression.
#
#     bytes_allocated::Real: The number of bytes allocated while evaluating the
#         core expression.
#
#     allocations::Real: The number of allocation operations while evaluating
#         the core expression.

function Base.push!(
    s::Samples,
    evaluations::Real,
    elapsed_time::Real,
    gc_time::Real,
    bytes_allocated::Real,
    allocations::Real,
)
    push!(s.evaluations, evaluations)
    push!(s.elapsed_times, elapsed_time)
    push!(s.gc_times, gc_time)
    push!(s.bytes_allocated, bytes_allocated)
    push!(s.allocations, allocations)
    return
end

# Empty all of the five vectors from a `Samples` object.
#
# Arguments:
#
#     s::Samples: The `Samples` object whose contents should be emptied.

function Base.empty!(s::Samples)
    empty!(s.evaluations)
    empty!(s.elapsed_times)
    empty!(s.gc_times)
    empty!(s.bytes_allocated)
    empty!(s.allocations)
    return
end

# Pretty-print information about the `Samples` object.
#
# Arguments:
#
#     io::IO: An `IO` object to be written to.
#
#     s::Samples: The `Samples` object that we want to print to `io`.

function Base.show(io::IO, s::Samples)
    names = UTF8String["Number of samples"]
    values = Any[length(s.elapsed_times)]

    @printf(io, "================== Benchmark Samples ======================\n")
    max_length = maximum([length(n) for n in names]) +  1
    for (n, v) in zip(names, values)
        @printf(io, "%s: %s\n", lpad(n, max_length), v)
    end
end

# Log information about a set of samples to a CSV file.
#
# Arguments:
#
#     filename::String: The name of a file to which we'll write information
#         the `Samples` object, `s`.
#
#     s::Samples: The set of samples that we want to log to disk.
#
#     append::Bool: Should we overwrite the file or append to existing content?
#         Defaults to false.

function Base.writecsv(filename::String, s::Samples, append::Bool = false)
    if append
        io = open(filename, "a")
    else
        io = open(filename, "w")
    end
    println(
        io,
        join(
            [
                "evaluations",
                "elapsed_time",
                "gc_time",
                "bytes_allocated",
                "allocations",
            ],
            ','
        )
    )
    for i in 1:length(s.evaluations)
        println(
            io,
            join(
                [
                    string(s.evaluations[i]),
                    string(s.elapsed_times[i]),
                    string(s.gc_times[i]),
                    string(s.bytes_allocated[i]),
                    string(s.allocations[i]),
                ],
                ','
            )
        )
    end
    close(io)
end
