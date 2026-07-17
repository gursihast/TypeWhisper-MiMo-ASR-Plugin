# TypeWhisper-MiMo-ASR-Plugin

Unofficial Xiaomi MiMo ASR plugin for [TypeWhisper-Mac](https://github.com/TypeWhisper/typewhisper-mac).

A community plugin that integrates Xiaomi MiMo v2.5 ASR into TypeWhisper on macOS.

一个为 [TypeWhisper-Mac](https://github.com/TypeWhisper/typewhisper-mac) 制作的 Xiaomi MiMo ASR 语音识别插件。

该插件解决 Xiaomi MiMo v2.5 ASR 通过OpenAI Compatible插件接入 TypeWhisper无效的问题，使 TypeWhisper Mac版可以使用 MiMo 的云端语音识别能力进行中文、英文、日文、韩文等多语言转写。

> 本项目是 TypeWhisper 的第三方插件，不属于 TypeWhisper 官方项目，核心功能代码由 AI 辅助生成（Vibe Coding），本人主要负责需求定义、功能整合、测试验证以及 macOS 环境适配。🙈

- **代码质量**：本插件已在 macOS 26.5.2 上通过测试，能稳定实现小米 MiMo ASR 的调用，但代码风格和结构可能不完全符合 Swift 最佳实践。
- **维护与支持**：本人并非专业 Swift 开发者，因此可能无法修复所有潜在的 Bug 或进行深度优化。非常欢迎和感激任何开发者提交 Issue 或 Pull Request 来帮助改进这个项目。
- **致敬基础**：本项目的实现离不开 [TypeWhisper-Mac](https://github.com/TypeWhisper/typewhisper-mac) 提供的优秀平台和插件系统。

---

功能特性

- ✅ 支持 Xiaomi MiMo v2.5 ASR

- ✅ 支持 TypeWhisper 插件系统

- ✅ 支持自动语言检测

- ✅ 支持中文、英文、日文、韩文

- ✅ 支持 TypeWhisper 字典热词

- ✅ 使用 OpenAI Compatible API

- ✅ 原生 Swift 实现

- ✅ macOS 原生支持 Apple Silicon

---

 当前限制

目前 Xiaomi MiMo ASR API：

- ❌ 不支持真正实时流式音频输入

- ❌ TypeWhisper Streaming API 暂未启用

- ❌ 采用完整音频上传后识别模式：

麦克风
↓
TypeWhisper
↓
AudioData
↓
MiMo ASR API
↓
识别结果
↓
TypeWhisper 输入

---

## 快速安装使用此插件：
1. 下载编译版本：TypeWhisper-MIMO-ASR-Plugin.zip
2. 解压得到插件文件：TypeWhisper-MIMO-ASR-Plugin.bundle
3. 将TypeWhisper-MIMO-ASR-Plugin.bundle复制到：~/Library/Application Support/TypeWhisper/Plugins/
4. 重启 TypeWhisper。
5. 在：settings，Integrations中选中“小米MIMO ASR”，选择settings，输入MIMO API Key，ASR Model选选择MIMO2.5 ASR设置插件。（API Key 获取地址：https://mimo.mi.com/ 插件会将 API Key 保存在 macOS Keychain 中，不会上传到第三方服务器。）
6. 在：settings，Recording，Engine，Default Engine中选择MIMO ASR，开始使用。
## 如果 macOS 阻止插件加载⚠️
如果插件没有显示，或者 TypeWhisper 提示无法验证插件：
打开“终端”App运行：
```bash
xattr -cr "$HOME/Library/Application Support/TypeWhisper/Plugins/TypeWhisper-MIMO-ASR-Plugin.bundle"
```
重启 TypeWhisper，回到5. 继续，直到成功✅。

---

## 通过 Xcode 编译使用（开发者模式）：

此插件是 TypeWhisper 的社区插件，必须作为 TypeWhisper 官方 Xcode 工程的一部分 才能编译。它依赖官方的 TypeWhisperPluginSDK 和项目构建环境，不能作为独立 Xcode 工程编译。

前置要求
macOS 14.0 (Sonoma) 或更高版本

Xcode 16+（官方工程要求）

已安装 TypeWhisper 官方应用（用于测试）

Git（用于克隆仓库）

#### 第一步：克隆官方 TypeWhisper 工程
由于你的插件依赖官方 SDK，需要先将官方仓库克隆到本地：

```bash
git clone https://github.com/TypeWhisper/typewhisper-mac.git
cd typewhisper-mac
```

#### 第二步：将你的插件源码添加到工程中

复制插件源码：
将你仓库中的 Sources/ 目录下的所有 .swift 文件，复制到官方工程的 Plugins/ 或 TypeWhisperPluginSDK/Plugins/ 目录下（建议放在 TypeWhisperPluginSDK/Plugins/ 中，与官方插件统一）。


```bash
# 示例：假设你的插件源码在 ~/TypeWhisper-MiMo-ASR/Sources/
cp -R ~/TypeWhisper-MiMo-ASR/Sources/* TypeWhisperPluginSDK/Plugins/
```
在 Xcode 中引入文件：
用 Xcode 打开官方工程：open TypeWhisper.xcodeproj
在左侧项目导航器中，展开 TypeWhisperPluginSDK → Plugins 组
右键点击 Plugins 组，选择 Add Files to "TypeWhisper"...
选择你刚才复制进来的 .swift 文件，确保勾选 Copy items if needed（如果文件不在工程目录内）
点击 Add

#### 第三步：配置插件的 Info.plist 和 Manifest

TypeWhisper 插件需要正确的元信息才能被识别：

创建 Info.plist（如果官方插件模板中没有）：

在 TypeWhisperPluginSDK/Plugins/ 下为你的插件创建一个文件夹（如 MiMoASRPlugin）

在该文件夹中创建 Info.plist，包含以下关键字段：

Key	Value
CFBundleName	TypeWhisper-MiMo-ASR-Plugin
CFBundleIdentifier	com.typewhisper.plugin.mimo-asr
CFBundlePackageType	BNDL
CFBundleVersion	1.0.0
确认插件 Manifest：

TypeWhisper 插件通过 manifest.json 或代码中的 Plugin 协议暴露自身

确保你的主插件类实现了 TypeWhisperPluginSDK 中的 Plugin 或相应协议

参考官方插件（如 GroqPlugin、OpenAIPlugin）的实现方式

#### 第四步：配置代码签名
由于官方工程有严格的签名要求：

在 Xcode 中，选择 TypeWhisper 项目（根节点）

在 TARGETS 列表中找到你的插件 Target（如果未自动生成，需要手动添加 Bundle Target）

切换到 Signing & Capabilities 标签页

确保 Team 选择正确（可使用个人 Apple ID）

Signing Certificate 选择 Development 或 Sign to Run Locally

💡 提示：官方工程通常已配置好自动签名，如果遇到问题，可以参考官方 CodeSigning.xcconfig 中的设置。

#### 第五步：编译整个工程
按 ⌘ + B 编译整个 TypeWhisper 工程

编译成功后，你的插件 .bundle 文件会生成在：

text
~/Library/Developer/Xcode/DerivedData/TypeWhisper-xxxxx/Build/Products/Debug/TypeWhisper-MiMo-ASR-Plugin.bundle

#### 第六步：安装插件到 TypeWhisper

bash
创建插件目录（如果不存在）
mkdir -p ~/Library/Application\ Support/TypeWhisper/Plugins/

复制编译好的插件
cp -R ~/Library/Developer/Xcode/DerivedData/TypeWhisper-*/Build/Products/Debug/TypeWhisper-MiMo-ASR-Plugin.bundle ~/Library/Application\ Support/TypeWhisper/Plugins/
#### 第七步：在 TypeWhisper 中加载
完全退出 TypeWhisper（⌘ + Q）

重新打开 TypeWhisper
进入 Settings → Integrations，找到 "小米 MIMO ASR"
输入你的 MIMO API Key，选择模型为 "MIMO2.5 ASR"
在 Settings → Recording → Engine 中选择 "MIMO ASR"
如果插件未显示，运行以下命令解除 macOS 隔离：

bash
xattr -cr ~/Library/Application\ Support/TypeWhisper/Plugins/TypeWhisper-MiMo-ASR-Plugin.bundle
然后重启 TypeWhisper。

