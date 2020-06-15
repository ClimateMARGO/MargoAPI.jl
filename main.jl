if length(ARGS) != 2
    error("Usage: julia thisfile.jl 127.0.0.1 1234")
end

include("./server.jl")


using JuMP
import Ipopt

model = Model(optimizer_with_attributes(Ipopt.Optimizer,
"acceptable_tol" => 1.e-8, "max_iter" => Int64(1e8),
"acceptable_constr_viol_tol" => 1.e-3, "constr_viol_tol" => 1.e-4,
"print_frequency_iter" => 50,  "print_timing_statistics" => "no",
"print_level" => 0,
))

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
