type SDLLifecycleHandler = (background: boolean) => void

let lifecycleHandler: SDLLifecycleHandler | null = null
let pendingBackground = false

export function setSDLLifecycleHandler(handler: SDLLifecycleHandler): void {
  lifecycleHandler = handler
  if (pendingBackground) {
    pendingBackground = false
    lifecycleHandler(true)
  }
}

export function notifySDLBackgroundRequested(): void {
  if (lifecycleHandler) {
    lifecycleHandler(true)
    return
  }
  pendingBackground = true
}

export function notifySDLForegroundRequested(): void {
  if (lifecycleHandler) {
    lifecycleHandler(false)
  }
}
