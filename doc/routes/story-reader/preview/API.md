# 剧情阅读器预览页 API 数据结构

## 数据源

当前预览页使用 Atlas Academy CN 在线数据源，只读取 `scriptId=0100061710`。Atlas DB 页面为 `https://apps.atlasacademy.io/db/CN/script/0100061710`。

- 剧情元数据：`GET https://api.atlasacademy.io/nice/CN/script/{scriptId}`
- 静态脚本文本：元数据响应中的 `script` 字段
- BGM 目录：`GET https://api.atlasacademy.io/export/CN/nice_bgm.json`
- 背景图片：由脚本命令 `[scene 28600]` 拼接为 `https://static.atlasacademy.io/CN/Back/back28600.png`
- 角色立绘：由脚本命令 `[charaSet A 8001001 1 玛修]` 拼接为 `https://static.atlasacademy.io/CN/CharaFigure/8001001/8001001.png`
- 音效资源：由脚本命令 `[se ad1]` 拼接为 `https://static.atlasacademy.io/CN/Audio/SE/ad1.mp3`

页面不直接消费 Atlas 原始结构。`AtlasStoryRepository` 和 `AtlasScriptParser` 会把外部数据转换为项目内部的 `StoryChapter`、`StorySlice`、`StoryAudioCue`。

## 剧情元数据

请求：

```http
GET /nice/CN/script/0100061710
Host: api.atlasacademy.io
```

当前代码使用的顶层字段：

| 字段 | 类型 | 用途 |
| --- | --- | --- |
| `scriptId` | `string` | 脚本 id，对应内部 `StoryChapter.id`。 |
| `scriptSizeBytes` | `number` | 脚本文本大小，当前只作为外部信息保留，不参与渲染。 |
| `script` | `string` | 静态 `.txt` 脚本文本 URL，repository 会继续请求该地址。 |
| `quests` | `array<object>` | 关卡元信息列表，当前取第一个元素生成章节标题。 |

当前代码读取的 `quests[0]` 字段：

| 字段 | 类型 | 用途 |
| --- | --- | --- |
| `name` | `string` | 章节短标题，例如 `序章`。 |
| `warLongName` | `string` | 章节所属篇章，例如 `特异点F\n燃烧污染都市 冬木`。 |
| `phaseScripts` | `array<object>` | 外部关卡脚本列表，当前不参与加载流程，只作为结构说明。 |

标题生成规则：

1. 如果 `warLongName` 和 `name` 都存在，标题为 `warLongName · name`。
2. 如果只有 `name`，标题为 `name`。
3. 如果都缺失，标题回退为 `scriptId`。

示例结构：

```json
{
  "scriptId": "0100061710",
  "scriptSizeBytes": 19659,
  "script": "https://static.atlasacademy.io/CN/Script/01/0100061710.txt",
  "quests": [
    {
      "id": 1000617,
      "name": "告示死亡之丧钟（1/2）",
      "warLongName": "第六特异点\n神圣圆桌领域 卡美洛",
      "phaseScripts": [
        {
          "phase": 1,
          "scripts": [
            {
              "scriptId": "0100061710",
              "script": "https://static.atlasacademy.io/CN/Script/01/0100061710.txt"
            }
          ]
        }
      ]
    }
  ]
}
```

## BGM 目录

请求：

```http
GET /export/CN/nice_bgm.json
Host: api.atlasacademy.io
```

响应是 BGM 对象数组。当前代码按 `fileName` 建立索引，用脚本文本中的 `[bgm BGM_EVENT_11 0.1]` 反查 `audioAsset`。

当前代码使用的字段：

| 字段 | 类型 | 用途 |
| --- | --- | --- |
| `fileName` | `string` | BGM 文件名，也是脚本文本里的 BGM id。 |
| `audioAsset` | `string` | 远端音频 URL，对应内部 `StoryAudioCue.url`。 |

常见外部字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `number` | Atlas BGM id。 |
| `name` | `string` | 本地化名称。 |
| `originalName` | `string` | 原始名称。 |
| `notReleased` | `boolean` | 是否未释放。 |
| `priority` | `number` | 排序权重。 |
| `detail` | `string` | 描述。 |
| `logo` | `string` | 声音图标 URL。 |
| `releaseConditions` | `array<object>` | 解锁条件。 |
| `shop` | `object` | 可选字段，部分 BGM 有商店解锁信息。 |

示例结构：

```json
{
  "id": 40,
  "name": "记忆回廊",
  "originalName": "记忆回廊",
  "fileName": "BGM_EVENT_11",
  "notReleased": false,
  "audioAsset": "https://static.atlasacademy.io/CN/Audio/Bgm/BGM_EVENT_11/BGM_EVENT_11.mp3",
  "priority": 1011,
  "detail": "",
  "logo": "https://static.atlasacademy.io/CN/MyRoomSound/soundlogo_001.png",
  "releaseConditions": []
}
```

## 静态脚本文本

脚本文本是 Atlas 自定义文本格式，不是 JSON。当前 parser 按行读取并识别少量命令。

当前代码识别的命令：

| 命令 | 示例 | 内部映射 |
| --- | --- | --- |
| `[scene id]` | `[scene 28600]` | 更新当前背景，映射为 `https://static.atlasacademy.io/CN/Back/back{id}.png`。 |
| `[bgm fileName ...]` | `[bgm BGM_EVENT_11 0.1]` | 更新当前 BGM，按 `fileName` 从 BGM 目录反查音频 URL。 |
| `[bgmStop ...]` | `[bgmStop BGM_EVENT_3 0.4]` | 清空当前 BGM。 |
| `[soundStopAll]` | `[soundStopAll]` | 清空当前 BGM 和待播放音效。 |
| `[se id]` | `[se ad1]` | 为下一个 slice 添加一次性音效，映射为 `https://static.atlasacademy.io/CN/Audio/SE/{id}.mp3`。 |
| `[charaSet alias id ...]` | `[charaSet A 8001001 1 玛修]` | 记录角色槽位，映射为 `https://static.atlasacademy.io/CN/CharaFigure/{id}/{id}.png`。 |
| `[charaTalk alias]` | `[charaTalk A]` | 更新当前说话角色槽位。 |
| `[charaFadein alias ...]` | `[charaFadein A 0.1 1]` | 标记角色进入前景可见状态。 |
| `[charaFadeout alias ...]` | `[charaFadeout A 0.1]` | 标记角色离开前景可见状态。 |
| `＠speaker` | `＠百貌哈桑` | 更新当前说话来源，清理颜色标签。 |
| `[k]` | `[k]` | 切分一个剧情 slice。 |

当前代码忽略的演出命令示例：

- `[charaFace ...]`
- `[charaMove ...]`
- `[charaEffect ...]`
- `[charaEffectStop ...]`
- `[communicationCharaLoop ...]`
- `[communicationCharaClear]`
- `[fadein ...]`
- `[fadeout ...]`
- `[wait ...]`
- `[messageOff]`
- `[end]`

文本清理规则：

| 原始标记 | 处理 |
| --- | --- |
| `[r]` | 转换为换行。 |
| `[51d4ff]`、`[-]` | 删除颜色标记。 |
| `[line n]` | 删除排版线标记。 |
| 其他未识别的方括号标记 | 删除，避免污染正文。 |

示例片段：

```text
[soundStopAll]
[bgm BGM_EVENT_11 0.1]
[scene 28600]
＠百貌哈桑
从现在起，我会开始单独行动。[r]回荒野为圣都攻略做准备。
[k]
```

转换后的内部 slice 关键字段：

```json
{
  "backgroundImageUrl": "https://static.atlasacademy.io/CN/Back/back28600.png",
  "focusCharacterImageUrl": "https://static.atlasacademy.io/CN/CharaFigure/6003001/6003001.png",
  "speaker": "百貌哈桑",
  "text": "从现在起，我会开始单独行动。\n回荒野为圣都攻略做准备。",
  "bgm": {
    "id": "BGM_EVENT_11",
    "url": "https://static.atlasacademy.io/CN/Audio/Bgm/BGM_EVENT_11/BGM_EVENT_11.mp3",
    "type": "bgm"
  },
  "soundEffects": [],
  "isLast": false
}
```

## 内部数据结构

### StoryChapter

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `string` | 章节 id，当前等于 Atlas `scriptId`。 |
| `title` | `string` | 章节标题，由 quest 元信息生成。 |
| `source` | `string` | 数据来源，当前为 `Atlas Academy CN`。 |
| `slices` | `List<StorySlice>` | 已切分的剧情段落。 |

### StorySlice

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `backgroundImageUrl` | `Uri?` | 当前背景图 URL。 |
| `focusCharacterImageUrl` | `Uri?` | 当前焦点角色立绘 URL，优先使用正在说话且已进入前景的角色；没有前景角色时允许为空。 |
| `speaker` | `string` | 当前说话来源。 |
| `text` | `string` | 当前正文。 |
| `bgm` | `StoryAudioCue?` | 当前 BGM，未遇到新 BGM 前会继承上一段。 |
| `soundEffects` | `List<StoryAudioCue>` | 当前 slice 进入时播放一次的音效。 |
| `isLast` | `boolean` | 是否最后一段。 |

### StoryAudioCue

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `string` | 音频 id，例如 `BGM_EVENT_11` 或 `ad1`。 |
| `url` | `Uri?` | 音频 URL，解析失败时允许为空。 |
| `type` | `StoryAudioCueType` | `bgm` 或 `soundEffect`。 |

## 当前边界

- 首版只处理阅读器渲染需要的命令集合，其他 Atlas 演出命令会忽略或只参与文本清理。
- 角色立绘首版只展示一个焦点角色，不还原多人站位、表情差分、移动和特效。
- BGM URL 解析失败时保留阅读流程，只跳过播放。
- 音效 URL 使用固定路径规则拼接，未额外请求音效目录。
- 脚本请求失败、BGM 目录请求失败或响应格式异常时，页面进入加载失败态。
