# Estimate the best-case resolution of benchmark timings based on the
# system clock in nanoseconds.
#
# Arguments:
#
#     n_samples::Integer: The number of times we call the system clock to
#         estimate its resolution. Defaults to 10,000 calls.
#
# Returns:
#
#     t::Float64: The estimated clock resolutio in nanoseconds.

function estimate_clock_resolution(n_samples::Integer = 10_000)
    t = typemax(Float64)

    for s in 1:n_samples
        t1 = Base.time_ns()
        t2 = Base.time_ns()
        elapsed = convert(Float64, t2 - t1)
        t = min(t, elapsed)
    end

    t
end
