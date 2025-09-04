# copilot-api

## 简介

copilot-api 是一个代理服务，用于将 GitHub Copilot 的 API 调用转发到 Claude Code。

## 安装

## 手把手教你配置

首先确保你的系统已安装 [Node.js](https://nodejs.org/en/download)，然后安装必要工具：

```bash
npm install -g copilot-api
```

如果还没安装 Claude Code，一行命令即可搞定：

```bash
npm install -g @anthropic-ai/claude-code
```

### 启动 copilot-api 代理服务

接下来，打开第一个终端，启动代理服务：

```bash
copilot-api start
```

系统会提示你进行 GitHub 授权：

```bash
Please visit https://github.com/login/device and enter code XXXX-XXXX to authenticate
```

按提示访问 GitHub 登录页面，输入设备码完成授权。成功后你将看到可用模型列表和 API 调用地址，这些模型都是可用模型，可以正常使用。

### 配置 Claude Code

打开第二个终端，创建 Claude Code 配置文件。在 `~/.claude/settings.json` 中添加：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4141",
    "ANTHROPIC_AUTH_TOKEN": "dummy",
    "ANTHROPIC_MODEL": "claude-sonnet-4",
    "ANTHROPIC_SMALL_FAST_MODEL": "claude-3.7-sonnet",
    "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

**配置说明**：

- `ANTHROPIC_BASE_URL`: 指向本地代理服务地址；
- `ANTHROPIC_AUTH_TOKEN`: 填写任意值即可（代理会处理真实认证）；
- `ANTHROPIC_MODEL`: 主要模型，推荐 `claude-opus-4` 或 `claude-sonnet-4`；
- `ANTHROPIC_SMALL_FAST_MODEL`: 快速模型，用于轻量级任务；
- 后两个参数用于优化性能，减少不必要的调用。

配置完成后，在终端执行：

```bash
claude
```

一切顺利的话，就成功用上了由 GitHub Copilot 驱动的 Claude Code！🎉
