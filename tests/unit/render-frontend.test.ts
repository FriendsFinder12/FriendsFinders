// eslint-disable-next-line @typescript-eslint/no-require-imports
const { renderIndex, readConfig } = require('../../scripts/render-frontend');

// The shape of `terraform output -json`.
const outputs = {
  cognito_hosted_ui_url: { value: 'https://app.auth.us-east-1.amazoncognito.com' },
  cognito_web_client_id: { value: 'web-client' },
  http_api_endpoint: { value: 'https://abc.execute-api.us-east-1.amazonaws.com' },
  websocket_api_endpoint: { value: 'wss://def.execute-api.us-east-1.amazonaws.com/dev' },
  aws_region: { value: 'us-east-1' },
};

const page = '<html><head><title>x</title></head><body></body></html>';

describe('readConfig', () => {
  it('maps the Terraform outputs to the keys the page reads', () => {
    expect(readConfig(outputs)).toEqual({
      cognitoDomain: 'https://app.auth.us-east-1.amazoncognito.com',
      webClientId: 'web-client',
      httpApi: 'https://abc.execute-api.us-east-1.amazonaws.com',
      wsApi: 'wss://def.execute-api.us-east-1.amazonaws.com/dev',
      region: 'us-east-1',
    });
  });

  it('names the missing output instead of publishing a page that cannot log in', () => {
    const { cognito_web_client_id: _removed, ...rest } = outputs;
    expect(() => readConfig(rest)).toThrow('cognito_web_client_id');
  });
});

describe('renderIndex', () => {
  it('puts the config in a script just before </head>', () => {
    const html = renderIndex(page, outputs);
    expect(html).toContain('<script>window.__APP_CONFIG__ = {');
    expect(html.indexOf('window.__APP_CONFIG__')).toBeLessThan(html.indexOf('</head>'));
    expect(html).toContain('"webClientId":"web-client"');
    expect(html.startsWith('<html><head><title>x</title><script>')).toBe(true);
  });

  it('cannot be broken out of the script by a value containing </script>', () => {
    const hostile = { ...outputs, cognito_web_client_id: { value: '</script><script>alert(1)' } };
    const html = renderIndex(page, hostile);
    expect(html.match(/<\/script>/g)).toHaveLength(1);
  });

  it('refuses a page with no </head>, where the config could not go', () => {
    expect(() => renderIndex('<html></html>', outputs)).toThrow('</head>');
  });
});
