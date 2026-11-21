import { captureAWSv3Client } from 'aws-xray-sdk-core';

/**
 * Makes every call a client sends to AWS (DynamoDB, SSM, S3...) show up as a
 * subsegment of the Lambda's X-Ray trace, with its own duration and errors.
 *
 * It only instruments inside Lambda: outside it there is no trace to attach to
 * and the X-Ray SDK would log "context missing" errors on every call.
 */
export function traced<T extends Parameters<typeof captureAWSv3Client>[0]>(client: T): T {
  if (!process.env.AWS_LAMBDA_FUNCTION_NAME) return client;
  return captureAWSv3Client(client) as T;
}
