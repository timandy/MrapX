import { aws_sign_request, AwsCredentialsProvider, AwsSignatureType, AwsSignedBodyHeaderType, AwsSignedBodyValue, AwsSigningAlgorithm, AwsSigningConfig } from 'aws-crt/dist/native/auth';
import { HttpHeaders, HttpRequest } from 'aws-crt/dist/native/http';

//执行 SigV4A 签名算法, 返回传入的 headers 和 签名 headers; 需要给执行 Lambda 的角色, 授予要访问的服务的权限
export async function get_sigv4a_headers_core(method: string, url: string, headers: HttpHeaders, config: AwsSigningConfig) {
  headers.set('Host', new URL(url).host);
  const request = new HttpRequest(method, url, headers);
  const signedRequest = await aws_sign_request(request, config);
  return signedRequest.headers;
}

//执行 SigV4A 签名算法, 返回传入的 headers 和 签名 headers; 需要给执行 Lambda 的角色, 授予要访问的服务的权限
export async function get_sigv4a_headers(method: string, url: string, headers: HttpHeaders, service: string) {
  const config: AwsSigningConfig = {
    service: service,
    region: '*',
    algorithm: AwsSigningAlgorithm.SigV4Asymmetric,
    signature_type: AwsSignatureType.HttpRequestViaHeaders,
    signed_body_header: AwsSignedBodyHeaderType.XAmzContentSha256,
    signed_body_value: AwsSignedBodyValue.UnsignedPayload,
    provider: AwsCredentialsProvider.newDefault()
  };
  return await get_sigv4a_headers_core(method, url, headers, config);
}
