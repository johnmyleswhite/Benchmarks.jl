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
#     min_Δt::UInt: The estimated clock resolution in nanoseconds.
#
# TODO:
#
#     This function is known to not work on Windows because of the behavior
#     of `time_ns()` on that platform.

function estimate_clock_resolution(n_samples::Integer = 10_000)
    min_Δt = typemax(UInt)

    for _ in 1:n_samples
        t1 = Base.time_ns()
        t2 = Base.time_ns()
        Δt = t2 - t1
        min_Δt = min(min_Δt, Δt)
    end

    min_Δt
end
