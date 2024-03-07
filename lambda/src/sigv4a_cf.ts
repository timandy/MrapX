import { get_sigv4a_headers } from './sigv4a';
import { HttpHeaders } from 'aws-crt/dist/native/http';

const IncludeHeaders = {
  XAmzCfId: 'X-Amz-Cf-Id'
};

const ExcludeHeaders = [
  'cloudfront-',
  'x-forwarded-for'
];

//对 CloudFront 自定义源请求进行签名
export async function signRequest(config: any, request: any, method: any): Promise<void> {
  const toSignUrl = getToSignUrl(request);
  if (!toSignUrl) {
    console.log('Only support custom origin!');
    return;
  }
  console.log(`==>ToSignUrl: ${toSignUrl}`);
  const toSignHeaders = getToSignHeaders(config, request);
  console.log(`==>ToSignHeaders: ${JSON.stringify({ headers: toSignHeaders._flatten() })}`);
  const signedHeaders = await get_sigv4a_headers(method, toSignUrl, toSignHeaders, 's3');
  request.headers = toCloudFrontHeaders(signedHeaders);
  request.querystring = '';
}

//获取要参与签名的 Url 前缀, 不带 s3 key
function getToSignBaseUrl(protocol: string, domain: string, port: number): string {
  switch (protocol) {
    case 'http':
      if (port === 80) {
        return `${protocol}://${domain}`;
      }
      break;
    case 'https':
      if (port === 443) {
        return `${protocol}://${domain}`;
      }
      break;
  }
  return `${protocol}://${domain}:${port}`;
}

//获取要参与签名的 Url
function getToSignUrl(request: any): string | undefined {
  const origin = request.origin.custom;
  if (!origin) {
    return undefined;
  }
  const protocol = origin.protocol ?? 'https';
  const domain = origin.domainName ?? '';
  const port = origin.port ?? 443;
  let url = getToSignBaseUrl(protocol, domain, port);
  const path = request.uri ?? '';
  if (path !== '')
    url += path;
  return url;
}

//是否需要参与签名的请求头
function isExcludeHeader(lowerHeaderName: string): boolean {
  for (const headerName of ExcludeHeaders) {
    if (lowerHeaderName.startsWith(headerName)) {
      return true;
    }
  }
  return false;
}

//获取要参与签名的请求头
function getToSignHeaders(config: any, request: any): HttpHeaders {
  const sourceHeaders = request.headers;
  const headers = new HttpHeaders();
  for (const headerKey in sourceHeaders) {
    if (isExcludeHeader(headerKey)) {
      continue;
    }
    const headerObjs = sourceHeaders[headerKey];
    for (const headerObj of headerObjs) {
      headers.add(headerObj.key, headerObj.value);
    }
  }
  //CloudFront 在源请求 Lambda 之后, 对源的请求之前添加 'X-Amz-Cf-Id' 请求头, 此处必须添加以参与签名
  headers.add(IncludeHeaders.XAmzCfId, config.requestId);
  return headers;
}

//将签名后的请求头转换为 CloudFront 请求头
function toCloudFrontHeaders(signedHeaders: HttpHeaders): any {
  //标头 'X-Amz-Cf-Id' 由 CloudFront 在执行Lambda@Edge后源请求之前添加, 此处必须移除
  signedHeaders.remove(IncludeHeaders.XAmzCfId);

  //将签名后的请求头格式转换为 CloudFront 源请求格式
  const headers: any = {};
  for (const headerObj of signedHeaders) {
    const name = headerObj[0];
    const value = headerObj[1];
    const lowerName = name.toLowerCase();
    const headerObjs = headers[lowerName];
    if (headerObjs) {
      headerObjs.push({ key: name, value: value });
      continue;
    }
    headers[lowerName] = [{ key: name, value: value }];
  }
  return headers;
}
