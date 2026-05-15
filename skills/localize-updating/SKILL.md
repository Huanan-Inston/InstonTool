---
name: localize-updating
description: 用于操作和排查 InstonTool 的 `tool localize updating` 工作流，面向 iOS 本地化目录。适用于需要通过 Drojian API keys 或已下载的本地化目录更新 `*.lproj/Localizable.strings`、说明或执行 `tool auth`、处理 `--keys`、`--keys-file`、`--downloaded`、`--cfg`，或排查 `localize updating` 子命令相关的 Mint 版本过旧、认证和配置问题的场景。
metadata:
  author: donghuanan@inston.ltd
  version: "1.0"
---

# InstonTool 本地化更新

默认通过 Mint 使用 `mint run Huanan-Inston/InstonTool ...` 作为调用形式。

## 前置条件

### 1. Mint 支持

Mint: https://github.com/yonaskolb/mint

在使用 `localize updating` 之前确认 `mint` 已经可用。
如果不存在，则立刻终止，并提示用户安装。

### 2. API 认证

1. 只要使用 `--keys` 或 `--keys-file`，就先完成这一组认证前置条件。
2. 可以通过 `mint run Huanan-Inston/InstonTool auth --access_key <key> --access_secret <secret>` 保存认证，也可以同时提供 `DROJIAN_ACCESS_KEY` 和 `DROJIAN_ACCESS_SECRET`。
3. 只有两个值同时存在时，认证才算有效。
4. 默认情况下，保存后的认证文件位于 `$XDG_CONFIG_HOME/inston/auth.json` 或 `~/.config/inston/auth.json`。
5. 如果这次任务只使用 `--downloaded`，则不需要这一组认证前置条件。

## 步骤

### 1. 明确 Strings 目录

`<strings>` 参数应该指向一个包含多语言目录的文件夹。

目录格式一般如下：

```text
./MapRunner/Strings
├── en.lproj
│   └── Localizable.strings
└── zh-Hans.lproj
    └── Localizable.strings
```


### 2. 准备数据

1. 如果使用 API 模式，确认后端已经刷新了指定 keys 的本地化数据。
2. 如果使用 `keys-file` 模式，确认文件里列出的 keys 是正确的，并且每行一个。
3. 如果使用 `downloaded` 模式，确认目录里放的是以后端语言码命名的文件，而不是 `.lproj` 目录树。

### 3. 执行

1. 如果目标是从后端刷新指定 keys，使用 API 模式。

```bash
mint run Huanan-Inston/InstonTool localize updating ./MapRunner/Strings \
  --keys having_problem_tell_gpt --keys good_job
```

2. 如果 key 列表已经在文件里，使用 `keys-file` 模式。

```bash
mint run Huanan-Inston/InstonTool localize updating ./MapRunner/Strings \
  --keys-file ./keys.txt
```

3. 如果已经拿到了后端导出的本地化文件目录，使用 `downloaded` 模式。

```bash
mint run Huanan-Inston/InstonTool localize updating ./MapRunner/Strings \
  --downloaded ./downloaded-localizations
```

## 配置

如果需要更细粒度的控制，可以通过 `--cfg` 参数指定一个 JSON 配置文件，来覆盖默认行为。

```bash
mint run Huanan-Inston/InstonTool localize updating ./MapRunner/Strings \
  --keys having_problem_tell_gpt --keys good_job \
  --cfg ./inston.yaml
```

### 格式例子

```yaml
lang_name_map:
  zh-Hans: zh_CN
  zh-Hant: zh_TW
  ms-MY: ms
  id: in_ID
  pt: pt_br
ignore_keys:
  - app_name
  - company_name
```

### lang code 映射

后端的语言码可能和 iOS 本地化目录里的语言码不完全一致。可以通过 `lang_name_map` 配置项来指定映射关系，来让工具正确地找到对应关系。
Key：Strings 目录里语言码（不带 `.lproj` 后缀）
Value：Downloaded 模式里后端导出的文件名里的语言码，或者 API 模式里后端返回的语言码。

常见的映射：
  zh-Hans: zh_CN
  zh-Hant: zh_TW
  ms-MY: ms
  id: in_ID
  pt: pt_br


### 忽略 keys

有些 keys 可能不希望被覆盖，可以通过 `ignore_keys` 配置项来指定一个列表，来让工具在更新时跳过这些 keys。
