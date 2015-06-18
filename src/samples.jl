# A Samples object represents all of the logged information about the execution
# of a benchmark. Each object contains five vectors of equal length.
#
# Fields:
#
#     n_evals::Vector{Float64}: The number of times the expression was
#         evaluated for every sample.
#
#     elapsed_times::Vector{Float64}: The execution time in nanoseconds for
#         every sample.
#
#     bytes_allocated::Vector{Int}: The total number of bytes allocated for
#         every sample.
#
#     gc_times::Vector{Float64}: The GC time in nanoseconds for every sample.
#
#     num_allocations::Vector{Int}: The total number of allocation operations
#         for every sample.

immutable Samples
    n_evals::Vector{Float64}
    elapsed_times::Vector{Float64}
    bytes_allocated::Vector{Int}
    gc_times::Vector{Float64}
    num_allocations::Vector{Int}

    function Samples()
        new(
            Array(Float64, 0),
            Array(Float64, 0),
            Array(Int, 0),
            Array(Float64, 0),
            Array(Int, 0),
        )
    end
end

# Empty all of the five vectors from a Samples object.
#
# Arguments:
#
#     s::Samples: The Samples object whose contents should be emptied.

function Base.empty!(s::Samples)
    empty!(s.n_evals)
    empty!(s.elapsed_times)
    empty!(s.bytes_allocated)
    empty!(s.gc_times)
    empty!(s.num_allocations)
    return
end


# Pretty-print information about the Samples object.
#
# Arguments:
#
#     io::IO: An IO object to be written to.
#
#     s::Samples: The Samples object that we want to print to `io`.

function Base.show(io::IO, s::Samples)
    n = length(s.elapsed_times)
    @printf(io, "================== Benchmark Samples ==================\n")
    @printf(io, " %s %s\n", lpad("Number of samples:", 17), n)
    @printf(io, " %s %s", lpad("Number of metrics:", 17), 5)
end

# Log information about the environment in which benchmarks are being executed
# to a TSV file.
#
# Arguments:
#
#     filename::String: The name of a file to which we'll write information
#         the environment object, `e`.
#
#     e::Environment: The environment that we want to log to disk.
#
#     append::Bool: Should we write a new file or append to an existing one?
#         Defaults to false.

function Base.writecsv(filename::String, e::Environment, append::Bool = false)
    if append
        io = open(filename, "a")
    else
        io = open(filename, "w")
    end
    println(
        io,
        join(
            [
                "uuid",
                "timestamp",
                "julia_sha1",
                "package_sha1",
                "os",
                "cpu_cores",
                "arch",
                "machine",
                "use_blas64",
                "word_size",
            ],
            "\t"
        )
    )
    println(
        io,
        join(
            [
                e.uuid,
                e.timestamp,
                e.julia_sha1,
                get(e.package_sha1, "NULL"),
                e.os,
                string(e.cpu_cores),
                e.arch,
                e.machine,
                string(e.use_blas64),
                string(e.word_size),
            ],
            "\t"
        )
    )
    close(io)
end

# Log information about a set of samples to a TSV file.
#
# Arguments:
#
#     filename::String: The name of a file to which we'll write information
#         the Samples object, `s`.
#
#     s::Samples: The set of samples that we want to log to disk.
#
#     append::Bool: Should we write a new file or append to an existing one?
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
                "n_evals",
                "elapsed_times",
                "bytes_allocated",
                "gc_times",
                "num_allocations",
            ],
            "\t"
        )
    )
    for i in 1:length(s.n_evals)
        println(
            io,
            join(
                [
                    string(s.n_evals[i])
                    string(s.elapsed_times[i])
                    string(s.bytes_allocated[i])
                    string(s.gc_times[i])
                    string(s.num_allocations[i])
                ],
                "\t"
            )
        )
    end
    close(io)
end
