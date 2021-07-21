---
title: concurrent.futures控制并发
date: 2021-07-21T21:42:42+00:00
categories: ['Python']
tags: ["python","并发"]
---

### concurrent.futures是什么？

concurrent.futures模块提供给开发者一个执行异步调用的高级接口。concurrent.futures基本上就是在Python的threading和multiprocessing模块之上构建的抽象层，更易于使用。

concurrent.futures包括抽象类Executor，它并不能直接被使用，所以你需要使用它的两个子类：ThreadPoolExecutor或者ProcessPoolExecutor。

线程池或进程池是用于在程序中优化和简化线程/进程的使用。通过池，你可以提交任务给executor。池由两部分组成，一部分是内部的队列，存放着待执行的任务；另一部分是一系列的进程或线程，用于执行这些任务。池的概念主要目的是为了重用：让线程或进程在生命周期内可以多次使用。它减少了创建创建线程和进程的开销，提高了程序性能。重用不是必须的规则，但它是程序员在应用中使用池的主要原因。 

![../_images/pooling-management.png](https://python-parallel-programmning-cookbook.readthedocs.io/zh_CN/latest/_images/pooling-management.png) 

### 使用进程池还是线程池？

这有一个例子

```python
import concurrent.futures
import time
number_list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

def evaluate_item(x):
        # 计算总和，这里只是为了消耗时间
        result_item = count(x)
        # 打印输入和输出结果
        return result_item

def  count(number) :
        for i in range(0, 10000000):
                i=i+1
        return i * number

if __name__ == "__main__":
        # 顺序执行
        start_time = time.time()
        for item in number_list:
                print(evaluate_item(item))
        print("Sequential execution in " + str(time.time() - start_time), "seconds")
        # 线程池执行
        start_time_1 = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = [executor.submit(evaluate_item, item) for item in number_list]
                for future in concurrent.futures.as_completed(futures):
                        print(future.result())
        print ("Thread pool execution in " + str(time.time() - start_time_1), "seconds")
        # 进程池
        start_time_2 = time.time()
        with concurrent.futures.ProcessPoolExecutor(max_workers=5) as executor:
                futures = [executor.submit(evaluate_item, item) for item in number_list]
                for future in concurrent.futures.as_completed(futures):
                        print(future.result())
        print ("Process pool execution in " + str(time.time() - start_time_2), "seconds")
        
output---
10000000
20000000
30000000
40000000
50000000
60000000
70000000
80000000
90000000
100000000
Sequential execution in 4.697415590286255 seconds
10000000
30000000
40000000
50000000
20000000
60000000
70000000
80000000
90000000
100000000
Thread pool execution in 4.338747262954712 seconds
10000000
20000000
40000000
50000000
30000000
60000000
80000000
90000000
70000000
100000000
Process pool execution in 1.3198800086975098 seconds
```

可以看到使用线程池的速度和普通轮询结果没什么区别，进程池就快了很多。因为python GIL的存在，多线程其实是伪并发，其实自始至终都只有一个线程再执行，所以以上这个计算密集型的例子使用线程不会有速度提升。但是io密集型的任务由于网络延迟，磁盘io等需要等待的原因，使用多线程会更好。

由于工作性质，绝大多数情况下是与操作系统io打交道，这里就简单介绍下ThreadPoolExecutor的使用方法，ProcessPoolExecutor同理。

### 1.使用ThreadPoolExecutor

`submit()`

调度可调用对象 *fn*，以 `fn(*args **kwargs)` 方式执行并返回 [`Future`](https://docs.python.org/zh-cn/3/library/concurrent.futures.html#concurrent.futures.Future) 对象代表可调用对象的执行。:

```python
from concurrent import futures
from concurrent.futures import thread
import time


def woker(n):
    time.sleep(3)
    return n*10

threadpool = futures.ThreadPoolExecutor(max_workers=5)
start = time.time()
for i in range(5):
    threadpool.submit(woker, i)
    
end = time.time()
print(end-start)

output---
0.001994609832763672
```

运行发现，线程任务还没有执行完成，就随着主进程的退出结束任务了

### 2.等待future 对象执行完成

`shutdown()`

当待执行的 future 对象完成执行后向执行者发送信号，它就会释放正在使用的任何资源。

```python
from concurrent import futures
from concurrent.futures import thread
import time


def woker(n):
    time.sleep(3)
    return n*10

threadpool = futures.ThreadPoolExecutor(max_workers=5)
start = time.time()
for i in range(5):
    threadpool.submit(woker, i)
    
threadpool.shutdown()
end = time.time()
print(end-start)

output---
3.008821487426758
```

如果使用 [`with`](https://docs.python.org/zh-cn/3/reference/compound_stmts.html#with) 语句，你就可以避免显式调用这个方法 

```python
from concurrent import futures
from concurrent.futures import thread
import time


def woker(n):
    time.sleep(3)
    return n*10
start = time.time()
with futures.ThreadPoolExecutor(max_workers=5) as threadpool:
    for i in range(5):
        threadpool.submit(woker, i)
end = time.time()
print(end-start)

output---
3.010192632675171
```

现在我们的所有线程任务都可以健康的执行，那么，如何获取任务的返回结果呢？

### 3.获取返回结果

`result(*timeout=None*)`

返回调用返回的值。如果调用还没完成那么这个方法将等待 *timeout* 秒。

```python
from concurrent import futures
from concurrent.futures import thread
import time


def woker(n):
    time.sleep(3)
    return n*10

threadpool = futures.ThreadPoolExecutor(max_workers=5)
start = time.time()
threadlist = {threadpool.submit(woker, i): i for i in range(5)}
    
for thread in threadlist:
    print(thread.result())
end = time.time()
print(end-start)

output---
0
10
20
30
40
3.005878448486328
```

现在我们可以获取到任务的返回结果了，注意这里的返回结果顺序是根据任务的调度顺序获取的(result方法是阻塞的，会等待获取到某个任务的结果采取获取下一个)。

那如果我们的任务内如果有报错，会怎么样呢？把*10换成+‘10’，再执行看看

```python
...
def woker(n):
    time.sleep(3)
    return n+'10'
...

output---
Traceback (most recent call last):
  File "c:\Users\pangr\Desktop\pycode\future\run.py", line 15, in <module>
    print(thread.result())
  File "C:\Users\pangr\AppData\Local\Programs\Python\Python37\lib\concurrent\futures\_base.py", line 435, in result
    return self.__get_result()
  File "C:\Users\pangr\AppData\Local\Programs\Python\Python37\lib\concurrent\futures\_base.py", line 384, in __get_result
    raise self._exception
  File "C:\Users\pangr\AppData\Local\Programs\Python\Python37\lib\concurrent\futures\thread.py", line 57, in run
    result = self.fn(*self.args, **self.kwargs)
  File "c:\Users\pangr\Desktop\pycode\future\run.py", line 8, in woker
    return n+'10'
TypeError: unsupported operand type(s) for +: 'int' and 'str'
```

主进程捕获到异常，直接退出了。
但如果有些异常是可接受的，也就是说就算某些异常出现了，捕获到这些异常后但是不能影响到其他任务的执行，要如何实现呢。

### 4.捕获异常

`exception(*timeout=None*) `

返回由调用引发的异常。 如果调用还没完成那么这个方法将等待 timeout 秒

```python
from concurrent import futures
from concurrent.futures import thread
import time


def woker(n):
    time.sleep(3)
    return n+'10'

start = time.time()
with futures.ThreadPoolExecutor(max_workers=5) as threadpool:
    for i in range(5):
        future = threadpool.submit(woker, i)
        print(future.exception())

end = time.time()
print(end-start)

output---
unsupported operand type(s) for +: 'int' and 'str'
unsupported operand type(s) for +: 'int' and 'str'
unsupported operand type(s) for +: 'int' and 'str'
unsupported operand type(s) for +: 'int' and 'str'
unsupported operand type(s) for +: 'int' and 'str'
15.044514894485474
```

虽然可以打印出所有任务的异常了，但是程序执行了15秒。因为exception()是阻塞的。若想以非阻塞的形式捕获 ，可以使用回调函数

`add_done_callback`(*fn*)

​	附加可调用 fn 到 future 对象。当 future 对象被取消或完成运行时，将会调用 fn，而这个 future 对象将作为它唯一的参数。

```python
from concurrent import futures
from concurrent.futures import thread
import time


def woker(n):
    time.sleep(3)
    if n == 2:
        return n+'10'
    else:
        return n*10

def exception_callback(future):
    if future.exception() != None: #若线程正常退出，打印结果
        print(future.exception())
    else:
        print(future.result())

start = time.time()
with futures.ThreadPoolExecutor(max_workers=5) as threadpool:
    for i in range(5):
        future = threadpool.submit(woker, i)
        future.add_done_callback(exception_callback)
        
end = time.time()
print(end-start)

output---
40
30
10
unsupported operand type(s) for +: 'int' and 'str'
0

3.0159034729003906
```



