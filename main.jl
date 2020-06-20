if length(ARGS) != 2
    error("Usage: julia thisfile.jl 127.0.0.1 1234")
end

include("./server.jl")

using ClimateMARGO

# some silly code to make our custom types work with MsgPack (JSON alternative)
import MsgPack
MsgPack.msgpack_type(::Type{ClimateMARGO.ClimateModel}) = MsgPack.StructType()
MsgPack.msgpack_type(::Type{ClimateMARGO.Economics}) = MsgPack.StructType()
MsgPack.msgpack_type(::Type{ClimateMARGO.Physics}) = MsgPack.StructType()
MsgPack.msgpack_type(::Type{ClimateMARGO.Controls}) = MsgPack.StructType()


# the main margo function
# has only to parameters for now, but this will be _all parameters_ soon
@expose function opt_controls_temp(;dt=20, T_max)
    t = 2020.0:dt:2200.0
    model = ClimateModel(; t=collect(t), dt=step(t))
    optimize_controls!(model; temp_goal=T_max)
    return model
end

# simple function as baseline for connection speed
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

# start running the server
run(ARGS[1], parse(Int64, ARGS[2]))
