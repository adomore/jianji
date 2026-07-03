# 简记 iOS 记账应用原型设计

_Started 2026-07-03 16:34 UTC_

---

## User

请先完整阅读我上传的《记账App-PRD.md》，然后为这个 iOS 记账 App「简记」
设计一套高保真、可点击的手机端 UI 原型（iPhone 390×844）。

范围（5 屏，细节以 PRD 第 4、5 章为准）：
1. 明细首页：月度汇总卡片 + 按天分组的账单列表 + 底部 TabBar，
   正中悬浮橙色「＋」大按钮
2. 记账弹出页：支出/收入分段切换、4 列分类图标网格、大字号金额、
   4×4 自定义数字键盘（右侧竖长「完成」键），键盘上方 🎤 和 🖼 两个入口
3. 语音确认卡片：识别原文 + 金额/分类/日期/备注（均可点改）+ 取消/确认
4. 图表页：月份切换、支出/收入/结余三数字、分类甜甜圈图 + 排行、
   每日支出柱状图
5. 首页空状态：无账单时的引导画面

风格：iOS 17 原生感（SF Pro、系统圆角卡片），主色橙色 #FF9500，
收入统一用绿色，克制留白，不要花哨装饰；关键页面各出一版深色模式。

交互：页面间做成可点击跳转（点＋进记账页、点🎤弹确认卡片）。
先出「明细首页 + 记账页」两屏定风格，我确认后再补其余。

## Assistant

_[tool: read_file]_

_[tool: read_skill_prompt]_

_[tool: copy_starter_component]_

_[tool: read_file]_

_[tool: set_project_title]_

_[tool: dc_write]_

_[tool: dc_write]_

_[tool: dc_write]_

_[tool: ready_for_verification]_

