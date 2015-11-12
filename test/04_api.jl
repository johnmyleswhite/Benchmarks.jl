# Ensure that the `@benchmark` user-facing API supports the following cases:
using Benchmarks
# no-op function calls:
f() = nothing
@benchmark f()

# infix operators
@benchmark (3.0+5im)^3.2

# indexing
A = rand(2,2)
@benchmark A[end,end]

# Keyword arguments
@benchmark svds(A, nsv=1)

# local scopes
x = 1
let B = copy(A), y = 2
    @benchmark B[1]
    @benchmark x+y
end
