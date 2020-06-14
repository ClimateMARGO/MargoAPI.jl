import Dates: isleapyear, Date
import HTTP
import MsgPack

include("./boring.jl")


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


run(2345)