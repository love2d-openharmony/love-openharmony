import entry from 'libentry.so'
import sdl from 'libSDL3.so'
import { common } from '@kit.AbilityKit'
import { intl } from '@kit.LocalizationKit'
import { promptAction } from '@kit.ArkUI'
import fs from '@ohos.file.fs'

let updateStatus: ((s: string) => void) | undefined = undefined
let launched = false
let debugInfo: string = ''

async function ensureRawfileToPath(
  con: common.UIAbilityContext,
  rawName: string,
  dstPath: string,
  onProgress: (copied: number, total: number) => void
): Promise<void> {
  try {
    fs.accessSync(dstPath)
    return
  } catch (e) {
  }

  const raw = (() => {
    try {
      return con.resourceManager.getRawFdSync(rawName)
    } catch (e) {
      throw new Error(`rawfile not found: ${rawName}`)
    }
  })()
  const dest = fs.openSync(dstPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)

  const bufTotal = raw.length as number
  let off = 0
  const chunk = 4 * 1024 * 1024
  const buffer = new ArrayBuffer(chunk)
  let lastReport = 0

  try {
    while (off < bufTotal) {
      const want = Math.min(chunk, bufTotal - off)
      const readed = fs.readSync(raw.fd, buffer, { offset: raw.offset + off, length: want })
      if (readed <= 0) {
        break
      }
      fs.writeSync(dest.fd, buffer, { offset: off, length: readed })
      off += readed
      if (off - lastReport >= 4 * 1024 * 1024 || off === bufTotal) {
        lastReport = off
        onProgress(off, bufTotal)
        await new Promise<void>((resolve) => setTimeout(resolve, 0))
      }
    }
  } finally {
    try { fs.closeSync(dest) } catch (e) {}
    try { fs.closeSync(raw.fd) } catch (e) {}
  }
}

class ArkNapiCallback {
  private con: common.UIAbilityContext | undefined = undefined

  setContext(con: common.UIAbilityContext) {
    this.con = con
  }

  onMainLaunch() {
    launched = true
    if (updateStatus) updateStatus('Launching game...')
    const rc = sdl.sdlLaunchMain('libentry.so', 'main')
    if (updateStatus) updateStatus(`Game exited (rc=${rc})`)
  }

  showDialog(title: string, message: string, indexMapping: number[], names: string[]) {
    let buttons: promptAction.Button[] = []
    for (let i = 0; i < names.length; i++) {
      buttons.push({ text: names[i], color: '#999999' })
    }
    promptAction.showDialog({ title, message, buttons }).then((a) => {
      sdl.sdlSendDialogStatus(indexMapping[a.index])
    })
  }

  fetchLocale(): string {
    let locale = new intl.Locale()
    return locale.language + "_" + locale.region
  }

  openLink(url: string) {
    this.con?.openLink(url)
  }

  hasBattery(): number { return 0 }
  batteryCharging(): number { return 0 }
  batteryCharged(): number { return 0 }
  batteryPercent(): number { return 100 }
  setPasteboardString(_text: string) {}
  textEditing(): number { return 0 }
  startTextInput() {}
  stopTextInput() {}
  openFileDialog(_id: number, _defpath: string, _itemcount: number, _filter: string) {}
  getInternalPath(): string { return this.con?.filesDir ?? '' }
}

let callbackRef: ArkNapiCallback = new ArkNapiCallback()

@Entry
@Component
struct Index {
  private context: UIContext | undefined = undefined
  @State status: string = 'Loading...'

  async aboutToAppear(): Promise<void> {
    this.context = this.getUIContext()
    const con = this.context.getHostContext() as common.UIAbilityContext
    updateStatus = (s: string) => { this.status = s }
    callbackRef.setContext(con)
    const gamePath = con.filesDir + '/game.love'
    const resGamePath = con.resourceDir + '/game.love'
    let resourceDirForLove = con.resourceDir
    try {
      try {
        fs.accessSync(resGamePath)
        let st = fs.statSync(resGamePath)
        debugInfo = `filesDir=${con.filesDir}\nresourceDir=${con.resourceDir}\nresGame=${resGamePath}\nresSize=${st.size}`
        this.status = 'Starting game...'
      } catch (e) {
        resourceDirForLove = con.filesDir
        try {
          fs.accessSync(gamePath)
        } catch (e2) {
          this.status = 'Preparing game... 0%'
          await ensureRawfileToPath(con, 'game.love', gamePath, (copied, total) => {
            const pct = Math.floor((copied / total) * 100)
            this.status = `Preparing game... ${pct}%`
          })
        }
        let st2 = fs.statSync(gamePath)
        debugInfo = `filesDir=${con.filesDir}\nresourceDir=${con.resourceDir}\nresGame=${resGamePath}\ngameFile=${gamePath}\nsize=${st2.size}`
        this.status = 'Starting game...'
      }
    } catch (e) {
      this.status = 'Failed to prepare game.'
      promptAction.showDialog({ title: 'Error', message: `${e}`, buttons: [{ text: 'OK', color: '#999999' }] })
      return
    }
    entry.setPaths(con.filesDir, resourceDirForLove)
    sdl.sdlCallbackInit(callbackRef)


    setTimeout(() => {
      if (launched) {
        return
      }
      launched = true
      this.status = 'Launching game...'
      const rc = sdl.sdlLaunchMain('libentry.so', 'main')
      this.status = `Game exited (rc=${rc})`
    }, 500)
  }

  build() {
    Column() {
      Row() {
        Text(this.status).fontSize(14).fontColor('#FFFFFF')
        Button('Debug')
          .margin({ left: 12 })
          .onClick(() => {
            promptAction.showDialog({ title: 'Debug', message: debugInfo, buttons: [{ text: 'OK', color: '#999999' }] })
          })
      }
        .backgroundColor('#66000000')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .width('100%')
      XComponent({ id: 'mainView', type: 'surface', libraryname: 'SDL3' })
        .id('mainView')
        .width('100%')
        .layoutWeight(1)
    }
      .backgroundColor('#000000')
      .width('100%')
      .height('100%')
  }
}
