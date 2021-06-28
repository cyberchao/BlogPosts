---
title: Nginx配置与json互转
date: 2021-04-06T11:14:42+00:00
categories: ['运维工具']
tags: ["nginx"]
---

> 大型企业中，内部或外部域名数量极多，配置因为需求不同也五花八门，而公司又有许多分析的需求，比如域名对应的location盘点，upstream分析等。可以利用crossplane完成配置文件与json的互转，转换为json后分析就非常灵活了，甚至可以利用此工具完成nginx的变更自动化

[crossplane](https://github.com/nginxinc/crossplane)

工具提供go port：<https://github.com/aluttik/go-crossplane>

### 配置文件解析为json

**示例配置文件**

```
http {
    server {
        listen      443 ssl ;
        server_name  caiku.yqb.com;

        location / {
            proxy_pass http://fcsmbiz-http;
        }
        access_log /wls/applogs/nginx/caiku.yqb.com.access.log main;
        error_log /wls/applogs/nginx/caiku.yqb.com.error.log warn;
    }


    server {
        listen      80 ;
        server_name  caiku.yqb.com;

        location / {
            proxy_pass http://fcsmbiz-http;
        }
        access_log /wls/applogs/nginx/caiku.yqb.com.access.log main;
        error_log /wls/applogs/nginx/caiku.yqb.com.error.log warn;
    }
}
```

go解析配置文件为json

```
package main

import (
  "encoding/json"
  "fmt"
  "os"

  "github.com/aluttik/go-crossplane"
)

func main() {
  payload, err := crossplane.Parse(path, &crossplane.ParseOptions{})
  if err != nil {
    panic(err)
  }

  b, err := json.Marshal(payload)
  if err != nil {
    panic(err)
  }

  fmt.Println(string(b))
}
```

### json解析并生成配置文件

json数据

```
{
    "config": [
        {
            "file": "yqb222.com.conf",
            "parsed": [
                {
                    "directive": "server",
                    "line": 2,
                    "args": [],
                    "block": [
                        {
                            "directive": "listen",
                            "line": 3,
                            "args": [
                                "443",
                                "ssl"
                            ]
                        },
                        {
                            "directive": "server_name",
                            "line": 4,
                            "args": [
                                "caiku.yqb.com"
                            ]
                        },
                        {
                            "directive": "location",
                            "line": 6,
                            "args": [
                                "/"
                            ],
                            "block": [
                                {
                                    "directive": "proxy_pass",
                                    "line": 7,
                                    "args": [
                                        "http://fcsmbiz-http"
                                    ]
                                }
                            ]
                        },
                        {
                            "directive": "access_log",
                            "line": 10,
                            "args": [
                                "/wls/applogs/nginx/caiku.yqb.com.access.log",
                                "main"
                            ]
                        },
                        {
                            "directive": "error_log",
                            "line": 11,
                            "args": [
                                "/wls/applogs/nginx/caiku.yqb.com.error.log",
                                "warn"
                            ]
                        }
                    ]
                }
            ]
        }
    ]
}
```

go解析json数据为nginx配置

```
package main

import (
  "bytes"
  "encoding/json"
  "fmt"
  "io/ioutil"
  "os"

  "github.com/aluttik/go-crossplane"
)

func main() {
  file, err := os.Open(path)
  if err != nil {
    panic(err)
  }

  content, err := ioutil.ReadAll(file)
  if err != nil {
    panic(err)
  }

  var payload crossplane.Payload
  if err = json.Unmarshal(content, &payload); err != nil {
    panic(err)
  }

  var buf bytes.Buffer
  if err = crossplane.Build(&buf, payload.Config[0], &crossplane.BuildOptions{}); err != nil {
    panic(err)
  }

  fmt.Println(buf.String())
}
```

**output**

```
server {
    listen 443 ssl;
    server_name caiku.yqb.com;
    location / {
        proxy_pass http://fcsmbiz-http;
    }
    access_log /wls/applogs/nginx/caiku.yqb.com.access.log main;
    error_log /wls/applogs/nginx/caiku.yqb.com.error.log warn;
}
```