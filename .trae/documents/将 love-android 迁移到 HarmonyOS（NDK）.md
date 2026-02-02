## 你确认的方向
- 立即开始按“SDL3 原生接入鸿蒙”推进，然后在此基础上让 love2d 跑起来。

## 第 0 步：确定最短可验证闭环（先跑 SDL，再跑 love）
- **MVP 目标**：一个 OHOS Stage 应用（ArkTS）里放 XComponent；native 侧用 SDL3 在该 surface 上清屏绘制；触控事件能进入 SDL；音频能播放。
- 做到 MVP 后再接入 love2d（因为 love 的主要平台依赖都走 SDL3）。

## 第 1 步：在仓库新增 OHOS 宿主工程（Stage + XComponent + NDK）
- 新增一个 OHOS 工程/模块（不改现有 Android 工程），内容包括：
  - ArkTS UI：WindowStage + XComponent 作为渲染容器
  - NDK 原生库：暴露最小 N-API 接口给 ArkTS，用来：
    - 拿到 XComponent 的 native window / surface 句柄
    - 通知 native 启动/暂停/恢复/销毁
- 验证点：应用能启动并成功加载 native `.so`。

## 第 2 步：给 SDL3 增加 OHOS 平台层（先最小子集）
> 目标：让 SDL3 在 OHOS 上有一个“可用但不完美”的 video/events/audio 后端。

### 2.1 Video（窗口/渲染面）
- 新增 SDL3 源码目录（名称按 SDL3 现有风格）：
  - `src/video/ohos/`：创建 video device、window、EGL glue
- 做法：
  - 从 XComponent 提供的 native window 创建 EGLSurface
  - 支持尺寸变化回调（旋转/分辨率变化）
- 验证点：SDL 能创建 window + GL context，绘制清屏。

### 2.2 Events（触控/按键）
- 新增：`src/events/ohos/`（或挂在 video/ohos 下按 SDL3 习惯组织）
- 做法：
  - ArkTS/XComponent 事件回调 → N-API → SDL event pump
  - 先实现：触摸按下/移动/抬起、返回键（如可获取）
- 验证点：SDL 的事件队列能收到触控并打印坐标/手势 ID。

### 2.3 Audio（为了让 OpenAL-soft 复用 SDL3 后端）
- 新增：`src/audio/ohos/`（或按 SDL3 audio driver 结构接入）
- 做法：
  - 先实现基础 PCM 输出（以系统提供的 OHOS 音频 API 为底层）
  - 只要求：固定采样率/声道数也能工作，后续再做协商
- 验证点：SDL 直接播放测试音；随后 OpenAL-soft 使用它的 SDL3 后端（见 [sdl3.cpp](file:///Users/artin/0Workspace/github.com/bytemain/love-android/app/src/main/cpp/megasource/libs/openal-soft/alc/backends/sdl3.cpp)）也能出声。

### 2.4 Core（时间/线程/原子）
- 尽量复用 SDL3 的 POSIX 实现，只补齐 OHOS 平台宏与缺口。
- 验证点：SDL 自测/我们写的小 demo 稳定运行 1 分钟以上不崩。

## 第 3 步：把 love2d 接到 SDL3-OHOS 上
- 构建层面：复用现有 CMake 聚合（见 [CMakeLists.txt](file:///Users/artin/0Workspace/github.com/bytemain/love-android/app/src/main/cpp/CMakeLists.txt)），但改为 OHOS toolchain 驱动：
  - `CMAKE_TOOLCHAIN_FILE=.../ohos.toolchain.cmake`
  - `OHOS_ARCH/OHOS_PLATFORM/OHOS_STL` 按 NDK 文档配置
- 代码层面：
  - 新增 `LOVE_OHOS` 平台宏与平台文件，逐步替换/绕开 `LOVE_ANDROID` glue（核心参考：[android.cpp](file:///Users/artin/0Workspace/github.com/bytemain/love-android/app/src/main/cpp/love/src/common/android.cpp)）
  - 先完成两件事：
    1) 资源读取：让 `main.lua`/`game.love` 能从 HAP 资源中读出
    2) 保存路径：映射到 OHOS 沙箱目录，保证 `love.filesystem` 可写
- 验证点：内嵌一个最小 main.lua 能启动并绘制文字/方块。

## 第 4 步：打包与依赖治理（对齐 NDK 文档）
- 若使用预构建 `.so`（文档：build-with-ndk-prebuilts）：
  - 统一放入模块 `libs/` 并在 CMake 里 `IMPORTED` 引入
  - 确保每个 `.so` 的 SONAME 正确，避免运行时动态加载失败
- 毕昇编译器（文档：bisheng-compiler）：
  - DevEco 工程配置启用；若脚本化构建，确保 sysroot 指向 `.../openharmony/native/sysroot`

## 交付节奏（你会很快看到可运行结果）
- 先交付一个“SDL3-OHOS Demo HAP”：清屏 + 触控回显 + 播放音频。
- 再交付一个“love2d-OHOS Demo HAP”：运行内嵌 main.lua。

## 我接下来要做的第一件事（你点击确认后马上动手）
- 在仓库新增 OHOS Stage 宿主工程与 NDK 模块，并创建 SDL3 的 OHOS video/events 的最小骨架，目标是 1) 成功编译 2) 能清屏。

你回复“确认”后，我就开始在仓库里落代码与构建文件。