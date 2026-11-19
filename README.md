# Language Learning App Blueprint V1.0

面向 TOEIC、TOEFL、JLPT 的 iOS / Android / HarmonyOS NEXT 多端智能刷题 App 技术设计蓝图。

## 文件结构

- `docs/architecture.md`：系统架构、功能模块、开发计划
- `docs/er.mmd`：Mermaid 数据库 ER 图
- `db/schema.sql`：PostgreSQL 表结构初稿
- `api/openapi.yaml`：REST API OpenAPI 契约初稿

## 技术方向

- 移动端：uni-app x + Vue 3 + TypeScript
- 服务端：FastAPI + SQLAlchemy + PostgreSQL + Redis
- 管理后台：React + TypeScript + Ant Design Pro
- 音频：对象存储/CDN + 平台播放器和录音能力

> 此仓库目前为 **设计蓝图**，不是可直接运行的完整 App。数据库与 API 契约仍需在开发中验证、完善。
