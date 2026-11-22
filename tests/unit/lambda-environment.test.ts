import { readFileSync } from 'fs';
import { join } from 'path';

// Each Lambda finds its SSM parameters through the SSM_PREFIX environment variable. When one was
// missing, the Lambda asked SSM for paths of the default prefix, IAM refused the whole request
// and the Lambda ran on its built-in defaults without anyone noticing. Terraform is read as text
// because that is where the variable is set.
const lambdaTf = readFileSync(join(__dirname, '..', '..', 'terraform', 'modules', 'lambda', 'main.tf'), 'utf8');

function lambdaBlocks(): Record<string, string> {
  const blocks: Record<string, string> = {};
  const pattern = /resource "aws_lambda_function" "(\w+)" \{([\s\S]*?)\n\}/g;
  for (const match of lambdaTf.matchAll(pattern)) blocks[match[1]] = match[2];
  return blocks;
}

describe('Lambda environment variables in Terraform', () => {
  const blocks = lambdaBlocks();

  it('finds the three handlers', () => {
    expect(Object.keys(blocks).sort()).toEqual(['fanout_handler', 'rest_handler', 'websocket_handler']);
  });

  it.each(Object.keys(blocks))('%s receives SSM_PREFIX from var.ssm_prefix', name => {
    expect(blocks[name]).toMatch(/SSM_PREFIX\s*=\s*var\.ssm_prefix/);
  });

  it.each(Object.keys(blocks))('%s no longer sets a path per parameter', name => {
    expect(blocks[name]).not.toMatch(/SSM_(SEARCH_RADIUS|INACTIVITY_TTL|LOCATION_UPDATE_INTERVAL|MAX_FRIENDS|NEARBY_STRANGERS_LIMIT)\b/);
  });
});
