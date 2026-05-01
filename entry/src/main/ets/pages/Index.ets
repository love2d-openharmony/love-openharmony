import { hilog } from '@kit.PerformanceAnalysisKit';
import entry from 'libentry.so';
import sdltest from 'libSDL3.so';
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

const DOMAIN = 0x0000;

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
  hilog.info(DOMAIN, 'testTag', '%{public}s', `launchMainIfReady reason=${reason}`)
  sdltest.sdlLaunchMain("liblove.so", "SDL_main", mainArgs)
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
      sdltest.sdlSendDialogStatus(indexMapping.length > 0 ? indexMapping[0] : 0)
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
      sdltest.sdlSendDialogStatus(indexMapping[a.index])
    }).catch((err: BusinessError) => {
      try {
        debugInfo = (debugInfo + `[Ark] dialog failed: ${err.message ?? err}\n`).slice(-12000)
      } catch (e) {
      }
      sdltest.sdlSendDialogStatus(indexMapping[0])
    })
  }
  fetchLocale(): string {
    let locale = new intl.Locale()
    return locale.language + "_" + locale.region
  }
  test(): number {
    hilog.info(DOMAIN, 'testTag', 'Call from native !!!')
    try {
      debugInfo = (debugInfo + `\n[Ark] test called\n`).slice(-12000)
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
        hilog.error(DOMAIN, 'testTag', 'Failed to set PasteData. Cause: ' + err.message);
        return;
      }

      hilog.info(DOMAIN, 'testTag', 'Succeed in setting PasteData.');
    });
  }

  textEditing(): number {
    return input ? 1 : 0;
  }

  startTextInput() {
    input = true
    controller.showTextInput()
    hilog.info(DOMAIN, 'testTag', 'text input start')
  }
  stopTextInput() {
    input = false
    controller.hideTextInput()
    hilog.info(DOMAIN, 'testTag', 'text input stop')
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
      sdltest.sdlDialogClearSelection()
      for (let idx = 0; idx < uris.length; idx++)
      {
        let target = uris[idx].replace("file://docs", "")
        sdltest.sdlDialogFileSelected(target)
        console.info('documentViewPicker.select to file succeed and uris are: ' + target);
      }
      sdltest.sdlDialogExecCallback()
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
    sdltest.sdlCallbackInit(callbackRef)
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
      sdltest.sdlTextAppend(text)
    })
    controller.on('deleteLeft', (i) => {
      sdltest.sdlTextEditing(targetText, targetText.length - 1 - i, i);

      if (targetText.length > 0) {
        targetText = targetText.substring(0, targetText.length - i)
      }
      hilog.info(DOMAIN, 'testTag', targetText)
    })
    controller.on('deleteRight', (i) => {
      sdltest.sdlTextEditing(targetText, 0, i);

      if (targetText.length > 0) {
        targetText = targetText.substring(i, targetText.length)
      }
      hilog.info(DOMAIN, 'testTag', targetText)
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
        Column({ space: 12 }) {
          Text('选择启动内容')
            .fontSize(22)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
          Text(this.bundledGameExists ? `已检测到内置 game.love (${this.bundledGameSize} bytes)` : '未检测到内置 game.love')
            .fontSize(13)
            .fontColor('#D0D0D0')
          if (this.selectedGamePath.length > 0) {
            Text(this.selectedGamePath)
              .fontSize(12)
              .fontColor('#B0B0B0')
              .maxLines(2)
          }
          Text(this.launchHint)
            .fontSize(12)
            .fontColor('#B0B0B0')
          if (this.bundledGameExists) {
            Button('启动内置 game.love')
              .width('100%')
              .onClick(() => {
                this.launchBundledGame()
              })
          }
          if (this.storedGameUri.length > 0) {
            Button('启动上次外置游戏')
              .width('100%')
              .onClick(() => {
                void this.launchStoredExternalGame()
              })
          }
          Button('选择 .love 文件')
            .width('100%')
            .onClick(() => {
              void this.chooseStartupGame(false)
            })
          Button('选择游戏目录')
            .width('100%')
            .onClick(() => {
              void this.chooseStartupGame(true)
            })
          Button('启动 LÖVE 默认 nogame')
            .width('100%')
            .onClick(() => {
              this.launchNoGame()
            })
        }
        .width('84%')
        .padding(20)
        .borderRadius(18)
        .backgroundColor('#CC111111')
      }
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
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    // .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .onKeyEvent((keyevent) => {
      sdltest.sdlKeyEvent(keyevent.keyCode, keyevent.type);
    })
  }
}
