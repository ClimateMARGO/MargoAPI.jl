# run our functions once so that they start precompiling
println("Warm-up start")

include("./main.jl")
opt_controls_temp(;opt_parameters=Dict("temp_goal" => 2.0))

println("Warm-up done")
