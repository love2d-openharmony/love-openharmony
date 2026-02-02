## 依赖与打包要点

- 本工程在 OHOS 上优先走“源码构建”的 SDL3 / love / 第三方依赖，尽量避免预构建 so 的 SONAME 风险。
- 如果必须引入预构建 so，请确认每个 so 的 dynamic section 里存在 SONAME，否则打包进 hap 后可能出现动态加载找不到依赖库的问题。
- 可用 SDK 自带的 llvm-readelf 查看：`llvm-readelf -d libxxx.so | grep SONAME`。

## 编译器

- `ohos/entry/build-profile.json5` 已设置 `nativeCompiler: BiSheng`，用于在 DevEco Studio 下启用毕昇编译器构建 native 代码。

## XComponent（Surface）接入要点

- Surface 生命周期回调：OnSurfaceCreated / OnSurfaceChanged / OnSurfaceDestroyed。
- 建议在回调里用 `OH_NativeXComponent_GetXComponentSize(component, window, &w, &h)` 取到真实宽高，并把 `OHNativeWindow*` 与尺寸一起同步到渲染侧。
- 触控/鼠标/按键：Native XComponent 提供了获取事件数据的接口（Touch/Mouse/Key），后续需要把这些事件转换成 SDL 的事件队列。

## ArkUI NDK（可选）

- 如果后续接入 ArkUI NDK 创建/挂载 UI 组件树（例如 ContentSlot / NodeContent 等），需要注意 UI 接口调用的线程约束；在 API version 22 之后部分 NDK 接口支持多线程创建 Free 状态组件树，但依然需要遵守同一组件树不可被多线程同时操作等约束。
