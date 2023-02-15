## replica set
通过控制器来控制副本的数量.

### 伸缩副本集
```bash
kubectl scale deployment nginx-deployment --replicas=4
```

### 回滚及更新
#### 更新
```bash
# 打开记录
kubectl create -f nginx-deployment.yaml --record
# 实时查看过程
kubectl rollout status deployment/nginx-deployment
# 在任何时间窗口内，只有指定比例的pod处于处于离线状态 和 新Pod被创建出来
# 这两个比例的值都是可以配置的，默认都是 DESIRED 值的 25%。
# 策略如何配置如下 
spec:...
  strategy: 
    type: RollingUpdate 
    rollingUpdate: 
       maxSurge: 1 
       maxUnavailable: 1
```

#### 回滚
```bash
# 查看历史
kubectl rollout history deployment/nginx-deployment
# 查看要回滚的版本细节
kubectl rollout history deployment/nginx-deployment --revision=2
# 执行回滚操作
kubectl rollout history deployment/nginx-deployment --to-revision=2
```

#### 注意
Deployment对象有一个字段，叫作 spec.revisionHistoryLimit
就是 Kubernetes 为 Deployment 保留的“历史版本”个数。所以，如果把它设置为 0不能再做回滚操作了
滚动更新缺点: 长连接的服务更新

## 有状态应用 StatefulSet
StatefulSet 其实就是一种特殊的 Deployment，而其独特之处在于，它的每个 Pod 都被编号了。
### 拓扑状态
headless service
每一个Pod名称是没有顺序的，是随机字符串，因此是Pod名称是无序的，但是在statefulset中要求必须是有序 ，每一个pod不能被随意取代，pod重建后pod名称还是一样的。而pod IP是变化的，所以是以Pod名称来识别。pod名称是pod唯一性的标识符，必须持久稳定有效。这时候要用到无头服务，它可以给每个Pod一个唯一的名称

### 存储状态
volumeClaimTemplate
为每个Pod生成不同的pvc，并绑定pv，从而实现各pod有专用存储

### 实践 mysql集群
- 是一个“主从复制”（Maser-Slave Replication）的 MySQL 集群
- 有 1 个主节点（Master）
- 有多个从节点（Slave）
- 从节点需要能水平扩展 
- 所有的写操作，只能在主节点上执行 
- 读操作可以在所有节点上执行

too hard!

## DaemonSet
- 这个 Pod 运行在 Kubernetes 集群里的每一个节点（Node）上 
- 每个节点上只有一个这样的 Pod 实例
- 当有新的节点加入 Kubernetes 集群后，该 Pod 会自动地在新节点上被创建出来
- 而当旧节点被删除后，它上面的 Pod 也相应地会被回收掉

### 如何在master节点部署
Kubernetes 集群不允许用户在 Master 节点部署 Pod。
因为，Master 节点默认携带了一个叫作node-role.kubernetes.io/master的“污点”。
所以，为了能在 Master 节点上部署 DaemonSet 的 Pod，我就必须让这个 Pod“容忍”这个“污点”。



### 总结

- 为什么要设计两层控制, 通过deployment控制replica set(版本)再控制pod?
- StatefulSet主要用于什么服务部署
- DaemonSet是什么，应用


