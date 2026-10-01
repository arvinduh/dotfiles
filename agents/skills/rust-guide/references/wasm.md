# WebAssembly & DOM rules

Read when the crate depends on `wasm-bindgen`, `web-sys`, or `js-sys`.

- **Push over poll when idle.** Never keep a `requestAnimationFrame` loop
  running while nothing changes. Drive redraws from DOM event listeners
  (`resize`, `pointermove`, `ResizeObserver`) so an idle page uses 0% CPU; start
  a frame loop only while something animates, and stop it when it ends.
- **Cache DOM lookups.** `document.get_element_by_id` and similar run once, at
  initialization. Store the handles; never query the DOM inside a frame or event
  callback.
- **Rich callbacks.** Pass every metric a callback needs by value
  (`on_resize(|width, height, dpr| ...)`) instead of making the callee read them
  back from the DOM.
- **Closure lifetimes are explicit.** Keep `wasm_bindgen::closure::Closure`
  values owned by the struct that registered them, and remove the listener in
  `Drop`. `Closure::forget` is a leak; use it only for listeners that live for
  the whole page, with a comment saying so.
- **Casts use UCS.**
  `wasm_bindgen::JsCast::dyn_into::<web_sys::HtmlCanvasElement>(el)?` — the
  trait origin stays visible at the call site.
