---
title: Ansible批量管理配置文件
date: 2021-04-06T11:14:42+00:00
categories: ['运维工具']
tags: ["Ansible"]
---
配置管理对应用集群的重要性不言而喻。

配置分为两种，一种是存储在配置中心，比如key-value结构的etcd等配置中心，一种是需要持久化到应用服务器本地的配置文件。

如何修改，管理配置文件并保证修改后可以正常同步到对应应用集群的所有主机，是值得思考的。

在我来之前，公司内部一直使用puppet管理，运维体验非常糟糕，主要以下几点：

1. 每台被管理主机需要安装puppet agent，需要保证agent进程健康
2. 服务端管理复杂，有ca，master，git等多台服务器，不知所云
3. 每个应用集群agent执行是独立的，会导致某个时间点上去发现有些同步了，有些没同步
4. agent与server通信需要ca证书，经常出现ca证书有问题，需要重新初始化

要解决以上问题，ansible的[synchronize_module](https://docs.ansible.com/ansible/latest/collections/ansible/posix/synchronize_module.html)可以完美替代puppet。

synchronize模块是rsync的高度封装，比copy模块速度快很多。它在传输文件前会比较文件信息，如果src的文件与dest的文件是一致的，则不会传输，非常适合大规模集群管理。

安装ansible

```
yum install -y ansible
```

安装synchronize模块

```
ansible-galaxy collection install ansible.posix
```

被管理主机需要安装rsync

```
yum install -y rsync
```

使用此模块非常简单

hosts

```
[app1_uat]
10.0.0.11
[app1_hd]
10.0.0.12
[app1_prd_bx]
10.0.0.13
[app1_prd_wgq]
10.0.0.14
```

main.yaml

```
- name: app1_uat
  hosts: app1_uat
  tasks:
  - name: Synchronization of envconfig
    ansible.posix.synchronize:
      src: /opt/uat/app1/envconfig
      dest: /opt
  - name: Synchronization of env.sh
    ansible.posix.synchronize:
      src: /opt/uat/app1/env.sh
      dest: /opt
- name: app1_hd
  hosts: app1_hd
  tasks:
  - name: Synchronization of envconfig
    ansible.posix.synchronize:
      src: /opt/uat/app1/envconfig
      dest: /opt
  - name: Synchronization of env.sh
    ansible.posix.synchronize:
      src: /opt/uat/app1/env.sh
      dest: /opt
...
```

执行playbook

```
ansible-playbook main.yaml
```

一些有用的配置(/etc/ansible/ansible.cfg)

```
timeout = 3 #ssh 超时时间
forks = 20 #并发数量，默认为5
log_path = /var/log/ansible.log #记录日志，默认不记录
```

生产环境机器很多，要测试执行完一次playbook耗费时间
