### 说明
静态管理pv、pvc的方式太过于繁琐

Kubernetes 为我们提供了一套可以自动创建 PV 的机制，即：Dynamic Provisioning

传统是运维先创建pv 之后再创建pvc

使用storageclass定义了一个池子 创建pvc的时候会自动创建pv

#### 创建StorageClass
```bash
apiVersion: ceph.rook.io/v1beta1
kind: Pool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  replicated:
    size: 3
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: block-service
provisioner: ceph.rook.io/block
parameters:
  pool: replicapool
  #The value of "clusterNamespace" MUST be the same as the one in which your rook cluster exist
  clusterNamespace: rook-ceph
```

#### 使用
pvc里指定
```bash

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim1
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: block-service
  resources:
    requests:
      storage: 30Gi
```

PVC 描述的，是 Pod 想要使用的持久化存储的属性，比如存储的大小、读写权限等。
PV 描述的，则是一个具体的 Volume 的属性，比如 Volume 的类型、挂载目录、远程存储服务器地址等。
而 StorageClass 的作用，则是充当 PV 的模板。并且，只有同属于一个 StorageClass 的 PV 和 PVC，才可以绑定在一起。

### 高性能ssd pv的设计

一个pv一块盘 不可以使用根目录
需要给pv打上亲和度nodeAffinity 这样pod才能调度到这个本地盘的节点上来

本地盘必须要建pv 这一步无法省略

pv的绑定需要延迟到调度的时候StorageClass里的volumeBindingMode=WaitForFirstConsumer 否则的绑定优先级更高可能会调度到不允许的节点上