if length(ARGS) != 2
    error("Usage: julia thisfile.jl 127.0.0.1 1234")
end

include("./server.jl")


using JuMP
import Ipopt

model = Model(Ipopt.Optimizer)

@variable(model, 0 <= root)

@expose function opt_sqrt(;x)
    @NLobjective(model, Min, (root^2 - x)^2)
    optimize!(model)

    value(root)
end

@expose function arithmetic(;a, b)
    Dict(
        :sum => a + b,
        :difference => a - b,
    )
end

@expose function randimage(;width, height)
    img = rand(UInt8, width * height * 4)

    Dict(
        :img => img,
    )
end

run(ARGS[1], parse(Int64, ARGS[2]))
