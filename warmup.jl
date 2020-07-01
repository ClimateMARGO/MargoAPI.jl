# run our functions once so that they start precompiling
println("Warm-up start")

include("./main.jl")
opt_controls_temp(;T_max=2.0)

println("Warm-up done")
