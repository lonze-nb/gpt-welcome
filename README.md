# GPT Welcome

一个独立的 macOS 欢迎助手。在 ChatGPT 启动时播放自定义欢迎语，检测到对话输入框可用后淡出。支持 macOS 13 及以上、Apple Silicon 和 Intel。本项目独立于 OpenAI。

## 定制并下载

打开 [定制下载页](https://lonze-nb.github.io/gpt-welcome/)。输入欢迎语，可以预览动画，再点「下载 macOS 定制版」。下载页在浏览器中把欢迎语写入 ZIP 里的 `greeting.json`，并保留应用包的签名。欢迎语不会发送到服务器。

解压后，将 **GPT Welcome.app** 和 **greeting.json** 放在同一文件夹。可以编辑 JSON 后重新播放以更换欢迎语。首次打开助手后，若希望登录时自动运行，请在 **系统设置 → 通用 → 登录项与扩展 → 登录时打开** 中添加它。

自动淡出需要通过 **Welcome → 设置输入框检测权限** 授予辅助功能权限。可用性取决于 ChatGPT 版本是否向 macOS 暴露对话输入框。若助手一直无法识别，可用 **Welcome → 查看退场检测状态** 查看结果，或选 **关闭欢迎画面** 手动淡出。

## 本地构建

安装 Xcode Command Line Tools 和 Python 3，在仓库根目录运行：

```sh
./scripts/build.sh
open 'build/Customize GPT Welcome.html'
```

`build/site/` 是可部署到静态托管的下载页，`build/Customize GPT Welcome.html` 可离线打开。默认使用临时签名（ad hoc），没有 Apple 公证。若 macOS 拒绝下载的应用，可以从源码在本机编译。正式分发时可用自己的 Developer ID 签名并通过 Apple 公证。

## 发布下载页

在公开仓库的 **Settings → Pages → Build and deployment → Source** 中选 **GitHub Actions**，然后在 **Actions** 里运行 **Build and publish the download page**。工作流也会在推送到 `main` 后运行。

[MIT License](LICENSE)
