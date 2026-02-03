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
import { display } from '@kit.ArkUI';

import  { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;

let controller = inputMethod.getController()
let input = false
let targetText = ""
let context: UIContext
let debugInfo = ""
let surfaceReady = false
let callbackReady = false
let launchRequested = false
let mainLaunched = false

function launchMainIfReady(reason: string) {
  if (mainLaunched) {
    return
  }
  if (!launchRequested || !surfaceReady || !callbackReady) {
    return
  }
  mainLaunched = true
  try {
    debugInfo = (debugInfo + `\n[Ark] launchMainIfReady reason=${reason}\n`).slice(-12000)
  } catch (e) {
  }
  hilog.info(DOMAIN, 'testTag', '%{public}s', `launchMainIfReady reason=${reason}`)
  sdltest.sdlLaunchMain("libentry.so", "main")
}

export class ArkNapiCallback {
  onMainLaunch() {
    launchRequested = true
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
    let target: promptAction.Button[] = []
    for (let i = 0; i < names.length; i++)
    {
      target.push({ text: names[i], color: '#999999' })
    }
    promptAction.showDialog({ title: title, message: message, buttons: target }).then((a) => {
      sdltest.sdlSendDialogStatus(indexMapping[a.index])
    }).catch((_err: BusinessError) => {
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

@Entry
@Component
struct Index {
  @State floatX: number = 18
  @State floatY: number = 100
  @State floatOpen: boolean = false

  async aboutToAppear(): Promise<void> {
    context = this.getUIContext()
    const con = context.getHostContext() as common.UIAbilityContext
    entry.setPaths(con.filesDir, con.resourceDir)
    const resGame = con.resourceDir + '/game.love'
    const logPath = con.filesDir + '/love.log'
    try {
      let resExists = false
      let resSize = 0
      try {
        fs.accessSync(resGame)
        resExists = true
        resSize = fs.statSync(resGame).size
      } catch (e) {
      }
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
    launchRequested = true
    launchMainIfReady('after_callback_init')
    setTimeout(() => {
      launchMainIfReady('timeout_fallback')
    }, 1500)
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
