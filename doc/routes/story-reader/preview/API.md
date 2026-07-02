# 剧情阅读器预览页 API 数据结构

## 数据源

当前预览页使用 Atlas Academy CN 在线数据源，只读取 `scriptId=0100061710`。Atlas DB 页面为 `https://apps.atlasacademy.io/db/CN/script/0100061710`。

- 剧情元数据：`GET https://api.atlasacademy.io/nice/CN/script/{scriptId}`
- 静态脚本文本：元数据响应中的 `script` 字段
- BGM 目录：`GET https://api.atlasacademy.io/export/CN/nice_bgm.json`
- 角色表情布局：`GET https://api.atlasacademy.io/raw/CN/svtScript?charaId=...`，多个角色用重复 `charaId` query 参数
- 背景图片：由脚本命令 `[scene 28600]` 拼接为 `https://static.atlasacademy.io/CN/Back/back28600.png`
- 角色立绘：由脚本命令 `[charaSet A 8001001 1 玛修]` 拼接为 `https://static.atlasacademy.io/CN/CharaFigure/8001001/8001001_merged.png`
- 音效资源：由脚本命令 `[se ad1]` 拼接为 `https://static.atlasacademy.io/CN/Audio/SE/ad1.mp3`

页面不直接消费 Atlas 原始结构。`AtlasStoryRepository` 和 `AtlasScriptParser` 会把外部数据转换为项目内部的 `StoryChapter`、`StorySlice`、`StoryCharacter`、`StoryAudioCue`。

## 资源缓存

预览页运行时会在应用内部目录创建 `story_cache/{scriptId}/` 缓存目录，例如当前脚本为 `story_cache/0100061710/`。图片和 mp3 读取时先按内部 `StoryResource.cacheFileName` 拼接缓存文件绝对路径；文件存在时直接读取本地缓存，文件不存在时请求 `StoryResource.url` 并将响应内容写入同一个缓存文件名。

当前脚本资源的缓存文件名示例：

| 资源 | 远端来源 | 缓存文件名 |
| --- | --- | --- |
| 背景图 | `[scene 28600]` | `back28600.png` |
| 角色立绘与表情图集 | `[charaSet A 8001001 ...]` | `8001001_merged.png` |
| BGM | `[bgm BGM_EVENT_11 ...]` | `BGM_EVENT_11.mp3` |
| 音效 | `[se ad1]` | `ad1.mp3` |

缓存读取、写入或下载失败不会让阅读器进入失败态；图片会回退远端加载或兜底背景，音频会回退远端播放或跳过。`svtScript` 请求失败时不会阻断剧情加载，角色仍使用 `_merged.png` 顶部基础立绘区域，只是不叠加表情差分。

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

## 角色表情布局

请求：

```http
GET /raw/CN/svtScript?charaId=8001001&charaId=6003001
Host: api.atlasacademy.io
```

Repository 会在脚本文本下载后扫描所有 `[charaSet alias id ...]` 的角色 id，再一次性请求 `svtScript`。响应是角色脚本对象数组；同一 `id` 返回多条时取第一条。当前代码使用的字段：

| 字段 | 类型 | 用途 |
| --- | --- | --- |
| `id` | `number` | 角色立绘 id，对应 `[charaSet]` 的第二个参数。 |
| `faceX` | `number` | 表情块绘制到基础立绘上的 X 坐标。 |
| `faceY` | `number` | 表情块绘制到基础立绘上的 Y 坐标。 |
| `offsetX` | `number` | Atlas 附加偏移信息，当前保存到模型中但不参与表情覆盖坐标。 |
| `offsetY` | `number` | Atlas 附加偏移信息，当前保存到模型中但不参与表情覆盖坐标。 |
| `extendData.faceSize` / `extendData.faceSizeRect` | `number` / `array` / `object` | 可选表情块尺寸，缺省按 `256x256` 处理。 |

`_merged.png` 的图集规则：顶部 `1024x768` 是基础立绘区域，后续区域按表情编号从 1 开始、从左到右、从上到下排列脸部差分块。`charaFace 0` 表示使用基础立绘自带表情，不叠加差分。

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
| `[charaSet alias id baseFace name]` | `[charaSet A 8001001 1 玛修]` | 创建或更新角色槽位，初始表情为 `baseFace`，资源映射为 `https://static.atlasacademy.io/CN/CharaFigure/{id}/{id}_merged.png`。 |
| `[charaTalk alias]` | `[charaTalk A]` | 更新当前说话角色槽位。 |
| `[charaFace alias face]` | `[charaFace A 13]` | 更新角色槽位当前表情编号。 |
| `[charaFadein alias duration position]` | `[charaFadein A 0.1 1]` | 标记角色进入前景可见状态，并保存 Atlas 数字站位。 |
| `[charaFadeout alias ...]` | `[charaFadeout A 0.1]` | 标记角色离开前景可见状态。 |
| `[charaPut alias x,y]` | `[charaPut D 0,250]` | 立即更新角色槽位坐标，不表现动画。 |
| `[charaMove alias x,y duration]` | `[charaMove C -200,0 0.1]` | 立即更新角色槽位最终坐标，不表现移动过程。 |
| `＠speaker` | `＠百貌哈桑` | 更新当前说话来源，清理颜色标签。 |
| `[k]` | `[k]` | 切分一个剧情 slice。 |

当前代码忽略的演出命令示例：

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
  "backgroundImage": {
    "url": "https://static.atlasacademy.io/CN/Back/back28600.png",
    "cacheFileName": "back28600.png"
  },
  "characters": [
    {
      "alias": "F",
      "characterId": "6003001",
      "name": "百貌哈桑",
      "figureResource": {
        "url": "https://static.atlasacademy.io/CN/CharaFigure/6003001/6003001_merged.png",
        "cacheFileName": "6003001_merged.png"
      },
      "faceIndex": 0,
      "position": { "x": 0, "y": 0 },
      "isSpeaking": true,
      "faceLayout": {
        "faceX": 383,
        "faceY": 153,
        "offsetX": -2,
        "offsetY": 108,
        "faceSizeWidth": 256,
        "faceSizeHeight": 256
      }
    }
  ],
  "speaker": "百貌哈桑",
  "text": "从现在起，我会开始单独行动。\n回荒野为圣都攻略做准备。",
  "bgm": {
    "id": "BGM_EVENT_11",
    "resource": {
      "url": "https://static.atlasacademy.io/CN/Audio/Bgm/BGM_EVENT_11/BGM_EVENT_11.mp3",
      "cacheFileName": "BGM_EVENT_11.mp3"
    },
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
| `backgroundImage` | `StoryResource?` | 当前背景图资源。 |
| `characters` | `List<StoryCharacter>` | 当前可见角色列表，按进入前景的顺序保存。 |
| `focusCharacterImage` | `StoryResource?` | 兼容 getter，返回正在说话角色或最后一个可见角色的立绘资源；UI 不再用它驱动角色渲染。 |
| `speaker` | `string` | 当前说话来源。 |
| `text` | `string` | 当前正文。 |
| `bgm` | `StoryAudioCue?` | 当前 BGM，未遇到新 BGM 前会继承上一段。 |
| `soundEffects` | `List<StoryAudioCue>` | 当前 slice 进入时播放一次的音效。 |
| `isLast` | `boolean` | 是否最后一段。 |

### StoryCharacter

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `alias` | `string` | Atlas 脚本内角色槽位，例如 `A`、`F`。 |
| `characterId` | `string` | Atlas 角色立绘 id。 |
| `name` | `string` | `[charaSet]` 中的角色名。 |
| `figureResource` | `StoryResource` | `_merged.png` 图集资源。 |
| `faceIndex` | `int` | 当前表情编号，`0` 表示不覆盖表情差分。 |
| `position` | `StoryCharacterPosition` | Atlas 逻辑坐标，渲染时按角色图集绘制比例缩放，并限制在当前 `16:9` 舞台内，避免左右站位裁切角色。 |
| `isSpeaking` | `boolean` | 当前 slice 的说话角色标记。 |
| `faceLayout` | `StoryCharacterFaceLayout?` | `svtScript` 提供的脸部覆盖位置和表情块尺寸；请求失败时允许为空。 |

### StoryAudioCue

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `string` | 音频 id，例如 `BGM_EVENT_11` 或 `ad1`。 |
| `resource` | `StoryResource?` | 音频资源，包含远端 URL 和本地缓存文件名，解析失败时允许为空。 |
| `type` | `StoryAudioCueType` | `bgm` 或 `soundEffect`。 |

### StoryResource

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `url` | `Uri` | 远端资源 URL。 |
| `cacheFileName` | `string` | 当前脚本缓存子目录下使用的文件名。 |

## 当前边界

- 当前只处理阅读器渲染需要的命令集合，其他 Atlas 演出命令会忽略或只参与文本清理。
- 支持多人站位和 `charaFace` 表情差分，但不还原淡入淡出动画、移动动画、特效、震屏和通信立绘。
- BGM URL 解析失败时保留阅读流程，只跳过播放。
- 音效 URL 使用固定路径规则拼接，未额外请求音效目录。
- 脚本请求失败、BGM 目录请求失败或响应格式异常时，页面进入加载失败态；`svtScript` 请求失败只降级表情覆盖。
