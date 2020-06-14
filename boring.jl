import JSON
import UUIDs: UUID
import HTTP
import Sockets

"Will hold all 'response handlers': functions that respond to a WebSocket request from the client. These are defined in `src/webserver/Dynamic.jl`."
const funkies = Dict{Symbol, Function}()

macro expose(funcdef::Expr)
    quote
        funky = $(esc(funcdef))
        funkies[nameof(funky)] = funky
    end
end

function Base.endswith(vec::Vector{T}, suffix::Vector{T}) where T
    local liv = lastindex(vec)
    local lis = lastindex(suffix)
    liv >= lis && (view(vec, (liv-lis + 1):liv) == suffix)
end

# function Base.endswith(vec::Array{UInt8,1}, suffix::Array{UInt8,1})
#     local liv = lastindex(vec)
#     local lis = lastindex(suffix)
#     liv >= lis && (view(vec, (liv-lis + 1):liv) == suffix)
# end

function Base.readuntil(stream::HTTP.WebSockets.WebSocket, delim::Vector{UInt8})
    data = UInt8[]
    while !endswith(data, MSG_DELIM)
        if(eof(stream))
            if isempty(data)
                @warn "What is this"
                return data
            end
            @warn "Unexpected eof after" data
            return data
        end
        push!(data, readavailable(stream)...)
    end
    return data[1:end-length(delim)]
end

mutable struct Client
    id::Symbol
    stream::Any
    pendingupdates::Channel
end
Client(id::Symbol, stream) = let
    Client(id, stream, Channel(1024))
end

struct Initiator
    client_id::Symbol
    request_id::Symbol
end

struct UpdateMessage
    type::Symbol
    message::Any
    initiator::Initiator
end
UpdateMessage(type::Symbol, message::Any) = UpdateMessage(type, message, missing)




"Attempts to find the MIME pair corresponding to the extension of a filename. Defaults to `text/plain`."
function mime_fromfilename(filename)
    # This bad boy is from: https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types
    mimepairs = Dict(".aac" => "audio/aac", ".bin" => "application/octet-stream", ".bmp" => "image/bmp", ".css" => "text/css", ".csv" => "text/csv", ".eot" => "application/vnd.ms-fontobject", ".gz" => "application/gzip", ".gif" => "image/gif", ".htm" => "text/html", ".html" => "text/html", ".ico" => "image/vnd.microsoft.icon", ".jpeg" => "image/jpeg", ".jpg" => "image/jpeg", ".js" => "text/javascript", ".json" => "application/json", ".jsonld" => "application/ld+json", ".mjs" => "text/javascript", ".mp3" => "audio/mpeg", ".mpeg" => "video/mpeg", ".oga" => "audio/ogg", ".ogv" => "video/ogg", ".ogx" => "application/ogg", ".opus" => "audio/opus", ".otf" => "font/otf", ".png" => "image/png", ".pdf" => "application/pdf", ".rtf" => "application/rtf", ".sh" => "application/x-sh", ".svg" => "image/svg+xml", ".tar" => "application/x-tar", ".tif" => "image/tiff", ".tiff" => "image/tiff", ".ttf" => "font/ttf", ".txt" => "text/plain", ".wav" => "audio/wav", ".weba" => "audio/webm", ".webm" => "video/webm", ".webp" => "image/webp", ".woff" => "font/woff", ".woff2" => "font/woff2", ".xhtml" => "application/xhtml+xml", ".xml" => "application/xml", ".xul" => "application/vnd.mozilla.xul+xml", ".zip" => "application/zip")
    file_extension = getkey(mimepairs, '.' * split(filename, '.')[end], ".txt")
    MIME(mimepairs[file_extension])
end

function assetresponse(path)
    try
        @assert isfile(path)
        response = HTTP.Response(200, read(path, String))
        push!(response.headers, "Content-Type" => string(mime_fromfilename(path)))
        response
    catch e
        HTTP.Response(404, "Not found!: $(e)")
    end
end

function serve_onefile(path)
    return request::HTTP.Request->assetresponse(normpath(path))
end

function serve_asset(req::HTTP.Request)
    reqURI = req.target |> HTTP.URIs.unescapeuri |> HTTP.URI
    
    filepath = joinpath(pwd(), relpath(reqURI.path, "/"))
    assetresponse(filepath)
end







# https://github.com/JuliaWeb/HTTP.jl/issues/382
const flushtoken = Channel{Nothing}(1)
put!(flushtoken, nothing)


const MSG_DELIM = "IUUQ.km jt ejggjdvmu vhi" |> codeunits |> collect # riddle me this, Julius

function write_serialized(io::IO, x::Any)
    write(io, MsgPack.pack(x), MSG_DELIM)
    
end

"""Start a Pluto server _synchronously_ (i.e. blocking call) on `http://localhost:[port]/`.

This will start a WebSocket server. Pluto Notebooks will be started dynamically (by user input)."""
function run(host, port::Integer)
    hostIP = parse(Sockets.IPAddr, host)
    serversocket = Sockets.listen(hostIP, UInt16(port))
    servertask = @async HTTP.serve(hostIP, UInt16(port), stream = true, server = serversocket) do http::HTTP.Stream
        # messy messy code so that we can use the websocket on the same port as the HTTP server

        if HTTP.WebSockets.is_upgrade(http.message)
            try
                HTTP.WebSockets.upgrade(http) do clientstream::HTTP.WebSockets.WebSocket
                    if !isopen(clientstream)
                        return
                    end
                    while !eof(clientstream)
                        # This stream contains data received over the WebSocket.
                        # It is formatted and JSON-encoded by send(...) in editor.html
                        try
                            parentbody = let
                                data = readuntil(clientstream, MSG_DELIM)
                                MsgPack.unpack(data)
                            end
                            process_ws_message(parentbody, clientstream)
                        catch ex
                            if ex isa InterruptException
                                rethrow(ex)
                            elseif ex isa HTTP.WebSockets.WebSocketError
                                # that's fine!
                            elseif ex isa InexactError
                                # that's fine! this is a (fixed) HTTP.jl bug: https://github.com/JuliaWeb/HTTP.jl/issues/471
                                # TODO: remove this switch
                            else
                                bt = stacktrace(catch_backtrace())
                                @warn "Reading WebSocket client stream failed for unknown reason:" exception=(ex,bt)
                            end
                        end
                    end
                end
            catch ex
                if ex isa InterruptException
                    rethrow(ex)
                elseif ex isa Base.IOError
                    # that's fine!
                elseif ex isa ArgumentError && occursin("stream is closed", ex.msg)
                    # that's fine!
                else
                    bt = stacktrace(catch_backtrace())
                    @warn "HTTP upgrade failed for unknown reason" exception=(ex,bt)
                end
            end
        else
            request::HTTP.Request = http.message
            HTTP.closeread(http)
            response_body = serve_asset(http.message)

            request.response::HTTP.Response = response_body
            request.response.request = request

            HTTP.startwrite(http)
            write(http, request.response.body)
            HTTP.closewrite(http)
        end
    end

    root_url = get(ENV, "PLUTO_ROOT_URL", "/")
    address = if root_url == "/"
        hostPretty = (hostStr = string(hostIP)) == "127.0.0.1" ? "localhost" : hostStr
        portPretty = Int(port)
        "http://$(hostPretty):$(portPretty)/"
    else
        root_url
    end
    println("Go to $address to start writing ~ have fun!")
    println()
    println("Press Ctrl+C in this terminal to stop Pluto")
    println()
    
    
    # create blocking call:
    try
        wait(servertask)
    catch e
        if isa(e, InterruptException)
            println("\n\nClosing Pluto... Restart Julia for a fresh session. \n\nHave a nice day! 🎈")
            close(serversocket)
        else
            rethrow(e)
        end
    end
end

run(port::Integer=1234; kwargs...) = run("127.0.0.1", port; kwargs...)

function withmorebits(d::Dict)
    Dict((p.first => withmorebits(p.second)
        for p in d))
end
function withmorebits(x::T) where T<:Integer
    Int64(x)
end
function withmorebits(x::Vector)
    withmorebits.(x)
end
function withmorebits(x::Any)
    x
end

function process_ws_message(parentbody::Dict{Any, Any}, clientstream::HTTP.WebSockets.WebSocket)
    client_id = Symbol(parentbody["client_id"])
    
    messagetype = Symbol(parentbody["type"])
    request_id = Symbol(parentbody["request_id"])

    body = parentbody["body"]
    body_parsed = (Symbol(p.first) => withmorebits(p.second) for p in body)

    result = funkies[messagetype](;body_parsed...)

    token = take!(flushtoken)
    try
        if clientstream !== nothing
            if isopen(clientstream)
                clientstream.frame_type = HTTP.WebSockets.WS_BINARY
                write_serialized(clientstream, Dict(
                    :initiator_id => client_id,
                    :request_id => request_id,
                    :body => result,
                ))
                # write_serialized(clientstream, 123)
            else
                @info "Client $(client_id) stream closed."
                put!(flushtoken, token)
            end
        end
    catch ex
        bt = stacktrace(catch_backtrace())
        if ex isa Base.IOError
            # client socket closed, so we return false (about 5 lines after this one)
        else
            @warn "Failed to write to WebSocket of $(client_id) " exception=(ex,bt)
        end
    end
    put!(flushtoken, token)
end

