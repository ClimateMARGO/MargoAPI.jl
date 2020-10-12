include("./server.jl")

ENV["JULIA_MARGO_LOAD_PYPLOT"] = "no thank you"
import ClimateMARGO
using ClimateMARGO.Models
using ClimateMARGO.Optimization
using ClimateMARGO.Diagnostics

# some silly code to make our custom types work with MsgPack (JSON alternative)
import MsgPack
MsgPack.msgpack_type(::Type{ClimateModel}) = MsgPack.StructType()
MsgPack.msgpack_type(::Type{ClimateModelParameters}) = MsgPack.StructType()
MsgPack.msgpack_type(::Type{Domain}) = MsgPack.StructType()
MsgPack.msgpack_type(::Type{Economics}) = MsgPack.StructType()
MsgPack.msgpack_type(::Type{Physics}) = MsgPack.StructType()
MsgPack.msgpack_type(::Type{Controls}) = MsgPack.StructType()

function setfieldconvert!(value, name::Symbol, x)
    setfield!(value, name, convert(typeof(getfield(value, name)), x))
end
# the main margo function
# has only two parameters for now, but this will be _all parameters_ soon
@expose function opt_controls_temp(;dt=20, opt_parameters, economics=Dict(), physics=Dict())
    model_parameters = deepcopy(ClimateMARGO.IO.included_configurations["default"])::ClimateModelParameters
    model_parameters.domain = Domain(Float64(dt), 2020.0, 2200.0)
    model_parameters.economics.baseline_emissions = ramp_emissions(model_parameters.domain)
    model_parameters.economics.extra_CO₂ = zeros(size(model_parameters.economics.baseline_emissions))

    for (k, v) in economics
        setfieldconvert!(model_parameters.economics, Symbol(k), v)
    end
    for (k, v) in physics
        setfieldconvert!(model_parameters.physics, Symbol(k), v)
    end
    
    model = ClimateModel(model_parameters)

    parsed = Dict((Symbol(k) => v) for (k, v) in opt_parameters)
    model_optimizer = optimize_controls!(model; parsed..., print_raw_status=false)
    return Dict(
        :model_parameters => model_parameters,
        :controls => model.controls,
        :computed => Dict(
            :temperatures => Dict(
                :baseline => T(model),
                :M => T(model; M=true),
                :MR => T(model; M=true, R=true),
                :MRG => T(model; M=true, R=true, G=true),
                :MRGA => T(model; M=true, R=true, G=true, A=true),
            ),
            :emissions => Dict(
                :baseline => effective_emissions(model),
                :M => effective_emissions(model; M=true),
                :MRGA => effective_emissions(model; M=true, R=true),
            ),
            :concentrations => Dict(
                :baseline => c(model),
                :M => c(model; M=true),
                :MRGA => c(model; M=true, R=true),
            ),
            :damages => Dict(
                :baseline => costs_dict(damage(model; discounting=true), model),
                :MRGA => costs_dict(damage(model; M=true, R=true, G=true, A=true, discounting=true), model),
            ),
            :costs => Dict(
                :M => costs_dict(cost(model; M=true, discounting=true), model),
                :R => costs_dict(cost(model; R=true, discounting=true), model),
                :G => costs_dict(cost(model; G=true, discounting=true), model),
                :A => costs_dict(cost(model; A=true, discounting=true), model),
                :MRGA => costs_dict(cost(model; M=true, R=true, G=true, A=true, discounting=true), model),
            ),
        ),
        :status => ClimateMARGO.Optimization.JuMP.termination_status(model_optimizer) |> string
    )
end

function costs_dict(costs, model)
    Dict(
        :discounted => costs,
        :total_discounted => sum(costs .* model.domain.dt),
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