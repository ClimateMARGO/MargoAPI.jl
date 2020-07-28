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
            a: a_slider.valueAsNumber,
            b: b_slider.valueAsNumber,
        }).then((val) => {
            c_box.value = val.sum
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

    const update_opt = () => {
        sendreceive("opt_controls_temp", {
            opt_parameters: {
                temp_goal: d_slider.valueAsNumber,
                temp_final: d_slider.valueAsNumber,
                max_deployment: {
                    mitigate: 1,
                    remove: 0,
                    geoeng: 0,
                    adapt: 0,
                },
            },
            economics: {
                mitigate_cost: 1,
            },
        }).then(console.log)
    }

    d_slider.addEventListener("input", update_opt)
    update_opt()
})
