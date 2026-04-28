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

## 子模块

首次克隆后请初始化子模块：

```bash
git submodule sync --recursive
git submodule update --init --force --recursive
```

## 许可证

仓库包含多个上游项目代码，请参考 `license.txt`。
