# 02 - 根因深度分析

## 2.1 双开失败根因：安装器合并

### 现象复现

检查发现以下异常：

1. **国内版安装目录被清空**：
   ```
   C:\Users\<user>\AppData\Local\Programs\WorkBuddy\   → 空目录或仅剩少量文件
   ```

2. **国内版主程序被收编**：
   ```
   C:\Users\<user>\AppData\Local\Programs\WorkBuddyAI\WorkBuddy.exe   ← 国内版 exe 出现在国际版目录
   ```

3. **两个快捷方式指向同一程序**：
   - 国内版快捷方式目标 → `WorkBuddyAI\WorkBuddy.exe`（错误）
   - 国际版快捷方式目标 → `WorkBuddyAI\WorkBuddyAI.exe`（正确）

4. **加载同一份代码**：两个入口都加载 `WorkBuddyAI\resources\app.asar`（国际版前端代码）

### 根因

国际版安装器（或自动更新流程）在检测到国内版已安装时，执行了**目录合并/收编**操作：
- 清空国内版 `Programs\WorkBuddy\` 目录
- 将国内版主程序复制/移动到国际版目录
- 可能修改了注册表中的安装路径

这导致国内版的独立安装被破坏，两个版本实际运行同一份国际版代码。

### 设计上本应支持并存

两个版本在 Windows 层面是完全独立的应用：

| 维度 | 国内版 WorkBuddy | 国际版 WorkBuddy AI |
|------|-----------------|-------------------|
| AppId | `{BFD312E9-1019-4F57-9F44-F86246833B50}` | `{C02C88CB-5DAE-4330-AEC1-572CFD048A59}` |
| Mutex | `workbuddy` | `workbuddy-ai` |
| UserModelId | `WorkBuddy.WorkBuddy` | `WorkBuddy.WorkBuddyAI` |
| 数据目录 | `~/.workbuddy/` | `~/.workbuddy-ai/` |
| 安装目录 | `Programs\WorkBuddy\` | `Programs\WorkBuddyAI\` |

Mutex 不同意味着两个进程不会互相排斥，数据目录不同意味着配置和登录态天然隔离。**安装器的合并行为是 bug，不是设计限制。**

---

## 2.2 国内版白屏根因：版本-服务端不兼容

### 诊断过程

1. **文件完整性检查**：部署的 5.3.14 文件完整（1476/1476，无缺失）
2. **主进程日志**：正常，能连接 `copilot.tencent.com`，代理 `127.0.0.1:7890` 正常
3. **渲染进程**：存在但页面空白
4. **干净数据目录测试**：用 `WORKBUDDY_CONFIG_DIR` 指定全新目录启动，**仍然白屏** → 排除数据不兼容
5. **Crash-Log 分析**：发现 React 渲染崩溃

### 关键证据

```
Error: Minified React error #31; visit https://reactjs.org/docs/error-decoder.html?invariant=31
  &args[]=object%20with%20keys%20%7B%24wbEncrypted%2C%20envelope%7D
    at Mg (react-dom-*.js:2665:9)
    at J (react-dom-*.js:2892:5)
    ...
```

### React Error #31 含义

> Objects are not valid as a React child (found: object with keys {$wbEncrypted, envelope})

React 渲染时遇到了一个对象 `{$wbEncrypted, envelope}`，而它期望的是字符串、数字或 React 元素。

### 根因

- 5.3.14（2025 年 8 月）的前端代码**无法解码** 5.8.x 服务端返回的**加密消息信封**（`$wbEncrypted` + `envelope` 结构）
- 服务端（`copilot.tencent.com`）已升级到 5.8.x 协议，返回加密格式的消息
- 旧版前端将加密对象直接当作 React child 渲染 → 崩溃 → 白屏

### 为什么干净数据目录也复现

因为问题不在本地数据，而在**客户端版本与服务端协议的不匹配**。只要用 5.3.14 连接当前服务端，就会收到无法解码的加密消息，必然崩溃。

### 结论

**5.3.14 旧版已无法与当前服务端兼容，必须升级到 5.8.x。**
