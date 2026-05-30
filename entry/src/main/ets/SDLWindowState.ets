import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const LOG_TAG = 'LoveOHOS';

let mainWindow: window.Window | null = null;
let keepScreenOnRequested: boolean | null = null;

function applyKeepScreenOn(win: window.Window, enabled: boolean): void {
  Promise.resolve(win.setWindowKeepScreenOn(enabled)).then(() => {
    hilog.info(DOMAIN, LOG_TAG, 'Applied keep-screen-on: %{public}s', enabled ? 'true' : 'false');
  }).catch((error: Object) => {
    hilog.error(DOMAIN, LOG_TAG, 'Failed to set keep-screen-on: %{public}s', JSON.stringify(error));
  });
}

export function setSDLMainWindow(win: window.Window): void {
  mainWindow = win;
  if (keepScreenOnRequested !== null) {
    applyKeepScreenOn(win, keepScreenOnRequested);
  }
}

export function setSDLMainWindowKeepScreenOn(enabled: boolean): boolean {
  keepScreenOnRequested = enabled;
  if (!mainWindow) {
    hilog.warn(DOMAIN, LOG_TAG, 'Main window is not ready, keep-screen-on request queued: %{public}s', enabled ? 'true' : 'false');
    return true;
  }

  try {
    applyKeepScreenOn(mainWindow, enabled);
    return true;
  } catch (error) {
    hilog.error(DOMAIN, LOG_TAG, 'Failed to set keep-screen-on: %{public}s', JSON.stringify(error));
    return false;
  }
}
