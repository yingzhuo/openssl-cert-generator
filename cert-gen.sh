#!/usr/bin/env bash
# 生成SSL双向验证所需证书文件等
# 作者: 应卓

set -e

# 证书过期时间 (天)
EXPIRE_DAYS="36500"

# 私钥密码 (所有私钥使用同一密码)
KEY_PASSWORD="123456"

# 秘钥库密码 (所有秘钥库使用同一密码)
STORE_PASSWORD="123456"

# 是否打包最后结果 (yes | no)
TAR_ALL="no"

# ----------------------------------------------------------------------------------------------------------------------

# 创建目录
mkdir -p ./{root,server,client}

cat <<"EOF" >./sign-req.cnf
[req]
prompt                      = no
distinguished_name          = req_distinguished_name
req_extensions              = req_ext

[req_distinguished_name]
C                           = CN
ST                          = Shanghai
L                           = Shanghai
O                           = Unknown
OU                          = Unknown
CN                          = Unknown

[req_ext]
keyUsage                    = keyEncipherment, dataEncipherment, nonRepudiation, digitalSignature
extendedKeyUsage            = serverAuth, clientAuth, codeSigning, emailProtection
subjectAltName              = @alt_names

[alt_names]
IP.1                        = 127.0.0.1
IP.2                        = 10.211.55.3
IP.3                        = 10.211.55.4
IP.4                        = 10.211.55.5
DNS.1                       = www.yingzhuo.com
EOF

# ----------------------------------------------------------------------------------------------------------------------
# CA Root
# ----------------------------------------------------------------------------------------------------------------------

if [ ! -f ./root/ca.cert ] && [ ! -f ./root/ca.key ] && [ ! -f ./root/ca.csr ]; then
  # 私钥文件
  openssl genrsa \
    -des3 \
    -out ./root/ca.key \
    -passout pass:"$KEY_PASSWORD" \
    2048

  # 请求文件
  openssl req \
    -new \
    -out ./root/ca.csr \
    -key ./root/ca.key \
    -passin pass:"$KEY_PASSWORD" \
    -config ./sign-req.cnf

  # 签名文件
  openssl x509 \
    -req \
    -in ./root/ca.csr \
    -signkey ./root/ca.key \
    -out ./root/ca.cert \
    -CAcreateserial \
    -passin pass:"$KEY_PASSWORD" \
    -days "$EXPIRE_DAYS"
fi

# ----------------------------------------------------------------------------------------------------------------------
# Sever Side
# ----------------------------------------------------------------------------------------------------------------------

# 私钥文件
openssl genrsa \
  -des3 \
  -out ./server/server.key \
  -passout pass:"$KEY_PASSWORD" \
  2048

# 请求文件
openssl req \
  -new \
  -key ./server/server.key \
  -out ./server/server.csr \
  -passin pass:"$KEY_PASSWORD" \
  -config ./sign-req.cnf

# 用根证书签名服务端证书
openssl x509 \
  -req \
  -CA ./root/ca.cert \
  -CAkey ./root/ca.key \
  -in ./server/server.csr \
  -out ./server/server.cert \
  -CAcreateserial \
  -days "$EXPIRE_DAYS" \
  -passin pass:"$KEY_PASSWORD"

# 打包 (签名文件 + 私钥文件)
openssl pkcs12 \
  -export \
  -in ./server/server.cert \
  -inkey ./server/server.key \
  -out ./server/server.keystore.p12 \
  -passin pass:"$KEY_PASSWORD" \
  -passout pass:"$STORE_PASSWORD" \
  -name "server"

# 打包 (CA root)
openssl pkcs12 \
  -export \
  -in ./root/ca.cert \
  -inkey ./root/ca.key \
  -out ./server/server.truststore.p12 \
  -passin pass:"$KEY_PASSWORD" \
  -passout pass:"$STORE_PASSWORD" \
  -name "CARoot"

# ----------------------------------------------------------------------------------------------------------------------
# Client Side
# ----------------------------------------------------------------------------------------------------------------------

# 私钥文件
openssl genrsa \
  -des3 \
  -out ./client/client.key \
  -passout pass:"$KEY_PASSWORD" \
  2048

# 请求文件
openssl req \
  -new \
  -key ./client/client.key \
  -out ./client/client.csr \
  -passin pass:"$KEY_PASSWORD" \
  -config ./sign-req.cnf

# 用根证书签名服务端证书
openssl x509 \
  -req \
  -CA ./root/ca.cert \
  -CAkey ./root/ca.key \
  -in ./client/client.csr \
  -out ./client/client.cert \
  -CAcreateserial \
  -days "$EXPIRE_DAYS" \
  -passin pass:"$KEY_PASSWORD"

# 打包 (签名文件 + 私钥文件)
openssl pkcs12 \
  -export \
  -in ./client/client.cert \
  -inkey ./client/client.key \
  -out ./client/client.keystore.p12 \
  -passin pass:"$KEY_PASSWORD" \
  -passout pass:"$STORE_PASSWORD" \
  -name "client"

# 打包 (CA root)
openssl pkcs12 \
  -export \
  -in ./root/ca.cert \
  -inkey ./root/ca.key \
  -out ./client/client.truststore.p12 \
  -passin pass:"$KEY_PASSWORD" \
  -passout pass:"$STORE_PASSWORD" \
  -name "CARoot"

# ----------------------------------------------------------------------------------------------------------------------
# 清理和打包
# ----------------------------------------------------------------------------------------------------------------------

rm -rf ./.srl
rm -rf ./sign-req.cnf

if [ "$TAR_ALL" == "yes" ]; then
  mkdir -p ./generated/
  cp -R ./root ./generated
  cp -R ./server ./generated
  cp -R ./client ./generated
  tar -czf ./generated.tar.gz ./generated
  rm -rf ./generated ./root ./client ./server
fi
