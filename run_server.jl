if length(ARGS) != 2
    error("Usage: julia thisfile.jl 127.0.0.1 1234")
end

include("./main.jl")

# start running the server
run(ARGS[1], parse(Int64, ARGS[2]))
