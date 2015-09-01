# Perform a univariate OLS regression (with non-zero intercept) to estimate the
# per-evaluation execution time of an expression.
#
# Arguments:
#
#     x::Vector{Float64}: The number of times the expression was evaluated.
#
#     y::Vector{Float64}: The total execution time of the expression's
#         (potentially repeated) evaluation.
#
# Returns:
#
#     a::Float64: The intercept of the univariate OLS model.
#
#     b::Float64: The slope of the univariate OLS model.
#
#     r²::Float64: The r-squared of the univariate OLS regresion

function ols(x::Vector{Float64}, y::Vector{Float64})
    a, b = linreg(x, y)
    r² = 1 - var(a + b * x - y) / var(y)
    return a, b, r²
end

function sem_ols(x::Vector{Float64}, y::Vector{Float64})
    a, b = linreg(x, y)
    n = length(x)
    residuals = y - (a + b * x)
    sem_b = sqrt(((1 / (n - 2)) * sum(residuals.^2)) / sum((x - mean(x)).^2))
    return sem_b
end
