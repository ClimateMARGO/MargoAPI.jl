import { margo_client } from "./connection.mjs"

margo_client().then(({ sendreceive }) => {
    console.log("Connected!")

    // var i = 0
    // setInterval(() => {
    //     i++

    //     const tic = Date.now()
    //     sendreceive("arithmetic", { a: 0, b: i }).then(() => {
    //         const toc = Date.now()
    //         console.log(toc - tic)
    //     })
    // }, 1000)

    const a_slider = document.querySelector("#a")
    const b_slider = document.querySelector("#b")
    const c_box = document.querySelector("#c")
    const d_slider = document.querySelector("#d")
    const e_slider = document.querySelector("#e")

    const repaint_button = document.querySelector("#repaint")
    const paint = document.querySelector("#painting")
    const ctx = paint.getContext("2d")

    const update_sliders = () => {
        sendreceive("arithmetic", {
            a: a.valueAsNumber,
            b: b.valueAsNumber,
        }).then((val) => {
            c.value = val.sum
        })
    }

    a_slider.addEventListener("input", update_sliders)
    b_slider.addEventListener("input", update_sliders)
    update_sliders()

    const update_painting = () => {
        sendreceive("randimage", {
            width: 256,
            height: 256,
        }).then((val) => {
            const img_data = new ImageData(new Uint8ClampedArray(val.img), 256, 256)
            ctx.putImageData(img_data, 0, 0)
        })
    }

    repaint_button.addEventListener("click", update_painting)
    update_painting()

    const update_sqrt = () => {
        sendreceive("opt_controls_temp", {
            T_max: d.valueAsNumber,
        }).then(console.log)
    }

    d_slider.addEventListener("input", update_sqrt)
    update_sqrt()
})
