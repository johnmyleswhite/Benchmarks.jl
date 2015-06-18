# The @benchmark macro generates a simple benchmark for an expression, then
# executes that benchmark.
#
# Arguments:
#
#     core: The core expression that will be executed.
#
# Generates:
#
#     A begin expression that contains:
#
#     (1) A function expression that defines a new "benchmarkable" function
#         with a name chosen by `gensym`.
#
#     (2) A call to `execute` to provide the results of running the
#         "benchmarkable" function.

macro benchmark(core)
    name = esc(gensym())
    quote
        begin
            Benchmarks.@benchmarkable(
                $name,
                nothing,
                $(esc(core)),
                nothing
            )
            Benchmarks.execute($name)
        end
    end
end
