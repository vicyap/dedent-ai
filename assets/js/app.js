// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/dedent_ai"
import topbar from "../vendor/topbar"

const copyText = async (text) => {
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text)
    return
  }

  const textarea = document.createElement("textarea")
  textarea.value = text
  textarea.setAttribute("readonly", "")
  textarea.style.position = "fixed"
  textarea.style.left = "-9999px"
  document.body.appendChild(textarea)
  textarea.select()
  document.execCommand("copy")
  document.body.removeChild(textarea)
}

const copyRich = async (text, html) => {
  if (navigator.clipboard && window.ClipboardItem && window.isSecureContext) {
    try {
      const item = new ClipboardItem({
        "text/plain": new Blob([text], {type: "text/plain"}),
        "text/html": new Blob([html], {type: "text/html"}),
      })
      await navigator.clipboard.write([item])
      return
    } catch (_err) {
      // fall through to plain text
    }
  }
  await copyText(text)
}

const flashCopied = (el) => {
  el.classList.add("btn-success")
  setTimeout(() => el.classList.remove("btn-success"), 1000)
}

const track = (event, props = {}) => {
  if (window.posthog && typeof window.posthog.capture === "function") {
    window.posthog.capture(event, props)
  }
}

window.addEventListener("phx:posthog:capture", (e) => {
  if (e.detail) track(e.detail.event, e.detail.props || {})
})

const hooks = {
  ...colocatedHooks,
  CopyToClipboard: {
    mounted() {
      this.el.addEventListener("click", async () => {
        const target = document.querySelector(this.el.dataset.clipboardTarget)
        if (!target) return

        const text = "value" in target ? target.value : target.textContent
        await copyText(text || "")
        flashCopied(this.el)
        track("copy_plain", {output_chars: (text || "").length})
      })
    },
  },
  CopyRich: {
    mounted() {
      this.el.addEventListener("click", async () => {
        const textEl = document.querySelector(this.el.dataset.textTarget)
        const htmlEl = document.querySelector(this.el.dataset.htmlTarget)
        if (!textEl || !htmlEl) return

        const text = "value" in textEl ? textEl.value : textEl.textContent
        const html = htmlEl.innerHTML || ""
        await copyRich(text || "", html)
        flashCopied(this.el)
        track("copy_formatted", {
          output_chars: (text || "").length,
          has_table: html.includes("<table"),
        })
      })
    },
  },
  CopyText: {
    mounted() {
      this.el.addEventListener("click", async () => {
        await copyText(this.el.dataset.copyText || "")
        flashCopied(this.el)
        track("insight_copied", {chars: (this.el.dataset.copyText || "").length})
      })
    },
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
