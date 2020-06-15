import { margo_client } from "./connection.mjs"

margo_client().then(({ sendreceive }) => {
    console.log("Connected!")

    var i = 0
    setInterval(() => {
        i++

        const tic = Date.now()
        sendreceive("wow", { a: 0, b: i }).then(() => {
            const toc = Date.now()
            console.log(toc - tic)
        })
    }, 1000)

    const a_slider = document.querySelector("#a")
    const b_slider = document.querySelector("#b")
    const c_box = document.querySelector("#c")

    const paint = document.querySelector("#paint")
    const ctx = paint.getContext("2d")


    const update = () => {
        sendreceive("wow", {
            a: a.valueAsNumber,
            b: b.valueAsNumber,
        }).then((val) => {
            c.value = val.sum[0]

            const img_data = new ImageData(new Uint8ClampedArray(val.img), 256, 256)
            ctx.putImageData(img_data, 0, 0)
        })
    }

    a_slider.addEventListener("input", update)
    b_slider.addEventListener("input", update)
    update()
})
