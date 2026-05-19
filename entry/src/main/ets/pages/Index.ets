import { hilog } from '@kit.PerformanceAnalysisKit';
import entry from 'libentry.so';
import sdlBridge from 'libSDL3.so';
import { intl } from '@kit.LocalizationKit';
import { promptAction, ShowDialogSuccessResponse, window } from '@kit.ArkUI';
import { inputMethod } from '@kit.IMEKit'
import { pasteboard } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { batteryInfo } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs'
import audio from '@ohos.multimedia.audio';
import vibrator from '@ohos.vibrator';
import { display } from '@kit.ArkUI';

import  { picker, fileShare } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { setSDLLifecycleHandler } from '../SDLLaunchState';

const DOMAIN = 0x0000;
const LOG_TAG = 'LoveOHOS';

let controller = inputMethod.getController()
let input = false
let targetText = ""
let context: UIContext
let debugInfo = ""
let surfaceReady = false
let callbackReady = false
let nativeLaunchReady = false
let launchRequested = false
let mainLaunched = false
let mainArgs: string[] = []

function launchMainIfReady(reason: string) {
  if (mainLaunched) {
    return
  }
  if (!launchRequested || !nativeLaunchReady || !surfaceReady || !callbackReady) {
    return
  }
  mainLaunched = true
  try {
    debugInfo = (debugInfo + `\n[Ark] launchMainIfReady reason=${reason}\n`).slice(-12000)
  } catch (e) {
  }
  hilog.info(DOMAIN, LOG_TAG, '%{public}s', `launchMainIfReady reason=${reason}`)
  sdlBridge.sdlLaunchMain("liblove.so", "SDL_main", mainArgs)
  setSDLLifecycleHandler((background: boolean) => {
    if (background) {
      sdlBridge.sdlOnBackground()
    } else {
      sdlBridge.sdlOnForeground()
    }
  })
}

export class ArkNapiCallback {
  onMainLaunch() {
    nativeLaunchReady = true
    try {
      debugInfo = (debugInfo + `\n[Ark] onMainLaunch\n`).slice(-12000)
    } catch (e) {
    }
    launchMainIfReady('native_onMainLaunch')
  }

  showDialog(title: string, message: string, indexMapping: number[], names: string[]) {
    try {
      const line = `\n[SDL_Dialog] title=${title}\n${message}\n`
      debugInfo = (debugInfo + line).slice(-12000)
    } catch (e) {
    }

    if (title === 'Compatibility Warning' && message.includes('made for version')) {
      try {
        debugInfo = (debugInfo + `[Ark] auto-ack SDL compatibility warning\n`).slice(-12000)
      } catch (e) {
      }
      sdlBridge.sdlSendDialogStatus(indexMapping.length > 0 ? indexMapping[0] : 0)
      return
    }

    let target: promptAction.Button[] = []
    for (let i = 0; i < names.length; i++)
    {
      target.push({ text: names[i], color: '#999999' })
    }
    promptAction.showDialog({ title: title, message: message, buttons: target }).then((a) => {
      try {
        debugInfo = (debugInfo + `[Ark] dialog selected index=${a.index}\n`).slice(-12000)
      } catch (e) {
      }
      sdlBridge.sdlSendDialogStatus(indexMapping[a.index])
    }).catch((err: BusinessError) => {
      try {
        debugInfo = (debugInfo + `[Ark] dialog failed: ${err.message ?? err}\n`).slice(-12000)
      } catch (e) {
      }
      sdlBridge.sdlSendDialogStatus(indexMapping[0])
    })
  }
  fetchLocale(): string {
    let locale = new intl.Locale()
    return locale.language + "_" + locale.region
  }
  onBridgeReady(): number {
    hilog.info(DOMAIN, LOG_TAG, 'SDL bridge callback ready')
    try {
      debugInfo = (debugInfo + `\n[Ark] bridge ready\n`).slice(-12000)
    } catch (e) {
    }
    return 1
  }

  openLink(url: string) {
    let con = context.getHostContext() as common.UIAbilityContext
    con.openLink(url)
  }

  hasBattery(): number {
    return batteryInfo.isBatteryPresent ? 1 : 0
  }
  batteryCharging(): number {
    return batteryInfo.chargingStatus == batteryInfo.BatteryChargeState.ENABLE ? 1 : 0
  }
  batteryCharged(): number {
    return batteryInfo.chargingStatus == batteryInfo.BatteryChargeState.FULL ? 1 : 0
  }
  batteryPercent(): number {
    return batteryInfo.batterySOC
  }

  vibrate(seconds: number) {
    const duration = Math.max(1, Math.min(5000, Math.round(seconds * 1000)))
    vibrator.startVibration({ type: 'time', duration: duration }, { usage: 'media' }).catch((err: BusinessError) => {
      try {
        debugInfo = (debugInfo + `\n[Ark] vibrate failed: ${err.message ?? err}\n`).slice(-12000)
      } catch (e) {
      }
    })
  }

  hasBackgroundMusic(): number {
    try {
      const streamManager = audio.getAudioManager().getStreamManager()
      return streamManager.isStreamActive(audio.StreamUsage.STREAM_USAGE_MUSIC) ? 1 : 0
    } catch (e) {
      try {
        debugInfo = (debugInfo + `\n[Ark] hasBackgroundMusic failed: ${e}\n`).slice(-12000)
      } catch (_err) {
      }
      return 0
    }
  }

  setPasteboardString(text: string) {
    let pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData, (err, data) => {
      if (err) {
        hilog.error(DOMAIN, LOG_TAG, 'Failed to set PasteData. Cause: ' + err.message);
        return;
      }

      hilog.info(DOMAIN, LOG_TAG, 'Succeed in setting PasteData.');
    });
  }

  textEditing(): number {
    return input ? 1 : 0;
  }

  startTextInput() {
    input = true
    controller.showTextInput()
    hilog.info(DOMAIN, LOG_TAG, 'text input start')
  }
  stopTextInput() {
    input = false
    controller.hideTextInput()
    hilog.info(DOMAIN, LOG_TAG, 'text input stop')
    targetText = ""
  }

  openFileDialog(id: number, defpath: string, itemcount: number, filter: string) {
    const documentSelectOptions = new picker.DocumentSelectOptions();
    documentSelectOptions.maxSelectNumber = itemcount;
    documentSelectOptions.defaultFilePathUri = defpath;

    if (id == 0 || id == 1)
    {
      documentSelectOptions.selectMode = picker.DocumentSelectMode.FILE;
    }
    if (id == 2)
    {
      documentSelectOptions.selectMode = picker.DocumentSelectMode.FOLDER;
    }

    let targetfilter: string[] = []
    let temp = filter.split('\u0002')
    for (let index = 0; index < temp.length; index++) {
      const element = temp[index];

      let temp2 = element.split("|")

      // broken filter!
      if (temp2.length == 1)
      {
        targetfilter.push(element + "|.*")
      }
      else
      {
        let targettemp = temp2[0] + "|";

        let temp3 = temp2[1].split(";")
        for (let index1 = 0; index1 < temp3.length; index1++) {
          targettemp += "." + temp3[index1] + ",";
        }
        targetfilter.push(targettemp)
      }
    }

    documentSelectOptions.fileSuffixFilters = targetfilter;
    documentSelectOptions.authMode = false;
    documentSelectOptions.mergeMode = picker.MergeTypeMode.DEFAULT;
    documentSelectOptions.isEncryptionSupported = false;

    let uris: string[] = [];
    let contextt = context.getHostContext() as common.UIAbilityContext;
    const documentViewPicker = new picker.DocumentViewPicker(contextt);
    documentViewPicker.select(documentSelectOptions).then((documentSelectResult: Array<string>) => {
      uris = documentSelectResult;
      sdlBridge.sdlDialogClearSelection()
      for (let idx = 0; idx < uris.length; idx++)
      {
        let target = uris[idx].replace("file://docs", "")
        sdlBridge.sdlDialogFileSelected(target)
        console.info('documentViewPicker.select to file succeed and uris are: ' + target);
      }
      sdlBridge.sdlDialogExecCallback()
    }).catch((err: BusinessError) => {
      console.error(`Invoke documentViewPicker.select failed, code is ${err.code}, message is ${err.message}`);
    })
  }

  getInternalPath(): string {
    let contextt = context.getHostContext() as common.UIAbilityContext
    return contextt.filesDir
  }
}

let callbackRef: ArkNapiCallback = new ArkNapiCallback()

class ReadTextOptions {
  offset: number = 0
  length: number = 0
  encoding: string = 'utf-8'
}

function getDebugText(): string {
  let msg = debugInfo
  try {
    let con = context.getHostContext() as common.UIAbilityContext
    const logPath = con.filesDir + '/love.log'
    const opts = new ReadTextOptions()
    let size = 0
    try { size = fs.statSync(logPath).size } catch (e) { size = 0 }
    const max = 20000
    opts.offset = size > max ? (size - max) : 0
    opts.length = size > max ? max : size
    const text = fs.readTextSync(logPath, opts)
    msg = msg + `\n--- love.log (tail) ---\n` + text
  } catch (e) {
    msg = msg + `\n--- love.log (tail) ---\n` + `${e}`
  }
  return msg
}

function copyToClipboard(text: string): void {
  const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
  const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
  systemPasteboard.setData(data, (err) => {
    if (err) {
      promptAction.showDialog({ title: 'Copy failed', message: `${err.message ?? err}`, buttons: [{ text: 'OK', color: '#999999' }] })
      return;
    }
    promptAction.showDialog({ title: 'Copied', message: '已复制到剪贴板', buttons: [{ text: 'OK', color: '#999999' }] })
  });
}

function normalizePickedPath(uri: string): string {
  if (uri.startsWith('file://docs')) {
    return uri.replace('file://docs', '')
  }
  if (uri.startsWith('file://')) {
    return uri.substring('file://'.length)
  }
  return uri
}

class StoredLaunchTarget {
  mode: string = ''
  uri: string = ''
  localPath: string = ''
}

function getStoredLaunchTargetPath(): string {
  const con = context.getHostContext() as common.UIAbilityContext
  return con.filesDir + '/launcher-game.json'
}

function loadStoredLaunchTarget(): StoredLaunchTarget | null {
  try {
    const statePath = getStoredLaunchTargetPath()
    const options = new ReadTextOptions()
    options.length = fs.statSync(statePath).size
    const text = fs.readTextSync(statePath, options)
    const parsed = JSON.parse(text) as StoredLaunchTarget
    const target = new StoredLaunchTarget()
    target.mode = parsed.mode ? parsed.mode : ''
    target.uri = parsed.uri ? parsed.uri : ''
    target.localPath = parsed.localPath ? parsed.localPath : ''
    return target
  } catch (_e) {
    return null
  }
}

function saveStoredLaunchTarget(target: StoredLaunchTarget): void {
  const statePath = getStoredLaunchTargetPath()
  const file = fs.openSync(statePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
  fs.writeSync(file.fd, JSON.stringify(target))
  fs.closeSync(file)
}

function clearStoredLaunchTarget(): void {
  try {
    fs.unlinkSync(getStoredLaunchTargetPath())
  } catch (_e) {
  }
}

function getCopiedLovePath(): string {
  const con = context.getHostContext() as common.UIAbilityContext
  return con.filesDir + '/selected-game.love'
}

function getFileSize(path: string): number {
  try {
    return fs.statSync(path).size
  } catch (_e) {
    return 0
  }
}

function fileExistsWithData(path: string): boolean {
  return getFileSize(path) > 0
}

function formatBytes(size: number): string {
  if (size >= 1024 * 1024) {
    return `${(size / (1024 * 1024)).toFixed(1)} MB`
  }
  if (size >= 1024) {
    return `${(size / 1024).toFixed(1)} KB`
  }
  return `${size} B`
}

function getDisplayName(path: string): string {
  if (path.length === 0) {
    return ''
  }
  const normalized = path.replace(/\\/g, '/')
  const idx = normalized.lastIndexOf('/')
  if (idx >= 0 && idx < normalized.length - 1) {
    return normalized.substring(idx + 1)
  }
  return normalized
}

function copyPickedFileToSandbox(uri: string, destPath: string): number {
  const source = fs.openSync(uri, fs.OpenMode.READ_ONLY)
  try {
    try {
      fs.unlinkSync(destPath)
    } catch (_e) {
    }
    fs.copyFileSync(source.fd, destPath)
  } finally {
    fs.closeSync(source)
  }

  const copiedSize = getFileSize(destPath)
  if (copiedSize <= 0) {
    throw new Error(`复制后的文件为空: ${destPath}`)
  }
  return copiedSize
}

async function persistLaunchPermission(uri: string): Promise<void> {
  const policies: Array<fileShare.PolicyInfo> = [{
    uri: uri,
    operationMode: fileShare.OperationMode.READ_MODE,
  }]
  await fileShare.persistPermission(policies)
}

async function activateLaunchPermission(uri: string): Promise<void> {
  const policies: Array<fileShare.PolicyInfo> = [{
    uri: uri,
    operationMode: fileShare.OperationMode.READ_MODE,
  }]
  await fileShare.activatePermission(policies)
}

@Entry
@Component
struct Index {
  @State floatX: number = 18
  @State floatY: number = 100
  @State floatOpen: boolean = false
  @State bundledGameExists: boolean = false
  @State bundledGameSize: number = 0
  @State launcherVisible: boolean = true
  @State selectedGamePath: string = ''
  @State selectedGameUri: string = ''
  @State storedGameUri: string = ''
  @State launchHint: string = '请选择要启动的游戏'
  @State settingsOpen: boolean = false
  @State debugToolsEnabled: boolean = false

  private buildMainArgs(gamePath?: string): string[] {
    const args = ['--renderers', 'opengl,vulkan']
    if (gamePath && gamePath.length > 0) {
      args.push(gamePath)
    }
    return args
  }

  private startSelectedGame(gamePath: string, useBundledGame: boolean): void {
    const con = context.getHostContext() as common.UIAbilityContext
    entry.setPaths(con.filesDir, useBundledGame ? con.resourceDir : '', useBundledGame)
    mainArgs = this.buildMainArgs(gamePath)
    try {
      debugInfo = (debugInfo + `\n[Ark] startSelectedGame bundled=${useBundledGame ? 1 : 0} path=${gamePath}\n[Ark] mainArgs=${JSON.stringify(mainArgs)}\n`).slice(-12000)
    } catch (e) {
    }
    this.selectedGamePath = gamePath
    this.selectedGameUri = useBundledGame ? '' : this.selectedGameUri
    this.launcherVisible = false
    this.launchHint = useBundledGame ? '启动内置 game.love' : (gamePath.length > 0 ? `启动 ${gamePath}` : '启动 LÖVE nogame')
    launchRequested = true
    launchMainIfReady(useBundledGame ? 'bundled_game' : (gamePath.length > 0 ? 'external_game' : 'nogame'))
  }

  private launchBundledGame(): void {
    const con = context.getHostContext() as common.UIAbilityContext
    this.startSelectedGame(con.resourceDir, true)
  }

  private async chooseStartupGame(selectFolder: boolean): Promise<void> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = selectFolder ? picker.DocumentSelectMode.FOLDER : picker.DocumentSelectMode.FILE
    options.authMode = false
    options.mergeMode = picker.MergeTypeMode.DEFAULT
    options.isEncryptionSupported = false
    if (!selectFolder) {
      options.fileSuffixFilters = ['LOVE|.love']
    }

    try {
      const con = context.getHostContext() as common.UIAbilityContext
      const documentViewPicker = new picker.DocumentViewPicker(con)
      const result: Array<string> = await documentViewPicker.select(options)
      if (result.length === 0) {
        return
      }
      const targetUri = result[0]
      let targetPath = normalizePickedPath(targetUri)
      this.selectedGameUri = targetUri
      this.storedGameUri = targetUri

      if (!selectFolder) {
        const copiedPath = getCopiedLovePath()
        const copiedSize = copyPickedFileToSandbox(targetUri, copiedPath)
        targetPath = copiedPath
        this.launchHint = `已复制 .love 到应用沙箱: ${copiedSize} bytes`
      }

      try {
        await persistLaunchPermission(targetUri)
        saveStoredLaunchTarget({ mode: selectFolder ? 'folder' : 'love', uri: targetUri, localPath: selectFolder ? '' : targetPath })
        if (selectFolder) {
          this.launchHint = `已保存外置授权: ${targetPath}`
        }
      } catch (persistErr) {
        if (selectFolder) {
          clearStoredLaunchTarget()
        } else {
          saveStoredLaunchTarget({ mode: 'love', uri: targetUri, localPath: targetPath })
        }
        const message = (persistErr as BusinessError).message ?? `${persistErr}`
        this.launchHint = selectFolder ? `已临时授权，本次可启动，未持久化: ${message}` : `已复制 .love，本次和下次可启动；外置授权未持久化: ${message}`
      }
      this.startSelectedGame(targetPath, false)
    } catch (err) {
      const message = (err as BusinessError).message ?? `${err}`
      this.launchHint = `选择失败: ${message}`
    }
  }

  private async launchStoredExternalGame(): Promise<void> {
    if (this.storedGameUri.length === 0) {
      return
    }
    try {
      let launchPath = ''
      const storedTarget = loadStoredLaunchTarget()
      if (storedTarget && storedTarget.mode === 'love') {
        const localPath = storedTarget.localPath.length > 0 ? storedTarget.localPath : getCopiedLovePath()
        if (fileExistsWithData(localPath)) {
          launchPath = localPath
        } else {
          await activateLaunchPermission(this.storedGameUri)
          copyPickedFileToSandbox(this.storedGameUri, getCopiedLovePath())
          launchPath = getCopiedLovePath()
          saveStoredLaunchTarget({ mode: 'love', uri: this.storedGameUri, localPath: launchPath })
        }
      } else {
        await activateLaunchPermission(this.storedGameUri)
        launchPath = normalizePickedPath(this.storedGameUri)
      }
      this.selectedGameUri = this.storedGameUri
      this.startSelectedGame(launchPath, false)
    } catch (err) {
      const message = (err as BusinessError).message ?? `${err}`
      this.launchHint = `激活已保存授权失败: ${message}`
    }
  }

  private launchNoGame(): void {
    this.startSelectedGame('', false)
  }

  private closeApp(): void {
    const con = context.getHostContext() as common.UIAbilityContext
    con.terminateSelf().catch((err: BusinessError) => {
      try {
        debugInfo = (debugInfo + `\n[Ark] terminateSelf failed: ${err.message ?? err}\n`).slice(-12000)
      } catch (_e) {
      }
    })
  }

  private handleBack(): boolean {
    if (this.settingsOpen) {
      this.settingsOpen = false
      return true
    }

    this.closeApp()
    return true
  }

  onBackPress(): boolean {
    return this.handleBack()
  }

  @Builder
  private GameCover(title: string, label: string, footer: string, enabled: boolean, accent: string, onClick: () => void) {
    Column({ space: 8 }) {
      Column() {
        Text(label)
          .fontSize(10)
          .fontColor('#101418')
          .fontWeight(FontWeight.Bold)
          .height(22)
          .width('100%')
          .textAlign(TextAlign.Center)
          .backgroundColor(enabled ? accent : '#555B61')
        Blank()
        Text(title)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(enabled ? Color.White : '#83888D')
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .width('100%')
        Blank()
        Text(enabled ? 'PLAY' : 'EMPTY')
          .fontSize(10)
          .fontColor(enabled ? '#C9D7E2' : '#6C7074')
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ bottom: 10 })
      }
      .width('100%')
      .height(168)
      .borderRadius(6)
      .backgroundColor(enabled ? '#20262D' : '#171B20')
      .border({ width: 1, color: enabled ? '#53616D' : '#30363C' })
      .onClick(() => {
        if (enabled) {
          onClick()
        }
      })

      Text(footer)
        .fontSize(12)
        .fontColor(enabled ? '#E6EDF3' : '#7E858B')
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private AddCover(title: string, footer: string, accent: string, onClick: () => void) {
    Column({ space: 8 }) {
      Column() {
        Text('ADD')
          .fontSize(10)
          .fontColor('#101418')
          .fontWeight(FontWeight.Bold)
          .height(22)
          .width('100%')
          .textAlign(TextAlign.Center)
          .backgroundColor(accent)
        Blank()
        Text('+')
          .fontSize(42)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width('100%')
        Text(title)
          .fontSize(15)
          .fontColor('#E6EDF3')
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .width('100%')
        Blank()
      }
      .width('100%')
      .height(168)
      .borderRadius(6)
      .backgroundColor('#1E2A33')
      .border({ width: 1, color: '#4C6B80' })
      .onClick(onClick)

      Text(footer)
        .fontSize(12)
        .fontColor('#E6EDF3')
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private Launcher() {
    Stack() {
      Column({ space: 12 }) {
        Row() {
          Column({ space: 2 }) {
            Text('LÖVE')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text('Game Gallery')
              .fontSize(12)
              .fontColor('#9EAAB4')
          }
          .layoutWeight(1)

          Button('SET')
            .height(34)
            .width(64)
            .backgroundColor('#20262D')
            .fontColor('#E6EDF3')
            .onClick(() => {
              this.settingsOpen = !this.settingsOpen
            })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 14 })

        Row({ space: 18 }) {
          Column() {
            this.GameCover(
              'NO GAME',
              'SYSTEM',
              'Nogame',
              true,
              '#78D6B2',
              () => {
                this.launchNoGame()
              }
            )
          }
          .layoutWeight(1)

          Column() {
            this.GameCover(
              'BUNDLED',
              'PACK',
              this.bundledGameExists ? `game.love ${formatBytes(this.bundledGameSize)}` : 'No bundled game',
              this.bundledGameExists,
              '#F2C46D',
              () => {
                this.launchBundledGame()
              }
            )
          }
          .layoutWeight(1)

          Column() {
            this.GameCover(
              this.storedGameUri.length > 0 ? getDisplayName(this.selectedGamePath) : 'EMPTY SLOT',
              'RECENT',
              this.storedGameUri.length > 0 ? 'Last added' : 'No ROM',
              this.storedGameUri.length > 0,
              '#8ED8FF',
              () => {
                void this.launchStoredExternalGame()
              }
            )
          }
          .layoutWeight(1)

          Column() {
            this.AddCover(
              '.love',
              'Add file',
              '#B8E06F',
              () => {
                void this.chooseStartupGame(false)
              }
            )
          }
          .layoutWeight(1)

          Column() {
            this.AddCover(
              'Folder',
              'Add folder',
              '#D7A0FF',
              () => {
                void this.chooseStartupGame(true)
              }
            )
          }
          .layoutWeight(1)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 22, right: 22, top: 4 })

        Row() {
          Text(this.launchHint)
            .fontSize(12)
            .fontColor('#AEB9C2')
            .maxLines(1)
            .layoutWeight(1)
          Text(this.bundledGameExists ? 'Bundled ready' : 'Bundled empty')
            .fontSize(12)
            .fontColor('#707A83')
        }
        .width('100%')
        .padding({ left: 22, right: 22, bottom: 16 })
      }
      .width('100%')
      .height('100%')

      if (this.settingsOpen) {
        Column({ space: 10 }) {
          Text('Settings')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width('100%')
          Button(this.debugToolsEnabled ? 'Hide log bubble' : 'Show log bubble')
            .height(34)
            .width('100%')
            .backgroundColor(this.debugToolsEnabled ? '#45535E' : '#E7EEF4')
            .fontColor(this.debugToolsEnabled ? Color.White : '#17202A')
            .onClick(() => {
              this.debugToolsEnabled = !this.debugToolsEnabled
              if (!this.debugToolsEnabled) {
                this.floatOpen = false
              }
            })
          Row({ space: 8 }) {
            Button('Copy log')
              .height(32)
              .layoutWeight(1)
              .onClick(() => {
                copyToClipboard(getDebugText())
              })
            Button('View log')
              .height(32)
              .layoutWeight(1)
              .onClick(() => {
                promptAction.showDialog({
                  title: 'Debug',
                  message: getDebugText(),
                  buttons: [{ text: 'OK', color: '#999999' }]
                })
              })
          }
          .width('100%')
        }
        .width(260)
        .padding(14)
        .borderRadius(8)
        .backgroundColor('#20262DEE')
        .border({ width: 1, color: '#46525C' })
        .position({ x: 22, y: 66 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#11161B')
  }

  async aboutToAppear(): Promise<void> {
    context = this.getUIContext()
    const con = context.getHostContext() as common.UIAbilityContext
    entry.setPaths(con.filesDir, con.resourceDir, false)
    mainArgs = this.buildMainArgs()
    const storedTarget = loadStoredLaunchTarget()
    if (storedTarget && storedTarget.uri.length > 0) {
      this.storedGameUri = storedTarget.uri
      this.selectedGameUri = storedTarget.uri
      this.selectedGamePath = storedTarget.localPath.length > 0 ? storedTarget.localPath : normalizePickedPath(storedTarget.uri)
      this.launchHint = `已检测到上次外置游戏: ${this.selectedGamePath}`
    }
    const resGame = con.resourceDir.length > 0 ? con.resourceDir + '/game.love' : ''
    const logPath = con.filesDir + '/love.log'
    try {
      let resExists = false
      let resSize = 0
      if (con.resourceDir.length > 0) {
        try {
          fs.accessSync(resGame)
          resSize = fs.statSync(resGame).size
          resExists = resSize > 0
        } catch (e) {
        }
      }
      this.bundledGameExists = resExists
      this.bundledGameSize = resSize
      let logExists = false
      let logSize = 0
      try {
        fs.accessSync(logPath)
        logExists = true
        logSize = fs.statSync(logPath).size
      } catch (e) {
      }
      debugInfo =
        `filesDir=${con.filesDir}\n` +
        `resourceDir=${con.resourceDir}\n` +
        `resGame=${resGame}\n` +
        `resGameExists=${resExists}\n` +
        `resGameSize=${resSize}\n` +
        `loveLog=${logPath}\n` +
        `loveLogExists=${logExists}\n` +
        `loveLogSize=${logSize}\n`
    } catch (e) {
      debugInfo = `debugInfo error: ${e}`
    }

    try {
      debugInfo = (debugInfo + `\n[Ark] calling sdlCallbackInit\n`).slice(-12000)
    } catch (e) {
    }
    sdlBridge.sdlCallbackInit(callbackRef)
    try {
      debugInfo = (debugInfo + `[Ark] sdlCallbackInit returned\n`).slice(-12000)
    } catch (e) {
    }
    callbackReady = true
    focusControl.requestFocus('mainView')
    await controller.attach(false, {
      inputAttribute: {
        textInputType: inputMethod.TextInputType.TEXT,
        enterKeyType: inputMethod.EnterKeyType.DONE
      }
    });
    controller.on('insertText', (text) => {
      targetText += text;
      sdlBridge.sdlTextAppend(text)
    })
    controller.on('deleteLeft', (i) => {
      sdlBridge.sdlTextEditing(targetText, targetText.length - 1 - i, i);

      if (targetText.length > 0) {
        targetText = targetText.substring(0, targetText.length - i)
      }
      hilog.info(DOMAIN, LOG_TAG, targetText)
    })
    controller.on('deleteRight', (i) => {
      sdlBridge.sdlTextEditing(targetText, 0, i);

      if (targetText.length > 0) {
        targetText = targetText.substring(i, targetText.length)
      }
      hilog.info(DOMAIN, LOG_TAG, targetText)
    })
  }

  build() {
    Stack() {
      XComponent({ id: 'mainView', type: 'surface', libraryname: 'SDL3' })
        .id('mainView')
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onLoad(() => {
          surfaceReady = true
          launchMainIfReady('surface_onLoad')
        })
      if (this.launcherVisible && !mainLaunched) {
        this.Launcher()
      }
      if (this.debugToolsEnabled) {
        Column() {
          if (this.floatOpen) {
            Button('复制日志')
              .fontSize(14)
              .height(34)
              .onClick(() => {
                copyToClipboard(getDebugText())
              })
            Button('查看日志')
              .margin({ top: 8 })
              .fontSize(14)
              .height(34)
              .onClick(() => {
                promptAction.showDialog({
                  title: 'Debug',
                  message: getDebugText(),
                  buttons: [{ text: 'OK', color: '#999999' }]
                })
              })
          }
          Text('LOG')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#66000000')
            .borderRadius(20)
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.floatOpen = !this.floatOpen
            })
        }
        .position({ x: this.floatX, y: this.floatY })
        .gesture(
          PanGesture()
            .onActionUpdate((e) => {
              this.floatX = this.floatX + e.offsetX
              this.floatY = this.floatY + e.offsetY
            })
        )
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    // .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .onKeyEvent((keyevent) => {
      if (keyevent.keyCode === 2) {
        return this.handleBack()
      }
      sdlBridge.sdlKeyEvent(keyevent.keyCode, keyevent.type);
      return false
    })
  }
}
