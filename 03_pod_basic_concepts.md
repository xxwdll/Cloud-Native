### pod和容器的关系
pod是共享了资源(存储、网络)的一组容器;
k8s pod比docker的容器组更加灵活, pod有一个中间容器 第一个被创建,Infra
#### Infra
通过中间容器 用户容器可以
- 共享网络
- 拥有相同的网络设备
- 共享同一podip
同时Pod 中的容器不会被分配到不同节点中，它们一定被部署到同一个节点中, pod中如果定义了volume
同一pod中的不同容器用这个volume一定也是共享的

### 部署技巧
#### sidecar
sidecar意思就是再主容器外再起一个辅助容器做一些额外操作
部署javaweb程序, 解耦war包和组件成两个镜像
initContainers是最先开始运行的 因此会先拷贝文件到/app目录
- 注 以下旁路镜像不可用 可以用busybox，alpine做旁路镜像
```

apiVersion: v1
kind: Pod
metadata:
  name: javaweb-2
spec:
  initContainers:
  - image: geektime/sample:v2
    name: war
    command: ["cp", "/sample.war", "/app"]
    volumeMounts:
    - mountPath: /app
      name: app-volume
  containers:
  - image: geektime/tomcat:7.0
    name: tomcat
    command: ["sh","-c","/root/apache-tomcat-7.0.42-v2/bin/start.sh"]
    volumeMounts:
    - mountPath: /root/apache-tomcat-7.0.42-v2/webapps
      name: app-volume
    ports:
    - containerPort: 8080
      hostPort: 8001 
  volumes:
  - name: app-volume
    emptyDir: {}
```

收集日志 也是通过共享目录 另一个容器收集日志


### 常用字段含义
- NodeSelector 调度到打上标签的节点
- NodeName 直接指定node 测试中常用
- Lifecycle 类似于钩子 在某个容器的启动(postStart)和结束(preStop)可以定义操作
```bash

apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-demo
spec:
  containers:
  - name: lifecycle-demo-container
    image: nginx
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo Hello from the postStart handler > /usr/share/message"]
      preStop:
        exec:
          command: ["/usr/sbin/nginx","-s","quit"]
```

### 三种信息
Secret、ConfigMap，以及 Downward API 通过挂载的方式支持动态更新 通过环境变量读取方便但是不支持动态更新
- Secret
user和pass需要经过base64转码
```bash

apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  user: YWRtaW4=
  pass: MWYyZDFlMmU2N2Rm
```

- ConfigMap
和Secret区别是不需要存加密的信息 可以存应用的配置信息

- Downward API
可以获取 Pod API 对象本身的信息。

### 探针
#### livenessProbe
```bash

apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: test-liveness-exec
spec:
  containers:
  - name: liveness
    image: busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```
在容器启动 5 s 后开始执行（initialDelaySeconds: 5），每 5 s 执行一次（periodSeconds: 5）。
但是实际在检查时pod一直是running的 因为restartPolicy=Always k8s的重启机制; restartPolicy=Never 观察后会变成failed
也可探测端口
```bash

    ...
    livenessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 20
```

#### readinessProbe
虽然它的用法与 livenessProbe 类似，但作用却大不一样。
readinessProbe 检查结果的成功与否，决定的这个 Pod 是不是能被通过 Service 的方式访问到，而并不影响 Pod 的生命周期



### 总结

pod的概念, pod和容器的关系, Infra、sidecar是什么
pod的字段含义, NodeSelector, NodeName, Lifecycle
pod获取信息的几种方式, Secret、ConfigMap，以及 Downward API, 获取这些信息一般的作用, 挂载和环境变量方式读取这些信息的区别
两种探针livenessProbe和readinessProbe