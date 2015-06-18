# Estimate the best-case resolution (in nanoseconds) of benchmark timings based
# on the system clock.
#
# Arguments:
#
#     n_samples::Integer: The number of times we call the system clock to
#         estimate its resolution. Defaults to 10,000 calls.
#
# Returns:
#
#     res::Float64: The estimated clock resolutio in nanoseconds.
#
# TODO:
#
#     This function is known to not work on Windows because of the behavior
#     of `time_ns` on that platform.

function estimate_clock_resolution(n_samples::Integer = 10_000)
    res = typemax(Float64)

    for s in 1:n_samples
        t1 = Base.time_ns()
        t2 = Base.time_ns()
        dt = convert(Float64, t2 - t1)
        res = min(res, dt)
    end

    res
end
