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
        :status => ClimateMARGO.Optimization.JuMP.termination_status(model_optimizer) |> string,
        model_results(model)...
    )
end

@expose function forward_controls_temp(;dt=20, controls=Dict(), economics=Dict(), physics=Dict())
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

    translations = Dict(
        :M => :mitigate,
        :R => :remove,
        :G => :geoeng,
        :A => :adapt,
    )
    for (k, v) in controls
        setfieldconvert!(model.controls, translations[Symbol(k)], v)
    end

    enforce_maxslope!(model.controls; dt=dt)

    return Dict(
        :model_parameters => model_parameters,
        model_results(model)...
    )
end


model_results(model::ClimateModel) = Dict(
    :controls => model.controls,
    :computed => Dict(
        :temperatures => Dict(
            :baseline => T_adapt(model),
            :M => T_adapt(model; M=true),
            :MR => T_adapt(model; M=true, R=true),
            :MRG => T_adapt(model; M=true, R=true, G=true),
            :MRGA => T_adapt(model; M=true, R=true, G=true, A=true),
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
)








function costs_dict(costs, model)
    Dict(
        :discounted => costs,
        :total_discounted => sum(costs .* model.domain.dt),
    )
end

function enforce_maxslope!(controls;
    dt,
    max_slope=Dict("mitigate"=>1. /40., "remove"=>1. /40., "geoeng"=>1. /80., "adapt"=> 0.)
    )
    controls.mitigate[1] = 0.0
    controls.remove[1] = 0.0
    controls.geoeng[1] = 0.0
    # controls.adapt[1] = 0.0


    for i in 2:length(controls.mitigate)
        controls.mitigate[i] = clamp(
            controls.mitigate[i], 
            controls.mitigate[i-1] - max_slope["mitigate"]*dt, 
            controls.mitigate[i-1] + max_slope["mitigate"]*dt
        )
        controls.remove[i] = clamp(
            controls.remove[i], 
            controls.remove[i-1] - max_slope["remove"]*dt, 
            controls.remove[i-1] + max_slope["remove"]*dt
        )
        controls.geoeng[i] = clamp(
            controls.geoeng[i], 
            controls.geoeng[i-1] - max_slope["geoeng"]*dt, 
            controls.geoeng[i-1] + max_slope["geoeng"]*dt
        )
        controls.adapt[i] = clamp(
            controls.adapt[i], 
            controls.adapt[i-1] - max_slope["adapt"]*dt, 
            controls.adapt[i-1] + max_slope["adapt"]*dt
        )
    end
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