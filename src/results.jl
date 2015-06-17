immutable Results
    sampling_strategy::Symbol
    estimation_strategy::Symbol
    samples::Samples
end

function Base.show(io::IO, r::Results)
    @printf(io, "=== Benchmarking results ===\n")

    s = r.samples

    if maximum(s.n_evals) == 1.0
        if length(s.n_evals) == 1
            @printf(io, "Sampling strategy: single sampling\n")
            @printf(io, "Number of samples: 1\n")

            samples = s.elapsed_times ./ s.n_evals
            m = mean(samples)
            @printf(io, "Direct CI = [%.2f ms, %.2f ms]\n", m / 10^6, m / 10^6)
        else
            @printf(io, "Sampling strategy: direct sampling\n")
            @printf(io, "Number of samples: %d\n", length(s.n_evals))

            samples = s.elapsed_times ./ s.n_evals
            n = length(samples)
            m = mean(samples)
            sem = std(samples) / sqrt(n)
            lower, upper = m - 1.96 * sem, m + 1.96 * sem

            @printf(io, "Direct CI = [%.2f ms, %.2f ms]\n", lower / 10^6, upper / 10^6)
        end
    else
        @printf(io, "Sampling strategy: OLS sampling\n")
        @printf(io, "Number of samples: %d\n", length(s.n_evals))

        a, b, r² = ols(s.n_evals, s.elapsed_times)

        @printf(io, "OLS estimate = %.2f ns\n", b)
        @printf(io, "R² = %.3f\n", r²)
    end
end
