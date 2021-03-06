---
title: Tmux极简使用
date: 2021-04-21T11:14:42+00:00
categories: ['运维工具']
tags: ["tmux"]
---

### Tmux

当我们需要通过SSH连接服务器进行一些操作，如果在公司做的操作，下班回家后是看不到的，而且一段时间后软件session会超时终端，之前的信息都没了，所以有了类似screen这种会话持久化工具，tmux也是其中一种。mac使用tmux也可以做到分屏功能，非常强大。本文介绍tmux最常用的功能。

（1）它允许在单个窗口中，同时访问多个会话。这对于同时运行多个命令行程序很有用。

（2） 它可以让新窗口”接入”已经存在的会话。

（3）它允许每个会话有多个连接窗口，因此可以多人实时共享会话。

（4）它还支持窗口任意的垂直和水平拆分。

项目地址：<https://github.com/tmux/tmux>

### 安装

```
# Ubuntu 或 Debian
$ sudo apt-get install tmux
# CentOS 或 Fedora
$ sudo yum install tmux
# Mac
$ brew install tmux
```

### 会话(session)

```
#新建session
tmux new -s <session-name>
#退出并关闭session
Ctrl+d或exit
#退出session
Ctrl+b d
#查看所有session
tmux ls
#接入会话
$ tmux attach -t 0
$ tmux attach -t <session-name>
#删除会话
$ tmux kill-session -t 0
$ tmux kill-session -t <session-name>
#切换会话
$ tmux switch -t 0
$ tmux switch -t <session-name>
#重命名
tmux rename-session -t 0 <new-name>

```

### 窗格(pane)

```
Ctrl+b %：划分左右两个窗格
Ctrl+b "：划分上下两个窗格
Ctrl+b <arrow key>：光标切换到其他窗格
Ctrl+b ;：光标切换到上一个窗格
Ctrl+b o：光标切换到下一个窗格
Ctrl+b x：关闭当前窗格
Ctrl+b z：当前窗格全屏显示，再使用一次会变回原来大小
Ctrl+b Ctrl+<arrow key>：调整窗格大小
```

### 窗口(window)

```
Ctrl+b c：创建一个新窗口，状态栏会显示多个窗口的信息。
Ctrl+b p：切换到上一个窗口（按照状态栏上的顺序）。
Ctrl+b n：切换到下一个窗口。
Ctrl+b <number>：切换到指定编号的窗口，其中的<number>是状态栏上的窗口编号。
Ctrl+b w：从列表中选择窗口。
Ctrl+b ,：窗口重命名。
```

### 其它

```
#列出所有快捷键，及其对应的 Tmux 命令
tmux list-keys
#列出所有 Tmux 命令及其参数
tmux list-commands
#列出当前所有 Tmux 会话的信息
tmux info
#重新加载当前的 Tmux 配置
tmux source-file ~/.tmux.conf
#向所有窗格发送命令
Ctrl-B :
setw synchronize-panes on
```

tmux也可以把ctrl+b设置为ctrl+a等更容易按的快捷键，也可以支持鼠标操作等，我个人喜欢原生态的软件，这样到哪个环境使用习惯都是一样的，这里不再赘述。