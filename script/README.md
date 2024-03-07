# 部署文档

## 先决条件

- 具有足够 [AWS Identity and Access Management (IAM)](https://aws.amazon.com/iam/)
  权限的 `AWS` 账户，可以创建 [Amazon CloudFront 分配](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-working-with.html) 和 `Lambda` 函数。

- 一个 `us-east-1` 区域下的 `Amazon S3` 存储桶，以便向其上传 `Lambda` 部署包。

- 一个预先创建好的 `S3` 多区域接入点。

- 安装并 [配置](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) 好的 [AWS 命令行 (CLI)](https://aws.amazon.com/cli/) 以部署 `CloudFormation` 模版。

- [Node.js 20](https://nodejs.org) 或更高版本，建议使用 [nvm](https://github.com/nvm-sh/nvm) 管理你的 `Node.js` 版本。

- 该解决方案的 `GitHub` 存储库。你可以使用 [Git](https://git-scm.com) 命令从终端克隆存储库。

- 用于打包 `Lambda` 部署包的 `zip` 命令行工具。通常可使用软件包管理器快速安装。

- 用于发出 `HTTP` 请求的 [curl](https://curl.se) 命令行工具。通常 `curl` 预装在现代操作系统上。

## 部署下载流程堆栈

### 部署

```shell
./deploy_get.sh 'MrapX-Get-Demo' 'clst-lambda-pkg' 'mrap-sg-01' 'm7xo58b1n6jet.mrap'
```

- 第一个参数(必须)：`CloudFormation` 堆栈名。
- 第二个参数(必须)：预先创建好的 `us-east-1` 区域下的用来临时存储 `Lambda` 部署包的 `Amazon S3` 存储桶名。
- 第三个参数(必须)：预先创建好的承担故障转移功能的 `Amazon S3` 存储桶名。
- 第四个参数(必须)：预先创建好的 `S3` 多区域接入点别名。
- 第五个参数(可选)：`AWS CLI` 配置名。

堆栈会被部署在 `us-east-1` 区域。
部署完成后可在 `CloudFormation` 资源页查看 `CloudFront` 的分配 `ID`，在输出页查看对应的域名。

### 验证

- 往 `S3` 多区域接入点关联的任一存储桶手动上传文件，待跨区域复制(`CRR`)将文件同步到其他存储桶后，通过 `CloudFront` 分配的域名下载该文件。
- 往承担故障转移功能的 `Amazon S3` 存储桶手动上传文件，立即通过 `CloudFront` 分配的域名下载该文件。

### 清理

```shell
./clean.sh 'MrapX-Get-Demo'
```

- `CloudFormation` 可能无法删除 `Lambda` 函数版本，因为它是与 `CloudFront` 发行版关联的复制函数。在这种情况下，请在几个小时后再次尝试删除 `Lambda` 函数。
  有关更多信息，请参阅 [删除 Lambda@Edge 函数和副本](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/lambda-edge-delete-replicas.html)。

## 部署上传流程堆栈

### 部署

```shell
./deploy_put.sh 'MrapX-Put-Demo' 'clst-lambda-pkg' 'mrap-sg-01' 'm7xo58b1n6jet.mrap'
```

- 第一个参数(必须)：`CloudFormation` 堆栈名。
- 第二个参数(必须)：预先创建好的 `us-east-1` 区域下的用来临时存储 `Lambda` 部署包的 `Amazon S3` 存储桶名。
- 第三个参数(必须)：预先创建好的承担故障转移功能的 `Amazon S3` 存储桶名。
- 第四个参数(必须)：预先创建好的 `S3` 多区域接入点别名。
- 第五个参数(可选)：`AWS CLI` 配置名。

堆栈会被部署在 `us-east-1` 区域。
部署完成后可在 `CloudFormation` 资源页查看 `CloudFront` 的分配 `ID`，在输出页查看对应的域名。

### 验证

- [为可信密钥组创建密钥对](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/private-content-trusted-signers.html#private-content-creating-cloudfront-key-pairs)。
- 通过 `CloudFront` 控制台上传公钥。
- 通过 `CloudFront` 控制台创建密钥组，并将公钥添加到密钥组。
- 修改分配的行为，打开限制查看器访问，关联密钥组。
- [重新设置密钥对格式](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/private-content-trusted-signers.html#private-content-reformatting-private-key)，导出 `DER` 格式的私有密钥。
- [使用 Java 创建 URL 签名](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/CFPrivateDistJavaDevelopment.html)。
- 通过签名 `URL`，执行 `POST` 方法上传文件，请求体为文件流。
- 通过下载流程的 `CloudFront` 分配域名执行 `GET` 方法下载文件。

### 清理

```shell
./clean.sh 'MrapX-Put-Demo'
```

- `CloudFormation` 可能无法删除 `Lambda` 函数版本，因为它是与 `CloudFront` 发行版关联的复制函数。在这种情况下，请在几个小时后再次尝试删除 `Lambda` 函数。
  有关更多信息，请参阅 [删除 Lambda@Edge 函数和副本](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/lambda-edge-delete-replicas.html)。
