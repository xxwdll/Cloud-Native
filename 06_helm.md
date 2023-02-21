### 概念
https://helm.sh/zh/docs/intro/using_helm/

helm3 是目前主流的Kubernetes包管理工具 类似centos中的yum

Repository（仓库）、Chart（包）、Release（版本）

### 安装

官网提供的步骤
```bash
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh
```
由于下载helm包太慢get_helm.sh我做了点修改,包的版本是helm-v3.11.1-linux-amd64.tar.gz 上传到改服务的/home目录里
```bash
# downloadFile downloads the latest binary package and also the checksum
# for that binary.
downloadFile() {
  HELM_DIST="helm-$TAG-$OS-$ARCH.tar.gz"
  DOWNLOAD_URL="https://get.helm.sh/$HELM_DIST"
  CHECKSUM_URL="$DOWNLOAD_URL.sha256"
  HELM_TMP_ROOT="$(mktemp -dt helm-installer-XXXXXX)"
  HELM_TMP_FILE="$HELM_TMP_ROOT/$HELM_DIST"
  HELM_SUM_FILE="$HELM_TMP_ROOT/$HELM_DIST.sha256"
  echo "Downloading $DOWNLOAD_URL"
  if [ "${HAS_CURL}" == "true" ]; then
    curl -SsL "$CHECKSUM_URL" -o "$HELM_SUM_FILE"
    #curl -SsL "$DOWNLOAD_URL" -o "$HELM_TMP_FILE"
    cp /home/helm-v3.11.1-linux-amd64.tar.gz $HELM_TMP_FILE
  elif [ "${HAS_WGET}" == "true" ]; then
    wget -q -O "$HELM_SUM_FILE" "$CHECKSUM_URL"
    wget -q -O "$HELM_TMP_FILE" "$DOWNLOAD_URL"
  fi
}
```

### 安装kong
官网地址 https://github.com/Kong/kubernetes-ingress-controller
```bash
$ helm repo add kong https://charts.konghq.com
$ helm repo update
$ helm install kong/kong --generate-name --set ingressController.installCRDs=false
```
### 安装psql
- nfs
```bash
yum install -y nfs-utils

echo "/data/postgresql *(insecure,rw,sync,no_root_squash)" > /etc/exports

# 执行以下命令，启动 nfs 服务;创建共享目录
mkdir -p /data/postgresql

# 在master执行
chmod -R 777 /data/postgresql

# 使配置生效
exportfs -r

#检查配置是否生效
exportfs

systemctl enable rpcbind && systemctl start rpcbind

systemctl enable nfs && systemctl start nfs
```

- storage
注 每个节点都需要安装 yum install -y nfs-utils

先安装 nfs-subdir-external-provisioner 
```bash
$ helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
$ helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=x.x.x.x \
    --set nfs.path=/exported/path \
    --set image.repository=registry.cn-hangzhou.aliyuncs.com/iuxt/nfs-subdir-external-provisioner
```

```bash

export provisioner_name=`kubectl get deployment nfs-subdir-external-provisioner -o yaml |\
  grep -A1 PROVISIONER_NAME |\
  grep value | \
  awk -F':' '{print $NF}'`

cat <<EOF > nfs-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage

provisioner: $provisioner_name
parameters:
  onDelete: "remain"
EOF

kubectl apply -f nfs-storage.yaml
```


- postgresql-storage.yaml 这里有个坑 高版本的ps数据库无法使用
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami/postgresql
cat << EOF> my-values.yaml
global:
  storageClass: nfs-storage
  postgresql:
    auth:
      postgresPassword: "ucloud.cn"
      username: "konga"
      password: "ucloud.cn"
      database: "konga"
image:
  tag: 12.14.0-debian-11-r2
EOF
helm install ps-db bitnami/postgresql \
-f my-values.yaml
```

### 安装konga
https://github.com/dangtrinhnt/konga-helm-chart
```bash
cat << EOF> konga-valus.yaml
config: {}
  port: 1337
  node_env: production
  db_adapter: postgres
  db_host: ps-db-postgresql.default.svc.cluster.local
  db_port: 5432
  db_user: konga
  db_password: ucloud.cn
  db_database: konga
EOF
helm install konga ./ -f konga-valus.yaml
```


```bash
cat << EOF> konga-deployment.yml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: konga
  namespace: kong
spec:
  replicas: 1
  selector:
    matchLabels:
      app: konga
  template:
    metadata:
      labels:
        app: konga
    spec:
      containers:
        - name: konga
          image: pantsel/konga
          env:
            - name: DB_ADAPTER
              value: 'postgres'
            - name: DB_HOST
              value: 'ps-db-postgresql.default.svc.cluster.local'
            - name: DB_PORT
              value: '5432:5432'
            - name: DB_PASSWORD
              value: 'ucloud.cn'
            - name: DB_USER
              value: 'konga'
            - name: DB_DATABASE
              value: 'konga'
          ports:
            - containerPort: 1337
              name: web
EOF

kubectl apply -f konga-deployment.yml 

cat <<EOF> svc.yml 
kind: Service
apiVersion: v1
metadata:
  name: konga-nodeport
spec:
  type: NodePort
  ports:
   - name: http
     protocol: TCP
     port: 1337
     targetPort: 1337
     nodePort: 31337
  selector:
    app: konga
EOF
kubectl apply -f svc.yml
```