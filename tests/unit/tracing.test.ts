import { DynamoDBClient } from '@aws-sdk/client-dynamodb';

const captureAWSv3Client = jest.fn((client: unknown) => client);
jest.mock('aws-xray-sdk-core', () => ({
  captureAWSv3Client: (client: unknown) => captureAWSv3Client(client),
}));

import { traced } from '../../src/utils/tracing';

describe('traced', () => {
  const original = process.env.AWS_LAMBDA_FUNCTION_NAME;

  afterEach(() => {
    if (original === undefined) delete process.env.AWS_LAMBDA_FUNCTION_NAME;
    else process.env.AWS_LAMBDA_FUNCTION_NAME = original;
    captureAWSv3Client.mockClear();
  });

  it('returns the client untouched outside Lambda (tests, local runs)', () => {
    delete process.env.AWS_LAMBDA_FUNCTION_NAME;
    const client = new DynamoDBClient({});
    expect(traced(client)).toBe(client);
    expect(captureAWSv3Client).not.toHaveBeenCalled();
  });

  it('instruments the client inside Lambda so each AWS call becomes a trace subsegment', () => {
    process.env.AWS_LAMBDA_FUNCTION_NAME = 'nearby-friends-rest-handler';
    const client = new DynamoDBClient({});
    expect(traced(client)).toBe(client);
    expect(captureAWSv3Client).toHaveBeenCalledWith(client);
  });
});
