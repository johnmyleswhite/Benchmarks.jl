# Perform an OLS regression to estimate the per-eval execution time of an
# expression.
#
# Arguments:
#
#     x::Vector{Float64}: The number of times the expression was evaluated.
#
#     y::Vector{Float64}: The total execution time of the expression's repeated
#         evaluation.
#
# Returns:
#
#     a::Float64: The intercept of the univariate OLS model.
#
#     b::Float64: The slope of the univariate OLS model.
#
#     r²::Float64: The r-squared of the OLS regresion

function ols(x::Vector{Float64}, y::Vector{Float64})
    a, b = linreg(x, y)
    r² = 1 - var(a + b * x - y) / var(y)
    return a, b, r²
end
