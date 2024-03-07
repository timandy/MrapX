# MrapX

`MrapX` 是基于 `AWS` 云原生技术栈的内容交付和上传解决方案。

通过 `MrapX` 解决方案可以优化应用程序的性能，从而为最终用户提供最佳的体验。
`Mrap` 解决方案将 [Amazon S3 多区域接入点](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/MultiRegionAccessPoints.html)
与 [Amazon CloudFront](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/Introduction.html) 结合使用，
为 `Web` 应用程序、静态资产或存储在 `Amazon S3` 中的任何对象提供服务。

`MrapX` 主要解决用户地理位置分布全球，访问中心资源延迟较高的难题。
其会自动设置提供基于延迟的路由，以最低的网络延迟交付和上传内容。

## 架构

### 总览

![overview.svg](image/overview.svg)

整体架构按照应用场景分为 [客户端下载](#客户端下载)、[客户端上传](#客户端上传)、[服务端下载](#服务端上传下载) 和 [服务端上传](#服务端上传下载) 四部分。

### 客户端下载

![client-download.svg](image/client-download.svg)

1. 客户端发出 `HTTP` 请求到达 `CloudFront` [边缘节点](https://aws.amazon.com/cn/cloudfront/features/#Global_Edge_Network)。
2. 如果要 [限制私有访问](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/PrivateContent.html)，那么 `CloudFront` 将对请求进行验证签名。
3. `CloudFront` 调用关联的源请求 [Lambda@Edge](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/lambda-at-the-edge.html) 函数。
4. `Lambda` 函数使用 [SigV4A](https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/reference_aws-signing.html) 算法对请求进行签名并修改请求对象。
5. 修改后的请求对象将返回到 `CloudFront`。
6. `CloudFront` 使用修改后的请求向源组中的 [S3 多区域接入点](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/MultiRegionAccessPoints.html) 发出请求。
7. `S3` 多区域接入点根据最低网络延迟将请求路由到 `S3` 存储桶。
8. 如果回源失败 `CloudFront` 执行 [故障转移](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/high_availability_origin_failover.html) 流程，再次调用关联的源请求 `Lambda@Edge` 函数。
9. `Lambda` 函数判断源非 `S3` 多区域接入点跳过签名。
10. 回源请求原样返回到 `CloudFront`。
11. `CloudFront` 使用 [OAC](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html) 身份认证向指定的 `S3` 存储桶发出请求。

服务端上传时，直接将文件 `PUT` 到故障转移的 `S3` 存储桶。

服务端上传后客户端立即下载场景，故障转移流程能确保客户端可以访问到指定的文件。

### 客户端上传

![client-upload.svg](image/client-upload.svg)

1. 客户端发出 `HTTP` 请求到达 `CloudFront` [边缘节点](https://aws.amazon.com/cn/cloudfront/features/#Global_Edge_Network)。
2. 上传需 [限制私有访问](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/PrivateContent.html)，此时 `CloudFront` 将对请求进行验证签名。
3. `CloudFront` 调用关联的源请求 [Lambda@Edge](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/lambda-at-the-edge.html) 函数。
4. `Lambda` 函数使用 [SigV4A](https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/reference_aws-signing.html) 算法对请求进行签名并修改请求对象。
5. 修改后的请求对象将返回到 `CloudFront`。
6. `CloudFront` 使用修改后的请求向源组中的 [S3 多区域接入点](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/MultiRegionAccessPoints.html) 发出请求。
7. `S3` 多区域接入点根据最低网络延迟将请求路由到 `S3` 存储桶。

客户端上传后立即下载的场景，在客户端 `IP` 不变的情况下，该解决方案会回源到与上传时相同的 `S3` 存储桶。

各个 `S3` 存储桶之间配置 [跨区域复制](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/MultiRegionAccessPointBucketReplication.html) (`CRR`)，
并启用 [S3 Replication Time Control](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/replication-time-control.html) (`S3 RTC`)前提下，
文件变更会在 `15` 分钟内复制 `99.99%` 的对象。

有一特殊场景可忽略不予处理，即客户端上传后，用户通过代理修改了访问 `IP`，从而回源 `S3` 存储桶可能改变，导致在短时间内无法访问刚上传的文件。

数据类上传，即客户端上传后服务端立即需要使用的场景，通过 `API` 进行上传，不要使用该方案。

### 服务端上传下载

![server-download-upload.svg](image/server-download-upload.svg)

1. 服务端直连 `API` 所在相同区域的 `S3` 存储桶进行 `GET` 和 `PUT` 操作。

选定该 `S3` 存储桶选定为故障转移的源。

服务端上传后客户端立即下载场景，故障转移流程将回源到该 `S3` 存储桶。

## 性能

与通过公共互联网路由到 `S3` 的请求相比，通过 `S3` 多区域接入点路由的互联网源 `Amazon S3` 数据请求可以使
[性能](https://aws.amazon.com/cn/getting-started/hands-on/getting-started-with-amazon-s3-multi-region-access-points/) 提高多达 `60%`。

当请求的文件未在 `CloudFront` 边缘节点缓存时，通过 `MrapX` 解决方案，可显著提升回源性能，尤其是客户端设备距离源 `S3` 存储桶较远的地区。

## 可用性

因为多区域接入点关联了一个以上的 `S3` 存储桶，所以即便有个别存储桶故障也不会影响所有用户，表明该方案具备异地灾备特性。

在下载流程中，如果多区域接入点回源失败，则会再次回源故障转移的 `S3` 存储桶，表明该方案具备故障转移特性。

综上，与 `CloudFront` 回源到单个 `Amazon S3` 存储桶的方案比较，`MrapX` 解决方案具有更高的可用性。

## 安全性

- `S3` 多区域接入点关联的存储桶 [权限](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/access-control-block-public-access.html) 都配置为 `阻止所有公开访问`，防止被其他设施意外访问或泄露。
- 作为故障转移的 `S3` 存储桶应配置 [策略](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/bucket-policies.html)，只允许来自指定分配的请求可执行 `s3:GetObject` 操作。
- `S3` 多区域接入点 [权限](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/MultiRegionAccessPointPermissions.html) 应配置为 `阻止所有公开访问`，防止被公开访问。
- 下载流程中负责签名的 `Lambda@Edge` 执行角色的 [权限](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/lambda-edge-permissions.html)，只额外包含 `s3:GetObject` 权限，防止越权访问。
- 上传流程中负责签名的 `Lambda@Edge` 执行角色的 [权限](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/lambda-edge-permissions.html)，只额外包含 `s3:PutObject` 权限，防止越权访问。
- 如果某些资源只有授权用户能访问，则应在 `CloudFront` 使用 [签名URL](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-urls.html)
  或 [签名Cookie](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-cookies.html)。
- 另外还可按需在 `CloudFront` 启用 [WAF](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/distribution-web-awswaf.html)，以进一步提升安全性。

## 成本

与 `CloudFront` 回源到单个 `Amazon S3` 存储桶的方案比较，`MrapX` 解决方案成本有所增加。

增加的成本主要来自以下服务：

- `S3` 多区域存储，会造成存储成本增加。
- 开启跨区域复制(`CRR`)时，`S3` 存储桶强制开启版本控制，存储成本增加。
- 开启跨区域复制时，如果启用了 `RTC`，则会有额外的费用产生。
- 由于多区域接入点使用了 `GA` 网络，会产生额外的加速流量费用。
- 执行签名操作的 `Lambda@Edge`，会增加 `Lambda` 运行的费用。
- 存储 `Lambda@Edge` 的日志，会增加 `CloudWatch` 费用。
- 跨区域复制，可能会产生额外的跨区流量费。

为了尽可能的减少费用增加，可以通过以下方法：

- 用户数量不多的情况下，不要创建过多的 `S3` 存储桶。
- 配置存储桶声明周期策略，删除额外的文件版本。
- 配置存储桶声明周期策略，修改存储类为智能分层。

## 合规

- Amazon CloudFront [合规性验证](https://docs.aws.amazon.com/zh_cn/AmazonCloudFront/latest/DeveloperGuide/compliance.html)。
- Amazon S3 [合规性验证](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/s3-compliance.html)。

## 部署

查看 [部署文档](script/README.md) 以获取更多信息。

## 安全

查看 [安全文档](SECURITY.md) 以获取更多信息。

## 许可证

`MrapX` 是在 [Apache License 2.0](LICENSE) 下发布的。

```
Copyright 2021-2024 TimAndy

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
