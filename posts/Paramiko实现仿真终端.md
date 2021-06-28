---
title: Paramiko实现仿真终端
date: 2021-04-18T11:14:42+00:00
categories: ['Python']
tags: ["python","paramiko"]
---

paramiko模块非常强大，使用它不仅可以实现运维自动化，还可以实现类似xshell的交互式终端，可以在某些复杂的情境下实现跳板机的功能，实现快捷登录和审计等功能。

现在我们生产环境中登录k8s的pod过程相当繁琐，要先查找应用对应的k8s集群，登录对应kube-master，之后查找应用下有哪些pod，然后根据podname用kube exec命令才登录到pod。利用paramiko可以实现一键登录。

**linux平台**

```
import paramiko
import os
import select
import sys
import tty
import termios

host = '1.1.1.1'
username = 'root'
password = 'password'
trans = paramiko.Transport((host, 22))
trans.start_client()
trans.auth_password(username=username, password=password)
channel = trans.open_session()
channel.get_pty()
channel.invoke_shell()

oldtty = termios.tcgetattr(sys.stdin)
try:
    # 支持tab
    tty.setraw(sys.stdin)
    channel.settimeout(0)

    while True:
        readlist, writelist, errlist = select.select(
            [channel, sys.stdin, ], [], [])
        if sys.stdin in readlist:
            input_cmd = sys.stdin.read(1)
            channel.sendall(input_cmd)
        if channel in readlist:
            result = channel.recv(1024)
            if len(result) == 0:
                print("\r\n**** EOF **** \r\n")
                break
            sys.stdout.write(result.decode())
            sys.stdout.flush()
finally:
    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, oldtty)

channel.close()
trans.close()
```

![img](http://45.63.114.236/wp-content/uploads/2021/05/%E5%8A%A8%E7%94%BB.gif)

**windows平台**

```
import paramiko
import sys

host = '1.1.1.1'
username = 'root'
password = 'password'
trans = paramiko.Transport((host, 22))
trans.start_client()
trans.auth_password(username=username, password=password)
channel = trans.open_session()
channel.get_pty()
channel.invoke_shell()


def windows_shell(chan):
    import threading

    def writeall(sock):
        while True:
            data = sock.recv(256)
            if not data:
                sys.stdout.write('\r\n*** EOF ***\r\n\r\n')
                sys.stdout.flush()
                break
            sys.stdout.write(data.decode())
            sys.stdout.flush()

    writer = threading.Thread(target=writeall, args=(chan,))
    writer.start()

    try:
        while True:
            d = sys.stdin.read(1)
            if not d:
                break
            chan.send(d)
    except OSError:
        channel.close()
        trans.close()


if __name__ == '__main__':
    windows_shell(channel)
```