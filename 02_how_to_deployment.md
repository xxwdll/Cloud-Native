### 部署nginx
#### 声明文件
kubectl create -f 我的配置文件

nginx-deployment.yaml
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```
以上配置代表是
- 镜像 nginx:1.7.9
- 端口 80
- 副本数 2
- 标签 app: nginx

metadata: 帮助唯一标识对象的一些数据，包括一个 name 字符串、UID 和可选的; spec内容代表的是: 你所期望的该对象的状态

#### 验证
结果如下
```bash
[root@node1 ~]# kubectl apply -f nginx-deployment.yaml
deployment.apps/nginx-deployment created
[root@node1 ~]#
[root@node1 ~]# kubectl get pods -l app=nginx
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-5d59d67564-dxkqp   1/1     Running   0          68s
nginx-deployment-5d59d67564-rqng4   1/1     Running   0          68s
[root@node1 ~]#
```

### pod里增加Volume
#### emptyDir格式
修改deployment文件 修改spec里的内容
```bash
...
...
    spec:
      containers:
      - name: nginx
        image: nginx:1.8
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: nginx-vol
      volumes:
      - name: nginx-vol
        emptyDir: {}
```
实际登录到挂载目录可知 emptyDir 文件并不是pod共享的
kubectl exec -it $pod_name -- /bin/bash
```bash
[root@node1 ~]# kubectl get pods -l app=nginx
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-5b8dcddb98-5fntd   1/1     Running   0          4m34s
nginx-deployment-5b8dcddb98-z9pqr   1/1     Running   0          4m35s
[root@node1 ~]#
[root@node1 ~]# kubectl exec -it nginx-deployment-5b8dcddb98-5fntd -- /bin/bash
root@nginx-deployment-5b8dcddb98-5fntd:/#
root@nginx-deployment-5b8dcddb98-5fntd:/# cd /usr/share/nginx/html
root@nginx-deployment-5b8dcddb98-5fntd:/usr/share/nginx/html# ls
root@nginx-deployment-5b8dcddb98-5fntd:/usr/share/nginx/html#
root@nginx-deployment-5b8dcddb98-5fntd:/usr/share/nginx/html# touch test
root@nginx-deployment-5b8dcddb98-5fntd:/usr/share/nginx/html#
root@nginx-deployment-5b8dcddb98-5fntd:/usr/share/nginx/html# ls
test
root@nginx-deployment-5b8dcddb98-5fntd:/usr/share/nginx/html# exit
[root@node1 ~]#
[root@node1 ~]#
[root@node1 ~]# kubectl exec -it nginx-deployment-5b8dcddb98-z9pqr -- /bin/bash
root@nginx-deployment-5b8dcddb98-z9pqr:/# cd /usr/share/nginx/html
root@nginx-deployment-5b8dcddb98-z9pqr:/usr/share/nginx/html# ls
root@nginx-deployment-5b8dcddb98-z9pqr:/usr/share/nginx/html#
root@nginx-deployment-5b8dcddb98-z9pqr:/usr/share/nginx/html# exit
[root@node1 ~]#
```

改格式的文件也并不是持久化的 pod如果重建 文件也会丢失

#### hostPath
```bash
 ...   
    volumes:
      - name: nginx-vol
        hostPath: 
          path:  " /var/data"
```

这个和上面的区别是持久化存储到node的节点上

测试结束 删除
```bash
[root@node1 ~]# kubectl delete -f nginx-deployment.yaml
deployment.apps "nginx-deployment" deleted
[root@node1 ~]#
[root@node1 ~]#
```

### 总结
#### 命令
- kubectl get pods -l app=nginx
- kubectl exec -it $pod_name -- /bin/bash
- kubectl apply -f $deployment_name
- kubectl describe pod $pod_name

#### 概念
spec和metadata的区别, 如何更新服务, 如何定义存储