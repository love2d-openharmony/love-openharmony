# LÖVE for OpenHarmony

这个仓库现在以 OpenHarmony 工程作为根目录入口，`AppScope`、`entry`、`hvigor` 以及相关 `json5` / `ts` 配置都直接位于仓库根目录。

## 目录说明

- `AppScope/`：应用级资源和配置
- `entry/`：OpenHarmony 主模块
- `hvigor/`、`hvigorfile.ts`：Hvigor 构建配置
- `cpp/`：共享 native 源码与三方依赖子模块，供 OpenHarmony 工程复用

## 共享 Native 源码

共享 C/C++ 源码现在直接放在仓库根目录的 `cpp/` 下，避免继续挂在历史 Android 目录层级里。

`entry/src/main/cpp/CMakeLists.txt` 会从仓库根目录引用下面两块内容：

- `cpp/love`
- `cpp/megasource`

## 使用方式

在 DevEco Studio 中直接打开仓库根目录即可，把它当作 OpenHarmony 工程入口使用。

如果是命令行构建，请在仓库根目录执行对应的 Hvigor 命令，并确保本地 OpenHarmony SDK、签名和 NDK/CMake 环境已正确配置。

## GitHub Action 打包

仓库根目录提供了一个复合 Action，可在 OpenHarmony SDK 容器中把 `.love` 游戏包打成 HAP：

```yaml
jobs:
  build-openharmony:
    runs-on: ubuntu-latest
    container: ghcr.io/bytemain/harmony-next-pipeline-docker/harmonyos-ci-image:v6.0.2.642
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Build OpenHarmony HAP
        id: build-hap
        uses: love2d-openharmony/love-openharmony@main
        with:
          app-name: "My Love Game"
          bundle-id: "com.example.mylovegame"
          love-package: "./game.love"
          product-name: "my-love-game"
          version-string: "1.0.0"
          version-code: "1000000"
          output-folder: "./dist"
      - uses: actions/upload-artifact@v4
        with:
          name: openharmony-hap
          path: ${{ steps.build-hap.outputs.package-paths }}
```

示例容器版本来自当前已验证的 HarmonyOS CI 镜像；实际项目可按目标 SDK 选择并更新到兼容的最新镜像。

如果 `love-package` 指定路径下没有 `.love` 文件，Action 会生成一个最小默认包用于打包验证。如果需要签名，可额外传入 `signing-cert-base64`、`signing-profile-base64`、`signing-key-base64`、`signing-key-alias`、`signing-key-password` 和 `signing-keystore-password`。Action 会输出 `package-paths`，内容是生成的 HAP 路径列表。

## 自动打包

仓库已内置 `.github/workflows/package.yml` 自动打包流程，会在推送到 `main`、推送 `v*` 标签或手动触发 `workflow_dispatch` 时运行。流程会直接引用当前仓库 `action.yml` 中的复合 Action 构建未签名 HAP，并通过 `actions/upload-artifact` 上传 `openharmony-hap` 构建产物。

手动触发时可以配置应用名称、包名、`.love` 包路径、产物名、版本号和构建模式；如果指定路径下没有 `.love` 文件，复合 Action 会生成一个最小默认包用于打包验证。

## 子模块

首次克隆后请初始化子模块：

```bash
git submodule sync --recursive
git submodule update --init --force --recursive
```

## 许可证

仓库包含多个上游项目代码，请参考 `license.txt`。
