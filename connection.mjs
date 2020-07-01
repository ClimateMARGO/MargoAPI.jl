// based on https://github.com/fonsp/Pluto.jl (by the same author)

// Polyfill for Blob::arrayBuffer when there is none (safari)
if (Blob.prototype.arrayBuffer == null) {
    Blob.prototype.arrayBuffer = function () {
        const reader = new FileReader()
        const promise = new Promise((resolve, reject) => {
            // on read success
            reader.onload = () => {
                resolve(reader.result)
            }
            // on failure
            reader.onerror = (e) => {
                reader.abort()
                reject(e)
            }
        })
        reader.readAsArrayBuffer(this)
        return promise
    }
}

import msgpack from "https://cdn.jsdelivr.net/gh/fonsp/msgpack-lite@0.1.27-es.1/dist/msgpack-es.min.mjs"

const timeout_promise = (promise, time_ms) =>
    Promise.race([
        promise,
        new Promise((res, rej) => {
            setTimeout(() => {
                rej(new Error("Promise timed out."))
            }, time_ms)
        }),
    ])

const get_short_unqiue_id = () => {
    return crypto.getRandomValues(new Uint32Array(1))[0].toString(36)
}

const MSG_DELIM = new TextEncoder().encode("IUUQ.km jt ejggjdvmu vhi")

export const margo_client = async (address = document.location.protocol.replace("http", "ws") + "//" + document.location.host) => {
    const client_id = get_short_unqiue_id()
    const sent_requests = {}

    const create_ws = () => {
        var resolve_socket, reject_socket

        const p = new Promise((res, rej) => {
            resolve_socket = res
            reject_socket = rej
        })

        const socket = new WebSocket(address)
        socket.onmessage = async (event) => {
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
        socket.onerror = (e) => {
            console.warn("SOCKET ERROR")
            console.log(e)
            reject_socket(e)
        }
        socket.onclose = (e) => {
            console.warn("SOCKET CLOSED")
            console.log(e)
            reject_socket(e)
        }
        socket.onopen = () => resolve_socket(socket)
        return p
    }

    var socket = await timeout_promise(create_ws(), 10000)

    const sendreceive = (message_type, body) => {
        var resolve, reject

        const p = new Promise((res, rej) => {
            resolve = res
            reject = rej
        })

        if (socket.readyState !== WebSocket.OPEN) {
            console.log("MARGO ws is not open")
            console.log("Reconnecting socket...")
            return timeout_promise(create_ws(), 10000).then((new_socket) => {
                socket = new_socket
                return sendreceive(message_type, body)
            })
        }

        const request_id = get_short_unqiue_id()

        var toSend = {
            type: message_type,
            client_id: client_id,
            request_id: request_id,
            body: body,
        }

        sent_requests[request_id] = resolve

        const encoded = msgpack.encode(toSend)
        const to_send = new Uint8Array(encoded.length + MSG_DELIM.length)
        to_send.set(encoded, 0)
        to_send.set(MSG_DELIM, encoded.length)
        socket.send(to_send)

        return p
    }

    return {
        sendreceive: sendreceive,
    }
}
