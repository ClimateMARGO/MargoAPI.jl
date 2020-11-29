# MargoAPI.jl

## _Interactive web-based articles for [ClimateMARGO.jl](https://github.com/ClimateMARGO/ClimateMARGO.jl)_

Have a look at our [Observable page](https://observablehq.com/@margo)!

![margo](https://user-images.githubusercontent.com/6933510/100540548-37c5c080-323e-11eb-9a0c-aab28772792d.gif)

## Backend

This repository contains the "backend" for our interactive articles written in [Observable](https://observablehq.com/@margo). It imports the ClimateMARGO.jl package, and wraps its important functionality in API functions.

This repository is deployed online using heroku. See [the API client notebook](https://observablehq.com/@margo/api) to learn more.

## Technology

Powering this API is a _super fast & simple_ web framework for Julia. Write functions that take _keyword arguments_ and return _simple objects_.

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

It was created by stripping down [Pluto.jl](https://github.com/fonsp/Pluto.jl) to just its communication code.

#### Features

It uses _WebSockets_ for optimal ping time (2ms on `localhost`) and _MessagePack_ for minimal (de)serialization overhead and minimal bandwidth usage. (A round trip to a Julia function returning a 1M-element `Array{UInt8}` is about 20ms - you could stream uncompressed 512x512 images at 60fps 😮.) We also have automatic timeout and reconnect.

## Heroku deployment

### Updating the deployment

We currently have two deployments:

-   **master** ([link to app](https://margo-api-test-1.herokuapp.com/)), [link to heroku for Fons & Henri](https://dashboard.heroku.com/apps/margo-api-test-1));
-   **staging** for the WIP latest updates ([link to app](https://margo-api-staging.herokuapp.com/), [link to heroku for Fons & Henri](https://dashboard.heroku.com/apps/margo-api-staging)).

These correspond to two branches of this repository with the same names.

To update the web app at heroku, we simply _push a commit to the branch_. The

_For more background on deploying Julia apps on heroku, I wrote this guide, intended for a more general audience: [fonsp/How to put Julia on heroku.md ](https://gist.github.com/fonsp/38965d7595a5d1060e27d6ca2084778d)._

### Creating a new deployment

Read the guide above for some basics. Some notes specific for this project:

-   You need to set a "Config Var" in the _Settings_ page of your heroku app: `JULIA_MARGO_LOAD_PYPLOT` with value `nothanks`. Trigger a rebuild afterwards by committing. [more info](https://github.com/ClimateMARGO/ClimateMARGO.jl/pull/53)
-   We tried to minimize Julia's compile time for the first request, but you will still benefit from using a "Hobby Dyno" (7$/month) instead of a free dyno.

## Running locally

Clone the repository, navigate to this folder, and then:

```
julia --project run_server.jl 127.0.0.1 2345
```

Then go to `http://localhost:2345/index.html` in your browser. This is only really useful to check for errors, since it does not include the visualisations. To connect an observable notebook to a local running instance of the server, you can use `ngrok`. In a second terminal, install ngrok and run:

```
./ngrok http 2345
```

You can then change the cell `margo_url` in the notebook to the https url that gave you, instead of the default. Contact me (fons) for more info.

# Contact

If any of this is interesting to you, get in touch!

— Henri Drake ([hdrake](https://github.com/hdrake)) & Fons van der Plas ([fonsp](https://github.com/fonsp))
