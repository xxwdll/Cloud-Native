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
systemctl enable nfs-server && systemctl start nfs-server
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
      username: "ucloud"
      password: "ucloud.cn"
      database: "kong"
image:
  tag: 12.14.0-debian-11-r2
EOF
helm install ps-db bitnami/postgresql \
-f my-values.yaml
```

### 安装kong
官网地址 https://github.com/Kong/kubernetes-ingress-controller
注释里有以下注意点 
- 1 有两种方式dbless和指定数据库
- 2 推荐使用自建数据库 通过env变量
```
# Kong can run without a database or use either Postgres or Cassandra
# as a backend datatstore for it's configuration.
# By default, this chart installs Kong without a database.

# If you would like to use a database, there are two options:
# - (recommended) Deploy and maintain a database and pass the connection
#   details to Kong via the `env` section.
# - You can use the below `postgresql` sub-chart to deploy a database
#   along-with Kong as part of a single Helm release. Running a database
#   independently is recommended for production, but the built-in Postgres is
#   useful for quickly creating test instances.
```

```bash
$ helm repo add kong https://charts.konghq.com
$ helm repo update
#$ helm install kong/kong --generate-name --set ingressController.installCRDs=false
# 我直接pull了chart包 然后修改values.yaml的文件 主要修改了两处 一个是不采用dbless 一个是svc使用nodeport
# --- values.yaml ---
env:
  database: "postgres"
  pg_host: ps-db-postgresql.default.svc.cluster.local
  pg_port: 5432
  pg_user: ucloud
  pg_password: ucloud.cn
  pg_database: kong

proxy:
  # Enable creating a Kubernetes service for the proxy
  enabled: true
  #type: LoadBalancer
  type: NodePort
# --- values.yaml ---

kubectl create namespace kong
helm install gateway ./ --namespace kong -f values.yaml --set ingressController.installCRDs=false
#helm install gateway kong/kong --namespace kong --set ingressController.installCRDs=false

### 安装结束输出
NAME: gateway
LAST DEPLOYED: Mon Mar  6 14:52:42 2023
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
To connect to Kong, please execute the following commands:

HOST=$(kubectl get svc --namespace default gateway-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
PORT=$(kubectl get svc --namespace default gateway-kong-proxy -o jsonpath='{.spec.ports[0].port}')
export PROXY_IP=${HOST}:${PORT}
curl $PROXY_IP

Once installed, please follow along the getting started guide to start using
Kong: https://docs.konghq.com/kubernetes-ingress-controller/latest/guides/getting-started/
```


### 安装konga
https://github.com/dangtrinhnt/konga-helm-chart
- 注 此方法不通 还是使用kubectl apply 部署
- 不部署konga了 不支持高版本的kong
部署
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
```

开放svc
```bash
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