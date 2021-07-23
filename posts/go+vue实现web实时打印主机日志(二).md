---
title: go+vue实现web实时打印主机日志(二)
categories: ['Go']
tags: ["go","websocket"]
---

上篇通过ssh包实现了多台主机的remote-tail，接下来利用vue,gin,websocket实现日志实时打印到web前端

参考文档：https://programmer.group/golang-gin-framework-with-websocket.html

### 后端

ws.go

```go
package v1

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"slb-admin/global"
	"slb-admin/model"
	"slb-admin/service"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"golang.org/x/crypto/ssh"
)

type Message struct {
	Host    string
	Content string
}
type Server struct {
	Hostname string
	File     string
	Stdout   io.Reader
}

type readJson struct {
	Type      string `json:"type"`
	Key       string `json:"key"`
	Env       string `json:"env"`
	Cluster   string `json:"cluster"`
	AccessLog string `json:"access_log"`
	ErrorLog  string `json:"error_log"`
}

// Execute the remote command
func (server *Server) Execute(output chan Message) {

	user := global.CONFIG.Ssh.User
	port := global.CONFIG.Ssh.Port
	keypath := global.CONFIG.Ssh.KeyPath
	client, _ := service.NewSshClient(
		user,
		server.Hostname,
		port,
		keypath)
	session := client.SshSession()
	TerminalModes := ssh.TerminalModes{
		ssh.ECHO:          0,
		ssh.TTY_OP_ISPEED: 14400,
		ssh.TTY_OP_OSPEED: 14400,
	}

	session.RequestPty("xterm", 80, 40, TerminalModes)
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
		global.Logger.Info("read message", line)
		output <- Message{
			Host:    host,
			Content: line,
		}
	}
}

var upGrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func RemoteTail(c *gin.Context) {
	//Upgrade get request to webSocket protocol
	ws, err := upGrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		global.Logger.Errorf("error get connection ", err.Error())
	}
	defer ws.Close()

	var readJson readJson
	ws.ReadJSON(&readJson)
	readString, _ := json.Marshal(&readJson)
	global.Logger.Info("read message", string(readString))

	if err != nil {
		global.Logger.Errorf("error read message", err.Error())
	}
	var hosts []model.Host

	// 获取域名对应的nginx主机
	global.DB.Where("cluster = ? AND env = ?", readJson.Cluster, readJson.Env).Find(&hosts)
	var serverList []Server
	for _, v := range hosts {
		var server Server
		server.Hostname = v.Ip
		if readJson.Type == "access" {
			server.File = readJson.AccessLog
		} else {
			server.File = readJson.ErrorLog
		}
		serverList = append(serverList, server)
	}
	fmt.Println(serverList)

	outputs := make(chan Message, 255)
	//等待goroutines执行结束 https://gobyexample.com/waitgroups
	var wg sync.WaitGroup

	for _, server := range serverList {
		wg.Add(1)
		t1, _ := json.Marshal(server)
		global.Logger.Info("start tail", string(t1))
		go func(server Server) {
			defer wg.Done()
			server.Execute(outputs)
		}(server)
	}

	go func() {
		for output := range outputs {
			writedata, _ := json.Marshal(output)
			ws.WriteMessage(1, []byte(writedata))
		}
	}()

	wg.Wait()
}
```

sshclient.go 用于生成ssh session

```go
type SshClient struct {
	Config *ssh.ClientConfig
	Server string
}

func NewSshClient(user string, host string, port int, privateKeyPath string) (*SshClient, error) {
	// read private key file
	key, err := ioutil.ReadFile(privateKeyPath)
	if err != nil {
		return nil, fmt.Errorf("Reading private key file failed %v", err)
	}
	// create signer
	signer, err := ssh.ParsePrivateKey(key)
	if err != nil {
		return nil, err
	}
	// build SSH client config
	config := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
		HostKeyCallback: func(hostname string, remote net.Addr, key ssh.PublicKey) error {
			// use OpenSSH's known_hosts file if you care about host validation
			return nil
		},
		Timeout: 3 * time.Second,
	}

	client := &SshClient{
		Config: config,
		Server: fmt.Sprintf("%v:%v", host, port),
	}
	return client, nil
}

func (s *SshClient) SshSession() *ssh.Session {

	conn, _ := ssh.Dial("tcp", s.Server, s.Config)

	session, _ := conn.NewSession()
	return session
}
```

注册ws路由

```go
func Routers() *gin.Engine {
	Router.GET("ws", v1.RemoteTail)
	return Router
}
```

### 前端

```javascript
  	data() {
    	return {
        activeRow: {},
        logInfo: {},
     	  receiveData: "",
        connection: null,
    	}
    }
    openws() {
      // 作用域问题。把this实例存为_this，回调函数里面就能访问到
      var _this = this;
      this.logInfo.env = this.activeRow.env;
      this.logInfo.cluster = this.activeRow.cluster;
      this.logInfo.access_log = this.activeRow.access_log;
      this.logInfo.error_log = this.activeRow.error_log;

      var ws = new WebSocket("ws://localhost:8080/ws");
      ws.onopen = function() {
        console.log("Successfully connected to the websocket server...");
        // 传递一些主机信息，后端数据库筛选
        ws.send(JSON.stringify(_this.logInfo));
      };
      ws.onmessage = function(event) {
        var data = JSON.parse(event.data);
        var line = data.Host + "-" + data.Content;
        _this.receiveData += line;
        // _this.receiveData.push(data);
      };
      ws.onclose = function() {
        console.log("Connection closed.");
      };
    },
```

### 效果

![Kapture 2021-07-16 at 11.24.07](/Users/pangru/Movies/Kaptures/Kapture 2021-07-16 at 11.24.07.gif)