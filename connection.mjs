// based on https://github.com/fonsp/Pluto.jl (by the same author)

import {msgpack} from "./msgpack.mjs"

const get_short_unqiue_id = () => {
    return crypto.getRandomValues(new Uint32Array(1))[0].toString(36)
}

const MSG_DELIM = new TextEncoder().encode("IUUQ.km jt ejggjdvmu vhi")

export const margo_client = (address=document.location.protocol.replace("http", "ws") + "//" + document.location.host) => {
    const client_id = get_short_unqiue_id()
    const sent_requests = {}

    var resolve_connected_client
    const connected_client = new Promise((res) => {
        resolve_connected_client = res
    })

    const psocket = new WebSocket(address)
    psocket.onmessage = async (event) => {
        try {
            const buffer = await event.data.arrayBuffer()
            const buffer_sliced = buffer.slice(0, buffer.byteLength - MSG_DELIM.length)
            const update = msgpack.decode(new Uint8Array(buffer_sliced))
            const by_me = update.initiator_id && update.initiator_id == client_id
            const request_id = update.request_id
            if (by_me && request_id) {
                const request = sent_requests[request_id]
                if (request) {
                    request(update.body)
                    delete sent_requests[request_id]
                    return
                }
            }
            console.log("Unrequested update:")
            console.log(update)
        } catch (ex) {
            console.error("Failed to get update!", ex)
            console.log(event)
        }
    }
    psocket.onerror = (e) => {
        console.error("SOCKET ERROR", e)

        if (psocket.readyState != WebSocket.OPEN && psocket.readyState != WebSocket.CONNECTING) {
            setTimeout(() => {
                if (psocket.readyState != WebSocket.OPEN) {
                    try_close_socket_connection()
                }
            }, 500)
        }
    }
    psocket.onclose = (e) => {
        console.warn("SOCKET CLOSED")
        console.log(e)
    }
    psocket.onopen = () => {
        resolve_connected_client({
            sendreceive: (message_type, body) => {
                const request_id = get_short_unqiue_id()

                var toSend = {
                    type: message_type,
                    client_id: client_id,
                    request_id: request_id,
                    body: body,
                }

                var resolve, reject

                const p = new Promise((res, rej) => {
                    resolve = res
                    reject = rej
                })

                if(psocket.readyState !== WebSocket.OPEN){
                    reject("WebSocket is not open")
                    return p
                }

                sent_requests[request_id] = resolve

                const encoded = msgpack.encode(toSend)
                const to_send = new Uint8Array(encoded.length + MSG_DELIM.length)
                to_send.set(encoded, 0)
                to_send.set(MSG_DELIM, encoded.length)
                psocket.send(to_send)

                return p
            },
        })
    }

    return connected_client
}
