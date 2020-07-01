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
                :baseline => costs_dict(damage_cost_baseline(model), model),
                :controlled => costs_dict(damage_cost(model), model),
            ),
            :costs => Dict(
                :M => costs_dict(model.economics.mitigate_cost .* model.economics.GWP .* f(model.controls.mitigate), model),
                :R => costs_dict(model.economics.remove_cost .* f(model.controls.remove), model),
                :G => costs_dict(model.economics.geoeng_cost .* model.economics.GWP .* f(model.controls.geoeng), model),
                :A => costs_dict(model.economics.adapt_cost .* f(model.controls.adapt), model),
                :controlled => costs_dict(control_cost(model), model),
            ),
        ),
        :status => ClimateMARGO.JuMP.termination_status(model_optimizer) |> string
    )
end

function costs_dict(costs, model)
    disc = discounting(model) .* costs
    Dict(
        # :costs => costs,
        # :total_costs => sum(costs .* model.dt),
        :discounted => disc,
        :total_discounted => sum(disc .* model.dt),
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