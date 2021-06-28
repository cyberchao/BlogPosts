---
title: nginx热升级
date: 2021-04-02T11:14:42+00:00
categories: ['nginx']
tags: ["nginx"]
---

> nginx热升级是生产环境中常见的需求，在升级nginx版本的同时还要保证不能中断服务，搭配信号，nginx可以实现热升级。(本文的nginx都是编译安装)

**第一步，生成新版本的nginx二进制文件**

新的编译过程中prefix等目录和权限信息要与之前一致，编译完成后只执行make不要执行make install，这样就不会把原来的nginx目录替换掉，只会在objs目录下生成新的nginx二进制文件，然后替换掉旧的sbin/nginx即可。(注意备份nginx目录和旧可执行文件，回滚比升级更重要！)

**第二部，向老 master 进程发送 USR2 信号**

发送 USR2 信号以后，现有 master 进程会做以下几件事情：修改 pid 文件名为pid.oldbin。使用新的二进制文件启动新的 master 进程，所以到此为止，会出现两个 master 进程和老的 worker 进程

```
[root@pafm-fs001 sbin]# kill -USR2 28463
[root@pafm-fs001 sbin]# ps -ef |grep nginx
root 12679 28463 0 19:05 ? 00:00:00 nginx: master process ./nginx
wls81 12680 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12681 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12682 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12683 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12684 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12685 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12686 12679 1 19:05 ? 00:00:00 nginx: worker process
wls81 12687 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12688 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12689 12679 0 19:05 ? 00:00:00 nginx: worker process
root 12695 24492 0 19:05 pts/0 00:00:00 grep nginx
root 28463 1 0 18:50 ? 00:00:00 nginx: master process ./nginx
wls81 28464 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28465 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28466 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28467 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28468 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28469 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28470 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28471 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28472 28463 0 18:50 ? 00:00:00 nginx: worker process
wls81 28473 28463 0 18:50 ? 00:00:00 nginx: worker process
```

老 master 进程是一直保存下来的，这是为了方便我们进行回滚，也就是发现新的 Nginx 程序有问题了，这个时候因为老的 master 进程还在，可以向老的 master 进程发送 HUP 信号，相当于执行了一次 reload，会启动新的 worker 进程，然后再向新 master 进程发送 QUIT 信号，也就是要求新的 worker 进程优雅退出，就实现了回滚。

**第三步，向老 master 进程发送 WINCH 信号**

```
[root@pafm-fs001 sbin]# kill -WINCH 28463
[root@pafm-fs001 sbin]# ps -ef |grep nginx
root 12679 28463 0 19:05 ? 00:00:00 nginx: master process ./nginx
wls81 12680 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12681 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12682 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12683 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12684 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12685 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12686 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12687 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12688 12679 0 19:05 ? 00:00:00 nginx: worker process
wls81 12689 12679 0 19:05 ? 00:00:00 nginx: worker process
root 12723 24492 0 19:05 pts/0 00:00:00 grep nginx
root 28463 1 0 18:50 ? 00:00:00 nginx: master process ./nginx
wls81 28464 28463 0 18:50 ? 00:00:00 nginx: worker process is shutting down
```

优雅关闭所有worker进程，旧的master进程13195还在，只是没有worker进程，如果要回退，只需要拉回旧的worker进程。

**第四步，通过QUIT 彻底关闭老进程**

```
[root@pafm-fs001 sbin]# kill -QUIT 28463
```

**回滚**

执行第三步后，如果观察有问题，可以直接发送HUP信号让老master重新把worker拉起来，并把新master关闭掉

```
[root@pafm-fs001 sbin]# kill -HUP 28463
[root@pafm-fs001 sbin]# kill -QUIT 12679
```

**信号管理**

Nginx是一个多进程应用，一般多进程通信可以采用共享内存、信号等通信方式。nginx的主进程和worker进程之间使用信号通信。开发者也会通过主动发送信号，控制nginx的行为

![img](https://img-blog.csdnimg.cn/20190929003242187.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2dleGlhb3lpemhpbWVp,size_16,color_FFFFFF,t_70) 其中发送信号的方式有两种

1.通过 kill -HUP 12392这种方式直接向进程发送信号。

2.通过nginx命令行方式：nginx -s reload

第2种实际上就是利用logs目录下的nginx.pid读取进程id然后发送对于的信号，本质一样。

上面红色标识的信号只能通过kill -命令直接发送给对应进程。而没有对应的nginx命令。

信号作用介绍

- CHLD：当worker进程出现异常关闭时，会给master进程发送该信号，master进程收到信号会重启worker进程
- TERM, INT: 这两个信号都是立即停止服务，而不会等待已连接的tcp处理完请求
- QUIT: 优雅的停止服务，不会立刻断开用户的tcp连接
- HUP: 重载配置文件
- USR1: 重新打开日志文件，可以做日志文件的切割
- USR2: 启动新的master主进程
- WINCH: 让master进程优雅的关闭所有的worker进程。

```
location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|js|css)?$ {
expires 7d;
}
location ~ .*\.(html|htm|json|xhtml|shtml)?$ {
expires 300s;
}
```