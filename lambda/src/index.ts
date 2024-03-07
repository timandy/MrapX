import { signRequest } from './sigv4a_cf';

export async function handler(event: any, context: any, callback: any): Promise<void> {
  const cf = event.Records[0].cf;
  const config = cf.config;
  const request = cf.request;
  const method = request.method;
  console.log(`---------- ${config.requestId} ----------`);
  console.log(`==>Request: ${JSON.stringify(request)}`);
  switch (method) {
    case 'GET':
    case 'PUT':
      await signRequest(config, request, method);
      break;
    default:
      console.log(`Not supported method '${method}'!`);
      break;
  }
  callback(null, request);
  console.log(`==>Signed: ${JSON.stringify(request)}`);
  console.log('Done!');
  return;
}
