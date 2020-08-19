// based on https://github.com/fonsp/Pluto.jl (by the same author)

// Polyfill for Blob::arrayBuffer when there is none (safari)
// ignore me
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

// ES6 import for msgpack-lite, we use the fonsp/msgpack-lite fork to make it ES6-importable (without nodejs)
import msgpack from "https://cdn.jsdelivr.net/gh/fonsp/msgpack-lite@0.1.27-es.1/dist/msgpack-es.min.mjs"

/**
 * Return a promise that resolves to:
 *  - the resolved value of `promise`
 *  - an error after `time_ms` milliseconds
 * whichever comes first.
 * @template T
 * @param {Promise<T>} promise
 * @param {number} time_ms
 * @returns {Promise<T>}
 */
const timeout_promise = (promise, time_ms) =>
    Promise.race([
        promise,
        new Promise((res, rej) => {
            setTimeout(() => {
                rej(new Error("Promise timed out."))
            }, time_ms)
        }),
    ])

/**
 * @returns {string}
 */
const get_short_unqiue_id = () => {
    return crypto.getRandomValues(new Uint32Array(1))[0].toString(36)
}

/**
 * We append this after every message to say that the message is complete. This is necessary for sending WS messages larger than 1MB or something, since HTTP.jl splits those into multiple messages :(
 */
const MSG_DELIM = new TextEncoder().encode("IUUQ.km jt ejggjdvmu vhi")

/**
 * Open a connection to the API. The method is asynchonous, and resolves to a @see MargoClient when the connection is established.
 * @typedef {{sendreceive: Function}} MargoClient
 * @param {string} address The WebSocket URL
 * @return {Promise<MargoClient>}
 */
export const margo_client = async (address = document.location.protocol.replace("http", "ws") + "//" + document.location.host) => {
    const client_id = get_short_unqiue_id()
    const sent_requests = {}

    const create_ws = () => {
        return new Promise((resolve_socket, reject_socket) => {
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
        })
    }

    var socket = await timeout_promise(create_ws(), 10000)

    /**
     * Send a message to Julia! If Julia responds to this message specifically, you can retrieve that result by awaiting the Promise returned by this function.
     * Will reconnect if needed before sending the message. Will time out (reject) if we can't reconnect.
     * @param {string} message_type A message type key that is known to the API
     * @param {any} body
     * @return {Promise<any>} Promise that resolves to the Julia response
     */
    const sendreceive = (message_type, body) => {
        return new Promise((resolve, reject) => {
            if (socket.readyState !== WebSocket.OPEN) {
                console.log("MARGO ws is not open")
                console.log("Reconnecting socket...")
                // The connection is broken, so create a new websocket and await the result
                return timeout_promise(create_ws(), 10000).then((new_socket) => {
                    // Once we have a new websocket, we try again:
                    socket = new_socket
                    return sendreceive(message_type, body)
                })
            }

            // Every request has an ID (different from the client ID), so that Julia can send back responses to specific JS requests
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
        })
    }

    return {
        sendreceive: sendreceive,
    }
}
