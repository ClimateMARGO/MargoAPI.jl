if length(ARGS) != 2
    error("Usage: julia thisfile.jl 127.0.0.1 1234")
end

import Dates: isleapyear, Date
import HTTP

include("./server.jl")


@expose function wow(;a, b)
    x = fill(a, 10)
    y = fill(b, 10)

    img = rand(UInt8, 256 * 256 * 4)

    Dict(
        :sum => x .+ y,
        :diff => x .- y,
        :img => img,
    )
end

run(ARGS[1], parse(Int64, ARGS[2]))
