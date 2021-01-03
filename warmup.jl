# run our functions once so that they start precompiling
println("Warm-up start")

include("./main.jl")
@info "Warm-up: optimizing"
for tmax in 0.0:0.5:4.0
    # we go from infeasible to feasible, should trigger most of JuMP's relevant internals
    result = opt_controls_temp(;opt_parameters=Dict("temp_goal" => tmax, "temp_final" => tmax))
    result = opt_controls_temp(;opt_parameters=Dict("temp_goal" => 999.0, "temp_final" => tmax))
    MsgPack.pack(result)
end
forward_controls_temp()

@info "Warm-up: HTTP server"
t = @async run("127.0.0.1", 40404)

sleep(5)
download("http://127.0.0.1:40404/index.html")

# this is async because it blocks for some reason
@async Base.throwto(t, InterruptException())
sleep(2) # i am pulling these numbers out of thin air


println("Warm-up done")
