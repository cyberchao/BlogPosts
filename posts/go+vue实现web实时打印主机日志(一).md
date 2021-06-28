---
title: go+vue实现web实时打印主机日志(一)
date: 2021-04-16T11:14:42+00:00
categories: ['Go']
tags: ["go","websocket"]
---

在一套nginx集群有很多台机器，而且日志系统不完善的情况下，查看域名的访问日志是非常痛苦的，如果有四台nginx作为集群的话，日志就会分布在四台主机上，非常不方便。最近在开发nginx管理平台，在想每个域名的后面可以添加一个查看日志的按钮，点击弹出terminal页面，与后端建立websocket即可实现方便实时打印所有主机上的nginx访问日志。

本篇先实现通过ssh密码登录到各台主机并执行tail -f命令，把命令输出打印到一个终端的效果。

正好看到github上已经有人实现了，修修剪剪最终实现为我需求的代码

参考项目：<https://github.com/mylxsw/remote-tail>

**源码：**

```
package main

import (
  "bufio"
  "fmt"
  "io"
  "sshtail/ssh"
  "sync"
)

// Message The message used by channel to transport log line by line
type Message struct {
  Host    string
  Content string
}
type Server struct {
  Hostname string
  User     string
  Password string
  File     string
  Stdout   io.Reader
}

// Execute the remote command
func (server *Server) Execute(output chan Message) {

  client := &ssh.Client{
    Host:     server.Hostname,
    User:     server.User,
    Password: server.Password,
  }

  if err := client.Connect(); err != nil {
    panic(fmt.Sprintf("[%s] unable to connect: %s", server.Hostname, err))
  }
  defer client.Close()

  session, _ := client.NewSession()
  defer session.Close()

  session.RequestPty("xterm", 80, 40, *ssh.CreateTerminalModes())
  server.Stdout, _ = session.StdoutPipe()

  go tailOutput(server.Hostname, output, &server.Stdout)
  //session.Start("tail -f " + server.File)
  if err := session.Start("tail -f " + server.File); err != nil {
    panic(fmt.Sprintf("[%s] failed to execute command: %s", server.Hostname, err))
  }
  session.Wait()
}

// bing the pipe output for formatted output to channel
func tailOutput(host string, output chan Message, input *io.Reader) {
  reader := bufio.NewReader(*input)
  for {
    line, _ := reader.ReadString('\n')
    output <- Message{
      Host:    host,
      Content: line,
    }
  }
}

func main() {
  var server1 = Server{
    Hostname: "10.0.0.10:22",
    User:     "root",
    Password: "1",
    File:     "/tmp/test1.log",
  }
  var server2 = Server{
    Hostname: "10.0.0.11:22",
    User:     "root",
    Password: "1",
    File:     "/tmp/test.log",
  }

  var servers = []Server{server1, server2}
  outputs := make(chan Message, 255)
  //等待goroutines执行结束 https://gobyexample.com/waitgroups
  var wg sync.WaitGroup

  for _, server := range servers {
    wg.Add(1)
    go func(server Server) {
      defer wg.Done()
      server.Execute(outputs)
    }(server)
  }

  go func() {
    for output := range outputs {
      fmt.Printf(
        output.Content,
      )
    }
  }()

  wg.Wait()
}
```
