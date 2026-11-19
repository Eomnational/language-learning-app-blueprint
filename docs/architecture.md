# 语言学习三端 App 技术设计 V1.0

> 目标：TOEIC / TOEFL iBT（2026版）/ JLPT；iOS、Android、HarmonyOS NEXT 三端共享统一账号、题库及学习记录。日期：2026-11-19。

## 1. 总览与取舍

- Mobile: uni-app x + Vue 3 + TypeScript / UTS；基础平台能力封装为 `PlatformAudio`、`PlatformRecorder`、`PlatformLocalDB`、`PlatformPurchase` 等接口；以实机验证为准。
- Admin: React + TypeScript + Ant Design Pro。
- API: Python 3.12+ + FastAPI + SQLAlchemy 2 + Alembic + Pydantic v2。
- DB: PostgreSQL 主数据；Redis 作缓存、限流、异步任务 broker；本地 SQLite 做离线题包/答题队列（须三端适配验证）。
- Worker: Celery，处理音频转码、异步口语/作文评测、学习报告。
- Object Storage: S3 兼容对象存储 + CDN；录音存储使用私有桶，短时签名 URL。
- 部署：Docker Compose（第一阶段）、Nginx、CI/CD、日志与监控；不预先上微服务和 K8s。
- 原则：题库与考试规则版本化、内容/题组/题目分离、服务端判题、事件化答题记录、跨设备游标同步、会员权益和支付订单分离。

### 需要提前验证的三端能力

1. `uni.createInnerAudioContext`：倍速、seek、区间复读、耳机切换、锁屏与后台行为。
2. `uni.getRecorderManager`：权限申请、录音文件格式、时长限制、系统中断恢复。
3. SQLite 原生插件：三端是否支持相同 SQL 功能、迁移与事务；框架 storage 不应被当作完整 SQLite 公共接口。
4. 文件读写、网络中断和断点续传、证书信任策略、后台任务。
5. 华为 IAP / Apple IAP / Google Play Billing：必须分别接入并服务端核验。

## 2. Monorepo 项目目录

```text
language-learning-platform/
├─ apps/
│  ├─ mobile/                         # uni-app x 原生三端 App
│  │  ├─ pages.json                   # 页面路由 / tabBar
│  │  ├─ manifest.json                # 平台打包配置
│  │  ├─ App.uvue
│  │  ├─ main.uts
│  │  ├─ pages/
│  │  │  ├─ home/index.uvue
│  │  │  ├─ catalog/index.uvue
│  │  │  ├─ catalog/package-detail.uvue
│  │  │  ├─ practice/session.uvue
│  │  │  ├─ practice/result.uvue
│  │  │  ├─ mock/index.uvue
│  │  │  ├─ mock/exam.uvue
│  │  │  ├─ review/index.uvue
│  │  │  ├─ review/question.uvue
│  │  │  ├─ profile/index.uvue
│  │  │  └─ auth/login.uvue
│  │  ├─ components/
│  │  │  ├─ questions/                # 题型渲染器
│  │  │  │  ├─ ChoiceQuestion.uvue
│  │  │  │  ├─ MultiChoiceQuestion.uvue
│  │  │  │  ├─ ClozeQuestion.uvue
│  │  │  │  ├─ OrderQuestion.uvue
│  │  │  │  ├─ WritingQuestion.uvue
│  │  │  │  └─ SpeakingQuestion.uvue
│  │  │  ├─ StimulusPanel.uvue        # 图文共用题干、阅读材料
│  │  │  ├─ AudioPlayer.uvue
│  │  │  ├─ RecorderControl.uvue
│  │  │  └─ QuestionNavigator.uvue
│  │  ├─ modules/
│  │  │  ├─ auth/
│  │  │  ├─ catalog/
│  │  │  ├─ practice/                  # 练习状态机、动作、路由
│  │  │  ├─ review/                    # 错题复习调度
│  │  │  ├─ mock/                      # 考试模式
│  │  │  ├─ media/                     # 播放、录音、缓存
│  │  │  ├─ sync/                      # outbox + cursor
│  │  │  └─ billing/
│  │  ├─ platform/
│  │  │  ├─ audio/
│  │  │  ├─ recorder/
│  │  │  ├─ local-db/
│  │  │  ├─ secure-storage/
│  │  │  └─ billing/
│  │  ├─ services/                     # 经过类型约束的 HTTP API
│  │  ├─ stores/                       # 用户、会话、播放状态
│  │  ├─ i18n/                         # zh-CN / ja-JP / en-US
│  │  ├─ static/
│  │  └─ uni_modules/                  # UTS 跨端原生插件
│  └─ admin/
│     └─ src/
│        ├─ pages/{dashboard,exams,packages,questions,media,users,orders}/
│        ├─ components/{QuestionEditor,PassageEditor,AudioUploader}/
│        ├─ services/
│        ├─ routes/
│        └─ auth/
├─ services/
│  └─ api/
│     ├─ pyproject.toml
│     ├─ alembic/
│     ├─ app/
│     │  ├─ main.py
│     │  ├─ core/{config,security,db,exceptions,observability}.py
│     │  ├─ modules/
│     │  │  ├─ identity/
│     │  │  ├─ catalog/
│     │  │  ├─ content/
│     │  │  ├─ practice/
│     │  │  ├─ scoring/
│     │  │  ├─ review/
│     │  │  ├─ sync/
│     │  │  ├─ media/
│     │  │  ├─ speech/
│     │  │  ├─ ai/
│     │  │  ├─ billing/
│     │  │  └─ admin/
│     │  ├─ tasks/{media,speech,report}.py
│     │  └─ providers/{storage,asr,llm,iap}/
│     └─ tests/{unit,integration,contract}/
├─ contracts/                          # OpenAPI、JSON Schema、示例请求
├─ db/{schema.sql,seed.sql}
├─ infra/{docker,nginx,monitoring,ci}/
├─ docs/{architecture.md,er.mmd,adr,release-checklist.md}
└─ .github/workflows/
```

说明：uni-app x 对部分 TypeScript / 第三方包有语法及平台限制；不建议直接将 Web 端 UI 库或 TS SDK 无差别复制到 UTS。以 OpenAPI/JSON Schema 作为接口协议，分别生成/维护兼容模型。

## 3. 数据模型

- `exams`：考试族，如 TOEIC_LR、TOEFL_IBT、JLPT。
- `exam_editions`：考试版本，包含版本号、考试时间范围、蓝图与评分策略 JSONB（TOEFL 2026 版单独建版）。
- `content_packages`：题包 / 教材；绑定考试版本，包含许可、发布状态、下载策略。
- `sections`：听力、阅读、词汇、语法、口语、写作等分组。
- `stimuli` / `stimulus_versions`：共享材料的稳定身份与不可变版本（音频、图片、文章、多个 passage 的组合）；多题可共用。
- `questions`：稳定逻辑题号和知识点；`question_versions`：不可变的已发布题目版本，引用固定 `stimulus_version_id`。
- `media_assets`：媒体文件哈希、权限、存储路径、时长；经 `question_media` 和 `stimulus_media` 与题目、材料版本关联。
- `practice_sessions`：练习/模考实例；`session_items`：开启会话时固定题号和版本快照。
- `attempts`：用户每次提交的答题事件，唯一 `client_attempt_id` 幂等，不能覆盖历史。
- `question_progress`：根据事件投影得到用户掌握度；`review_schedule`：复习计划与到期时间。
- `speech_jobs`：异步录音评分、作文评阅状态与服务商成本；`media_uploads`：临时上传。
- `purchase_orders`：各应用商店订单/交易；`entitlements`：用户当前可使用的会员权益。
- `sync_events`：跨设备同步的可重放事件序号（全局递增），供客户端 cursor 拉取。

详见 `db/schema.sql` 与 `docs/er.mmd`。所有主键用 UUID；使用 `TIMESTAMPTZ` 存 UTC，客户端按用户时区展示。

## 4. 通用题目引擎

**不是给 TOEIC / TOEFL / JLPT 各写一套题目页面。**

统一结构：

```text
ExamEdition -> ContentPackage -> Section -> Stimulus/QuestionGroup
                                                   -> QuestionVersion
      QuestionVersion = Presentation(body) + Interaction(answer_schema) + ScoringPolicy
```

三层解耦：

1. `StimulusVersion`：不可变的听力音频、阅读文章、图片、字幕快照，多个题目版本可引用。
2. `Interaction`：`single_choice`、`multiple_choice`、`cloze`、`reorder`、`short_text`、`essay`、`audio_response`。
3. `ScoringPolicy`：`exact_match`、`multi_select`、`sequence_match`、`rubric_async` 等；评分逻辑运行在服务端。

`question_versions.body` 只放 UI 安全字段，`question_versions.answer_key` 只允许服务端/管理后台读取。发布后若需改题，新建版本；在途会话仍按 `session_items.question_version_id` 固定版本。

**示例练习题**（API 下发时不包含正确答案）：

```json
{
  "id": "sample-jlpt-1",
  "version": 1,
  "exam": "JLPT",
  "section": "grammar",
  "interaction": "single_choice",
  "stimulus": null,
  "body": {
    "stem": "この本はとても（　）です。",
    "options": [
      {"id": "A", "text": "おもしろい"},
      {"id": "B", "text": "おもしろく"},
      {"id": "C", "text": "おもしろさ"},
      {"id": "D", "text": "おもしろかった"}
    ]
  },
  "answer_schema": {"kind": "option_ids", "min": 1, "max": 1},
  "render_hints": {"furigana": true, "show_translation": false}
}
```

题型矩阵：

| 技能 / 考试 | 交互 | 特别要求 |
|---|---|---|
| TOEIC L&R Listening | single_choice | 共享录音、图片、对话题组、听力播放策略 |
| TOEIC L&R Reading | single_choice | 多篇文章共享、一题或多题型组合 |
| JLPT 词汇/语法/阅读 | single_choice、reorder | 假名/汉字字体、富文本、词序题 |
| JLPT 听力 | single_choice | 音频与图片/文本提示 |
| TOEFL 2026 Reading | cloze、single_choice | Complete the Words 等新版阅读任务 |
| TOEFL 2026 Listening | single_choice | 真实听力材料与测试时间策略 |
| TOEFL 2026 Writing | reorder、short_text、essay | Build a Sentence、Email、Discussion |
| TOEFL 2026 Speaking | audio_response | Listen and Repeat、Interview，异步评分 |

*正式考试/官方分数预测只在取得相应授权、验证评价和等值机制后对外使用；自建题包可展示练习分、能力趋势，不应声称为官方分数。*

状态机：`created -> active -> paused -> submitted -> grading -> graded`，超时可由服务端转为 `expired`。题目提交用 `client_attempt_id` 幂等；会话采用 `exam_edition_id` + 固定版本快照和服务端截止时间。模考计时不能只信任客户端时钟。

判题：
- 客观题：确定性判断，支持多选部分得分、填空标准化（按题型选择）及顺序题严格匹配。
- 口语/写作：`pending_review`，入队异步评测，存储评分规则版本、服务商、置信度与人工复核标记。
- 不让 LLM 决定客观题标准答案。
- 题包发布前执行校验：正确答案包含在选项中、音频存在、题号唯一、关联材料可访问、题目版本合法。

## 5. API 设计

Base: `/api/v1`。登录使用短时 access token 与可轮换 refresh token；HTTPS；所有变更操作带幂等键。错误格式统一：`{code,message,details,request_id}`，时间为 ISO 8601 UTC。

| 方法 | 路径 | 权限 | 描述 |
|---|---|---|---|
| POST | `/auth/login` | Public | 登录 |
| POST | `/auth/refresh` | Refresh | 刷新登录凭证 |
| GET | `/me` | User | 当前用户 |
| GET | `/exams` | Public | 考试类型、现行版本 |
| GET | `/packages?exam=JLPT&level=N2` | User | 题包/教材列表 |
| GET | `/packages/{id}` | User | 题包详情、章节 |
| POST | `/practice/sessions` | User | 创建练习/模考实例 |
| GET | `/practice/sessions/{id}` | User | 读取会话和固定题目快照（无答案） |
| POST | `/practice/sessions/{id}/attempts:batch` | User | 批量上传答题事件（幂等） |
| POST | `/practice/sessions/{id}/submit` | User | 交卷，触发评分/报告 |
| GET | `/practice/sessions/{id}/result` | User | 成绩和解析（受模式权限约束） |
| GET | `/progress/overview` | User | 正确率、题量、学习时长 |
| GET | `/review/due` | User | 到期复习题 |
| POST | `/review/ratings` | User | 复习质量评价 |
| GET | `/sync/changes?cursor=...` | User | 服务端增量事件 |
| POST | `/sync/push` | User | 批量离线同步事件 |
| POST | `/media/uploads/presign` | User | 私有录音上传签名 |
| POST | `/speech/jobs` | User | 触发口语评分 |
| GET | `/speech/jobs/{id}` | User | 轮询评测进度和结果 |
| POST | `/billing/verify` | User | 服务端校验渠道交易 |
| GET | `/me/entitlements` | User | 会员权益 |
| POST | `/billing/webhooks/{platform}` | Provider | 订阅退款、续费通知 |
| POST | `/admin/questions` | Admin | 新建题目草稿 |
| POST | `/admin/questions/{id}/publish` | Admin | 发布不可变题目版本 |
| POST | `/admin/packages/import` | Admin | 题包批量导入并校验 |

OpenAPI 子集见 `api/openapi.yaml`。开发时由 FastAPI 自动导出完整 OpenAPI 并做接口契约测试。

### 离线与跨端同步

客户端维护 `outbox(id,device_id,client_event_id,type,payload,occurred_at,status)`：

1. 答题立即落盘；`client_event_id` 用 UUIDv4，避免离线重复。
2. 有网时批量 `POST /sync/push`；服务端在一个事务内去重入库。
3. 服务端以 `sync_events.seq` 记录可重放的变化；客户端按 cursor 拉 `GET /sync/changes`。
4. `attempts` 只追加；收藏按每项最后操作版本/服务器序号合并；学习累计时间使用会话去重，不能两端简单相加。
5. `question_progress` 和 `review_schedule` 由服务端按事件重算或增量投影；重装客户端仍能恢复。
6. 离线模式优先缓存答题内容，联网后统一评分；若必须离线显示答案，需要单独权衡内容泄露风险。

### 音频与口语上传

- 公共教材音频：CDN + 可撤销资源许可；受版权限制的资源使用短时签名链接或分发鉴权。
- 用户录音：授权后录音到应用私有目录 -> 创建上传签名 -> 直接上传私有对象存储 -> 提交评测任务 -> 获取结果；服务端校验文件大小、MIME、实际文件格式。
- 上传失败支持重试；用户可撤回、删除录音；限制保留周期；模型评测注明“练习反馈，并非官方成绩”。

## 6. App 页面结构

底部五 Tab：`首页` / `题库` / `模考` / `复习` / `我的`。

```text
首页
  ├─ 目标考试切换（TOEIC / TOEFL / JLPT）
  ├─ 今日任务：单词、语法、听力、阅读、口语
  ├─ 继续上次进度
  └─ 学习统计：时长、准确率、连续天数
题库
  ├─ 考试 -> 等级/教材 -> 章节/专题
  ├─ 题型筛选/进度
  └─ 答题页（共享题干 + 音频 + 选项 + 底部操作栏）
模考
  ├─ 按考试版本选择试卷
  ├─ 模考须知 / 倒计时 / 答题卡
  └─ 提交 -> 报告 / 错题分析
复习
  ├─ 今日待复习 / 错题 / 收藏
  ├─ 单词卡 / FSRS 调度（V2）
  └─ 弱项知识点
我的
  ├─ 个人信息 / 目标 / 学习统计
  ├─ 会员 / 订单
  ├─ 下载管理 / 离线资源
  └─ 设置（语言、隐私、录音清理、注销）
```

答题屏：顶部进度/计时；中间题组材料；下方交互组件；底部“上一题/下一题/提交”；模拟考试模式隐藏解析，练习模式交卷后按规则展示解析。

Web 后台导航：总览、考试版本、教材题包、题组/题目编辑器、媒体资源、批量导入、题目审核发布、用户与学习报表、订单与权限、操作审计。

## 7. 权限、合规与安全

- 题库原文、教材图片、官方音频需合法授权；仅引用考试名称也要注意商标使用规范。
- 管理后台 RBAC：`admin/editor/reviewer/support`；题目至少 `draft -> in_review -> published -> archived`。
- API 必须鉴权与限流；答题接口不发送答案键；审核与发布分离；管理员操作审计。
- 录音、行为统计说明处理目的、保留期限、删除方式；处理未成年人数据时添加适用的合规措施。
- 密码/凭证不落明文日志；敏感凭据用平台安全存储；对象存储最小权限。
- 支付：Apple StoreKit、Google Play Billing、华为 IAP 独立适配；订单核验、退款/续费 webhook、幂等事件处理、权益统一投影。
- 所有课程和学习统计区分 `practice_score` 与 `official_exam_score`；不要虚假宣称官方认可。

## 8. 实施路线（独立开发者全职，估算）

| 阶段 | 目标 | 时间估计 | 验收标准 |
|---|---|---|---|
| P0 技术探针 | 三端音频、录音、SQLite、安装签名 | 1–2 周 | 真机可录制/播放/落库，三端都能启动 |
| P1 工程与后台 | 仓库、CI、认证、数据库、题包 CRUD、审核导入 | 2 周 | 可在后台创建并发布 100 道原创题 |
| P2 通用做题 | 单选、填空、排序、题组、判题、错题、统计 | 2–3 周 | 练习和模考完整闭环，答案不泄露 |
| P3 媒体与同步 | 倍速、循环、录音、离线 outbox、跨端同步 | 2–3 周 | iPhone 离线作答，鸿蒙登录后恢复 |
| P4 考试配置 | TOEIC、JLPT 配置包、TOEFL 2026 配置骨架 | 2 周 | 通过版本配置切换题型/时间规则 |
| P5 稳定与发布 | 三端回归、安全/隐私/合规、灰度测试 | 2–3 周 | 崩溃、支付、弱网、权限、恢复测试通过 |

**首个 MVP 合计预计约 11–16 周**，假设个人全职、原创小型题库、暂不做完整官方级自适应评分和会员商业化。三考试覆盖全部题型、AI 批改、购买系统与高质量商业题库会显著增加周期，通常作为后续版本。

### 测试策略

- Unit：所有评分策略、答案归一化、多设备去重、复习调度。
- Integration：PostgreSQL 事务与并发、发题会话快照、重试、异步任务。
- Contract：OpenAPI schema 与客户端数据类型一致。
- E2E：三端登录、练习、断网重连、继续练习、考试超时、后台播放、录音权限拒绝。
- Security：越权访问、答案泄漏、支付伪造、上传恶意文件、速率限制。
- Performance：以目标设备及真实网络开展基准；初始建议 API 非媒体请求 p95 < 300 ms（同地域、缓存命中路径），后续按基线调整。

## 9. 下一步按优先级执行

1. **先做 P0**：真实鸿蒙设备验证播放器、录音和数据库持久化，及时发现跨端技术选型风险。
2. 固定 `QuestionV1` JSON Schema 和 `ExamEdition` 规则 schema，后台导入 Excel -> 草稿 -> 审核 -> 发布。
3. 完成纯服务端判题、题库版本快照、离线事件同步。
4. 先发布 JLPT 词汇/语法/听力和 TOEIC 基础听读题型，验证用户留存，再扩展 TOEFL 新版口语写作与 AI。

官方资料（访问于 2026-11-19）：
- https://doc.dcloud.net.cn/uni-app-x/app-harmony/
- https://doc.dcloud.net.cn/uni-app-x/tutorial/compatibility.html
- https://www.ets.org/toefl/test-takers/ibt/about/content.html?version=after-jan-2026
- https://www.ets.org/toeic/about/listening-reading.html
- https://www.jlpt.jp/cn/guideline/testsections.html
