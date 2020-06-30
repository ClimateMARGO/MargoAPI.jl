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
# has only two parameters for now, but this will be _all parameters_ soon
@expose function opt_controls_temp(;dt=20, T_max)
    t = 2020.0:dt:2200.0
    model = ClimateModel(; t=collect(t), dt=step(t))
    model_optimizer = optimize_controls!(model; temp_goal=T_max, print_raw_status=false)
    return Dict(
        :model => model,
        :computed => Dict(
            :temperatures => Dict(
                :baseline => δT_baseline(model),
                :MR => δT_no_geoeng(model),
                :MRG => δT(model),
                :MRGA => δT(model) .* sqrt.(1. .- model.controls.adapt),
            ),
            :emissions => Dict(
                :baseline => effective_baseline_emissions(model),
                :controlled => effective_emissions(model),
            ),
            :concentrations => Dict(
                :baseline => CO₂_baseline(model),
                :controlled => CO₂(model),
            ),
            :damages => Dict(
                :discounted_cost => discounted_damage_cost(model),
                :total_discounted_cost => discounted_total_damage_cost(model),
            ),
            :controls => Dict(
                :discounted_cost => discounted_control_cost(model),
                :total_discounted_cost => discounted_total_control_cost(model),
            ),
        ),
        :status => ClimateMARGO.JuMP.termination_status(model_optimizer) |> string
    )
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
