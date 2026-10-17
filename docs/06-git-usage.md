# Git 使用教程

本教程面向初学者，覆盖日常使用 GitHub 项目所需的全部 Git 操作。

## 一、首次配置（只需要做一次）

安装 Git 后，先配置用户名和邮箱：

```powershell
git config --global user.name "你的用户名"
git config --global user.email "你的邮箱@example.com"
```

查看配置：
```powershell
git config --global --list
```

## 二、日常更新流程（最常用）

修改文件后，按以下三步推送到 GitHub：

```powershell
# 1. 查看改了哪些文件
git status

# 2. 添加所有修改到暂存区
git add -A

# 3. 提交（写一句描述）
git commit -m "修复了某某问题"

# 4. 推送到 GitHub
git push
```

## 三、常用命令速查

| 命令 | 作用 | 示例 |
|------|------|------|
| `git status` | 查看当前修改状态 | `git status` |
| `git add -A` | 添加所有修改 | `git add -A` |
| `git add 文件名` | 添加指定文件 | `git add README.md` |
| `git commit -m "描述"` | 提交修改 | `git commit -m "更新文档"` |
| `git push` | 推送到远程仓库 | `git push` |
| `git pull` | 拉取远程更新 | `git pull` |
| `git log --oneline` | 查看提交历史 | `git log --oneline` |
| `git diff` | 查看具体修改内容 | `git diff` |
| `git clone 地址` | 克隆远程仓库 | `git clone https://github.com/xxx/xxx.git` |

## 四、克隆本项目

```powershell
git clone https://github.com/hudeonbush/workbuddy-dual-instance-fix.git
cd workbuddy-dual-instance-fix
```

## 五、从别人的更新中同步

如果 GitHub 上有新的提交（比如别人贡献了代码），拉取到本地：

```powershell
git pull
```

如果本地有未提交的修改，先提交或暂存：
```powershell
git stash        # 临时保存修改
git pull         # 拉取更新
git stash pop    # 恢复修改
```

## 六、代理设置（国内访问 GitHub 可能需要）

如果推送/拉取超时，设置代理：

```powershell
# 设置代理（Clash 默认端口 7890）
git config --local http.proxy http://127.0.0.1:7890
git config --local https.proxy http://127.0.0.1:7890

# 取消代理
git config --local --unset http.proxy
git config --local --unset https.proxy

# 查看当前代理
git config --local --get http.proxy
```

## 七、常见问题

### Q: push 时提示 "Everything up-to-date"
A: 说明没有新的提交需要推送。先 `git status` 确认是否有修改，有修改需要先 `git add` + `git commit`。

### Q: push 时提示 "failed to push some refs"
A: 远程有新的提交，先 `git pull` 拉取合并，再 `git push`。

### Q: commit 信息写错了怎么办
A: 还没 push 的话，可以修改最后一次提交：
```powershell
git commit --amend -m "新的描述"
```

### Q: 想撤销某个文件的修改
A:
```powershell
git checkout -- 文件名    # 撤销单个文件
git checkout -- .          # 撤销所有未提交的修改
```

### Q: 想回到某个历史版本
A:
```powershell
git log --oneline          # 查看提交哈希
git reset --hard 哈希值    # 回退到指定版本（危险，会丢失之后的修改）
```

## 八、推荐工作流

```
修改文件 → git status 确认 → git add -A → git commit -m "描述" → git push
```

每次提交写清楚做了什么，方便以后回溯。
