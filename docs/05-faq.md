# 05 - 常见问题

## Q1：为什么不用官方安装器直接安装？

官方 NSIS 安装器在已安装过另一版本的系统上，会因旧注册项路径残留把文件装进错误目录，并可能破坏另一版本的 `resources/app.asar`。`tar` 解包 + `robocopy` 是最可控的方式，完全避免安装器的路径解析逻辑。

## Q2：`platform` 参数为什么必须用 `workbuddy-win32-x64-user`？

更新 API 支持三种 platform 参数，但只有 `user` 格式的包在下载服务器上真实存在：

| platform | API 响应 | 下载结果 |
|----------|---------|---------|
| `workbuddy-win32-x64-user` | 200，返回 user 包 URL | ✅ 可下载 |
| `workbuddy-win32-x64-archive` | 200，返回 archive 包 URL | ❌ HTTP 404 NoSuchKey |
| `workbuddy-win32-x64` | 400 错误 | — |

archive 格式的 URL 是 API 返回的，但服务器上没有对应文件（可能是内部渠道或已下架）。

## Q3：`x-user-id` 怎么获取？

可以从以下位置获取：
- `~/.workbuddy/` 目录下的配置文件
- `~/.workbuddy/logs/` 中的日志（更新请求 URL 中包含）
- 也可以用任意 UUID 格式字符串，API 不严格校验

## Q4：白屏一定是版本太旧吗？

在本案例中是的。但白屏也可能由其他原因导致：
- 代理/网络问题导致前端资源加载失败
- 数据目录损坏
- GPU 渲染问题（可尝试 `--disable-gpu` 启动）

排查顺序：先看 `renderer.log` 有无 React 崩溃，再用 `WORKBUDDY_CONFIG_DIR` 指定干净目录测试。

## Q5：`WORKBUDDY_CONFIG_DIR` 和 `WORKBUDDY_DATA_FOLDER_NAME` 有什么区别？

| 变量 | 作用 | 用户可覆盖 |
|------|------|-----------|
| `WORKBUDDY_CONFIG_DIR` | 指定完整的数据目录路径 | ✅ 直接生效 |
| `WORKBUDDY_DATA_FOLDER_NAME` | 内部使用的目录名，启动时被代码覆写 | ❌ 设置无效 |

要切换数据目录，用 `WORKBUDDY_CONFIG_DIR=C:\path\to\dir`。

## Q6：两个版本会共享数据吗？

不会。数据目录完全隔离：
- 国内版：`~/.workbuddy/`
- 国际版：`~/.workbuddy-ai/`

登录态、对话历史、配置均各自独立。

## Q7：升级后国内版的登录态还在吗？

在。升级只替换 `Programs\WorkBuddy\` 下的程序文件，不影响 `~/.workbuddy/` 数据目录。登录态和对话历史保留。

## Q8：以后官方更新会再次破坏双开吗？

有可能。如果国际版自动更新再次触发目录合并，需要重新执行部署步骤。建议：
- 关闭自动更新（如应用内有选项）
- 更新前备份两个版本的安装目录
- 关注本项目的更新

## Q9：macOS/Linux 适用吗？

本项目的脚本和路径基于 Windows。macOS 的应用包结构（.app）和更新机制不同，但根因分析（安装器合并、版本-服务端不兼容）可能类似。

## Q10：部署后启动报错"找不到 DLL"怎么办？

可能是 `tar` 解包不完整或 `robocopy` 中断。重新执行：
1. 停止进程
2. 删除目标目录
3. 重新 `tar -xf` 解压
4. 重新 `robocopy /MIR`
5. 验证文件数与解压目录一致
