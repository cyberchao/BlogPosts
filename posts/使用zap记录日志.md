---
title: 使用Zap记录日志
date: 2021-04-06T23:41:42+00:00
categories: ["Go"]
tags: ["log","zap"]
---

## 介绍

**优势**
它最大的优点是使用非常简单。我们可以设置任何io.Writer作为日志记录输出并向其发送要写入的日志。
劣势

**劣势**

- 仅限基本的日志级别

  ​	只有一个Print选项。不支持INFO/DEBUG等多个级别。

- 对于错误日志，它有Fatal和Panic

  ​	Fatal日志通过调用os.Exit(1)来结束程序

  ​	Panic日志在写入日志消息之后抛出一个panic

  ​	但是它缺少一个ERROR日志级别，这个级别可以在不抛出panic或退出程序的情况下记录错误

- 缺乏日志格式化的能力——例如记录调用者的函数名和行号，格式化日期和时间格式。等等。

- 不提供日志切割的能力。

Zap是非常快的、结构化的，分日志级别的Go日志库。

## **安装zap**

`go get -u go.uber.org/zap`
Zap提供了两种类型的日志记录器—Sugared Logger和Logger。

在性能很好但不是很关键的上下文中，使用SugaredLogger。它比其他结构化日志记录包快4-10倍，并且支持结构化和printf风格的日志记录。

在每一微秒和每一次内存分配都很重要的上下文中，使用Logger。它甚至比SugaredLogger更快，内存分配次数也更少，但它只支持强类型的结构化日志记录。

## lumberjack切割日志

Zap本身不支持切割归档日志文件，使用lumberjack切割文件，还可以实现日志追加

以下是完整代码

```go
package main

import (
  "go.uber.org/zap"
  "go.uber.org/zap/zapcore"
  "gopkg.in/natefinch/lumberjack.v2"
  "net/http"
)

var sugarLogger *zap.SugaredLogger

func InitLogger() {
  writeSyncer := getLogWriter()
  encoder := getEncoder()
  core := zapcore.NewCore(encoder, writeSyncer, zapcore.DebugLevel)

  logger := zap.New(core, zap.AddCaller())
  sugarLogger = logger.Sugar()
}

func getEncoder() zapcore.Encoder {
  encoderConfig := zap.NewProductionEncoderConfig()
  encoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
  encoderConfig.EncodeLevel = zapcore.CapitalLevelEncoder
  return zapcore.NewConsoleEncoder(encoderConfig)
}

func getLogWriter() zapcore.WriteSyncer {
  lumberJackLogger := &lumberjack.Logger{
    Filename:   "123.log",
    MaxSize:    10,
    MaxBackups: 5,
    MaxAge:     30,
    Compress:   false,
  }
  return zapcore.AddSync(lumberJackLogger)
}

func simpleHttpGet(url string) {
  sugarLogger.Debugf("Trying to hit GET request for %s", url)
  resp, err := http.Get(url)
  if err != nil {
    sugarLogger.Errorf("Error fetching URL %s : Error = %s", url, err)
  } else {
    sugarLogger.Infof("Success! statusCode = %s for URL %s", resp.Status, url)
    resp.Body.Close()
  }
}

func main() {
  InitLogger()
  defer sugarLogger.Sync()
  simpleHttpGet("www.google.com")
  simpleHttpGet("http://www.baidu.com")
}
```

输出日志：

```
2021-03-11T14:24:49.425+0800  DEBUG myproject/simplehttp.go:40  Trying to hit GET request for www.google.com

2021-03-11T14:24:49.426+0800  ERROR myproject/simplehttp.go:43  Error fetching URL www.google.com : Error = Get "www.google.com": unsupported protocol scheme ""

2021-03-11T14:24:49.426+0800  DEBUG myproject/simplehttp.go:40  Trying to hit GET request for http://www.baidu.com

2021-03-11T14:24:49.463+0800  INFO  myproject/simplehttp.go:45  Success! statusCode = 200 OK for URL http://www.baidu.com

2021-03-11T14:24:59.447+0800  DEBUG myproject/simplehttp.go:40  Trying to hit GET request for www.google.com

2021-03-11T14:24:59.447+0800  ERROR myproject/simplehttp.go:43  Error fetching URL www.google.com : Error = Get "www.google.com": unsupported protocol scheme ""

2021-03-11T14:24:59.447+0800  DEBUG myproject/simplehttp.go:40  Trying to hit GET request for http://www.baidu.com

2021-03-11T14:24:59.477+0800  INFO  myproject/simplehttp.go:45  Success! statusCode = 200 OK for URL http://www.baidu.com

2021-03-11T14:25:01.889+0800  DEBUG myproject/simplehttp.go:40  Trying to hit GET request for www.google.com

2021-03-11T14:25:01.889+0800  ERROR myproject/simplehttp.go:43  Error fetching URL www.google.com : Error = Get "www.google.com": unsupported protocol scheme ""

2021-03-11T14:25:01.889+0800  DEBUG myproject/simplehttp.go:40  Trying to hit GET request for http://www.baidu.com

2021-03-11T14:25:01.920+0800  INFO  myproject/simplehttp.go:45  Success! statusCode = 200 OK for URL http://www.baidu.com

```

参考： https://www.liwenzhou.com/posts/Go/zap/ https://pkg.go.dev/go.uber.org/zap
