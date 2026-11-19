# GPT Welcome

一个独立的 macOS 欢迎助手。在 ChatGPT 启动时播放自定义欢迎语，检测到对话输入框可用后淡出。支持 macOS 13 及以上、Apple Silicon 和 Intel。本项目独立于 OpenAI。

## 下载与使用

打开 [下载页](https://lonze-nb.github.io/gpt-welcome/) 预览手写动画并下载 macOS 版。首次使用的欢迎语是 `welcome`。

解压后打开 **GPT Welcome** 文件夹里的 **GPT Welcome.app**。打开 ChatGPT 后，从菜单栏选择 **Welcome → 更改欢迎语… → 保存并预览** 即可更换欢迎语。设置保存在这台 Mac 上。若希望登录时自动运行，可在 **系统设置 → 通用 → 登录项与扩展 → 登录时打开** 中添加助手。

自动淡出需要通过 **Welcome → 设置输入框检测权限** 授予辅助功能权限。可用性取决于 ChatGPT 版本是否向 macOS 暴露对话输入框。若助手一直无法识别，可用 **Welcome → 查看退场检测状态** 查看结果，或选 **关闭欢迎画面** 手动淡出。

## 本地构建

安装 Xcode Command Line Tools 和 Python 3，在仓库根目录运行：

```sh
./scripts/build.sh
open 'build/site/index.html'
```

`build/site/` 包含可部署到静态托管的下载页和默认安装包 `GPT-Welcome.zip`。默认使用临时签名（ad hoc），没有 Apple 公证。若 macOS 拒绝下载的应用，可以从源码在本机编译。正式分发时可用自己的 Developer ID 签名并通过 Apple 公证。

## 发布下载页

在公开仓库的 **Settings → Pages → Build and deployment → Source** 中选 **GitHub Actions**，然后在 **Actions** 里运行 **Build and publish the download page**。工作流也会在推送到 `main` 后运行。

## 字形数据许可

项目代码采用 [MIT License](LICENSE)。英文字母和数字使用项目自绘笔画。
汉字笔顺来自 [Hanzi Writer Data 2.0.1](https://github.com/chanind/hanzi-writer-data)，沿用其 Arphic Public License。
构建时只保留笔画中心线，坐标保持原样，完整许可随构建产物分发。
没有笔画数据的字符（如 emoji）会在对应的位置淡入。
