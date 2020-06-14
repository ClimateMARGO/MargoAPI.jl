# MargoAPI.jl

Still in development - right now it houses a _super fast & simple_ web framework for Julia:

Write functions that take _keyword arguments_ and return _simple objects_.
```julia
@expose function wow(;a, b)
    Dict(
        :sum => a + b,
        :diff => a - b,
    )
end
```

You can then use them inside JavaScript:

```js
sendreceive("wow", {
    a: 7, 
    b: 6, 
}).then((val) => {
    console.log(val.sum)
    console.log(val.diff)
})
```

It uses _WebSockets_ for optimal ping time (2ms on `localhost`) and _MessagePack_ for minimal (de)serialization overhead and minimal bandwidth usage. (A round trip to a Julia function returning a 1M-element `Array{UInt8}` is about 20ms - you could stream uncompressed 512x512 images at 60fps 😮.)

Based on [fonsp/Pluto.jl](https://github.com/fonsp/Pluto.jl)
