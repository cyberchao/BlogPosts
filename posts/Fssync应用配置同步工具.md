---
title: Fssync应用配置同步工具
date: 2021-08-13T23:41:42+00:00
categories: ["Go"]
tags: ["rsync","git"]
---

公司目前一直使用puppet管理应用配置文件，运维体验非常糟糕，主要以下几点：

1. 每台被管理服务器需要安装puppet agent，需要保证agent进程存活
2. 服务端管理复杂，有ca，master，git等N个节点
3. 每个服务器上的agent执行是独立的，会导致某个时间点上去发现有些配置同步了，有些没同步
4. agent与server通信需要ca证书，经常出现ca证书有问题，需要重新初始化

考虑替换为ansible时，发现ansible的配置文件维护也没有很简单，而且要增加playbook的学习成本。于是，考虑自己写一个配置同步工具，要求架构极简，速度极快，使用起来也人性化。



![fssync 1.jpg](https://camo.githubusercontent.com/ed1d85229f0bf67121c22e4d41a7134839f9b82a9367d20c96f564aaf6c846a3/68747470733a2f2f692e6c6f6c692e6e65742f323032312f30382f31352f7961653970384f596f69727a5843732e6a7067)

程序结构如上图：

1. 操作者在本地git库修改文件后，push到远端gitlab server
2. fssync执行一个定时任务，没隔固定时间在它本机git仓库执行拉取
3. 如果拉取发现有文件变更，即开始分析文件所属模块，环境，应用等信息
4. 根据所得信息向cmdb发起查询请求，cmdb返回服务器ip列表
5. fssync以这些服务器ip作为目的端执行rsync操作
6. 同步完成，等待下一次轮询

如果远端应用有扩容或特殊情况文件不一致，依靠定时任务是不会触发同步任务的，需要手动触发，可以对外暴露一个http api，根据客户端请求参数执行同步任务。

项目地址：https://github.com/cyberchao/fssync

缺陷：git无法跟踪文件属主信息

**一些代码**

GetDiffFile

```go
func GetDiffFile() ([]string, error) {
	os.Chdir(config.Config.RepoDir)
	cmd := exec.Command("git", "pull", "origin", "main")
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	err := cmd.Run()

	if err != nil {
		config.Logger.Errorf("git pull error:%s:%s", err, stderr.String())
		return nil, err
	} else {
		config.Logger.Info("git pull: " + strings.Trim(out.String(), "\n"))
		// 判断是否有更新
		if !strings.Contains(out.String(), "Already up to date") {
			// git log -p -1 --oneline 获取最近一次更新的详细内容变化
			out, _ := exec.Command("git", "diff", "head^", "--name-only").Output()
			files := strings.Split(strings.Trim(string(out), "\n"), "\n")
			return files, nil
		} else {
			config.Logger.Infof("No diff file")
			return nil, nil
		}
	}
}
```

Worker

```go
func Worker() {
	var src []string
	diffFiles, err := util.GetDiffFile()
	if err != nil {
		config.Logger.Error("Get diff file error:", err.Error())
	} else if diffFiles != nil {
		config.Logger.Info("get files:", diffFiles)
	}
	// 按文件路径信息执行同步
	for _, file := range diffFiles {
		config.Logger.Infof("Start sync file:%s", file)
		dirs := strings.Split(file, "/")
		if len(dirs) > 3 {
			mod, env, appName := dirs[0], dirs[1], dirs[2]
			srcPath := fmt.Sprintf("%s/%s/%s/%s/", config.Config.RepoDir, mod, env, appName)

			if !util.Contains(&src, &srcPath) {
				src = append(src, srcPath)
				ipList, err := util.Getip(&env, &appName)
				if err != nil {
					config.Logger.Error("Get ip error:", err.Error())
					return
				}
				config.Logger.Infof("[Sync info]src:%s;mod:%s;env:%s;app:%s;iplist:%s", srcPath, mod, env, appName, ipList)
				for _, ip := range ipList {
					go core.SyncCron(&srcPath, &ip)
				}
			}
		}
	}
}
```

Sync

```go
func SyncCron(srcPath, ip *string) {
	err := exec.Command("/usr/bin/rsync", "-avz", "--timeout="+config.Config.Timeout, "--owner="+config.Config.Owner, "--group="+config.Config.Group, *srcPath, *ip+":/").Run()
	if err != nil {
		config.Logger.Errorf("Rsync error:[%s]-[%s]-[%s]", *srcPath, *ip, err.Error())
	} else {
		config.Logger.Infof("Rsync success:rsync -az %s* %s:/", *srcPath, *ip)
	}
}

func SyncHttp(srcPath, ip *string, ch chan string) {
	out, err := exec.Command("/usr/bin/rsync", "-avz", "--timeout="+config.Config.Timeout, "--owner="+config.Config.Owner, "--group="+config.Config.Group, *srcPath, *ip+":/").Output()
	if err != nil {
		config.Logger.Errorf("Rsync error:[%s]-[%s]-[%s]", *srcPath, *ip, err.Error())
		ch <- *ip + ":" + string(out)
	} else {
		config.Logger.Infof("Rsync success:rsync -az %s* %s:/", *srcPath, *ip)
		ch <- *ip + ":success"
	}
}
```

Http API

```go
func SyncFunc(c *gin.Context) {
	env := c.DefaultQuery("env", "all")
	appName := c.Query("app")
	mod := c.Query("mod")
	ipList, err := util.Getip(&env, &appName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"msg": "get ip from cmdb failed:" + err.Error()})
	}
	srcPath := fmt.Sprintf("%s/%s/%s/%s/", config.Config.RepoDir, mod, env, appName)
	config.Logger.Infof("[Sync info]mod:%s;env:%s;app:%s;iplist:%s", mod, env, appName, ipList)

	ch := make(chan string, len(ipList))
	for _, ip := range ipList {
		go core.SyncHttp(&srcPath, &ip, ch)
	}
	var resp []string
	for i := 0; i < len(ipList); i++ {
		r := <-ch
		resp = append(resp, r)
	}
	c.IndentedJSON(http.StatusOK, resp)
}
```



