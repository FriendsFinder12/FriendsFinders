import { SSMClient, GetParametersCommand } from '@aws-sdk/client-ssm';
import { traced } from './tracing';

const ssmClient = traced(new SSMClient({}));

interface AppConfig {
  searchRadiusMiles: number;
  inactivityTtlSeconds: number;
  locationUpdateIntervalSeconds: number;
  maxFriends: number;
  nearbyStrangersLimit: number;
}

const DEFAULTS: AppConfig = {
  searchRadiusMiles: 5,
  inactivityTtlSeconds: 600,
  locationUpdateIntervalSeconds: 30,
  maxFriends: 5000,
  nearbyStrangersLimit: 50,
};

// Every parameter lives under one prefix per environment (for example /nearby-friends-prod),
// which Terraform passes as SSM_PREFIX. Building the paths from it means one variable cannot be
// forgotten while the others are set, which used to send a request for a path IAM refused.
const SSM_PREFIX = (process.env.SSM_PREFIX || '/nearby-friends').replace(/\/+$/, '');

const PARAM_PATHS = {
  searchRadiusMiles: `${SSM_PREFIX}/search-radius-miles`,
  inactivityTtlSeconds: `${SSM_PREFIX}/inactivity-ttl-seconds`,
  locationUpdateIntervalSeconds: `${SSM_PREFIX}/location-update-interval-seconds`,
  maxFriends: `${SSM_PREFIX}/max-friends`,
  nearbyStrangersLimit: `${SSM_PREFIX}/nearby-strangers-limit`,
};

// A good value is reused for this long, so a changed SSM parameter reaches a warm container
// within one period. After a failed attempt SSM is left alone for the back-off period.
const DEFAULT_CACHE_TTL_SECONDS = 300;
const CACHE_TTL_MS = positiveNumber(process.env.CONFIG_CACHE_TTL_SECONDS, DEFAULT_CACHE_TTL_SECONDS) * 1000;
const FAILURE_BACKOFF_MS = 30 * 1000;

let lastGood: { config: AppConfig; expiresAt: number } | null = null;
let retryNotBefore = 0;
let inFlight: Promise<AppConfig> | null = null;

function positiveNumber(raw: string | undefined, fallback: number): number {
  const value = Number(raw);
  return raw !== undefined && Number.isFinite(value) && value > 0 ? value : fallback;
}

/** A setting must be a finite number above zero (and a whole number where it counts something). */
function parseSetting(path: string, raw: string | undefined, fallback: number, wholeNumber: boolean): number {
  if (raw === undefined) return fallback;

  const value = Number(raw);
  if (!Number.isFinite(value) || value <= 0 || (wholeNumber && !Number.isInteger(value))) {
    console.warn(`Ignoring invalid value "${raw}" for SSM parameter ${path}; using the default (${fallback})`);
    return fallback;
  }
  return value;
}

async function loadFromSsm(): Promise<AppConfig> {
  const response = await ssmClient.send(new GetParametersCommand({ Names: Object.values(PARAM_PATHS) }));

  const paramMap = new Map<string, string>();
  for (const param of response.Parameters || []) {
    if (param.Name && param.Value) {
      paramMap.set(param.Name, param.Value);
    }
  }

  const read = (key: keyof AppConfig, wholeNumber: boolean) =>
    parseSetting(PARAM_PATHS[key], paramMap.get(PARAM_PATHS[key]), DEFAULTS[key], wholeNumber);

  return {
    searchRadiusMiles: read('searchRadiusMiles', false),
    inactivityTtlSeconds: read('inactivityTtlSeconds', true),
    locationUpdateIntervalSeconds: read('locationUpdateIntervalSeconds', true),
    maxFriends: read('maxFriends', true),
    nearbyStrangersLimit: read('nearbyStrangersLimit', true),
  };
}

/** Never rejects: on failure it keeps the last good values, or falls back to the defaults. */
async function refresh(): Promise<AppConfig> {
  try {
    const config = await loadFromSsm();
    lastGood = { config, expiresAt: Date.now() + CACHE_TTL_MS };
    retryNotBefore = 0;
    return config;
  } catch (err) {
    retryNotBefore = Date.now() + FAILURE_BACKOFF_MS;
    console.error(
      `Failed to load configuration from SSM; using ${lastGood ? 'the last known' : 'the default'} values`,
      err
    );
    return lastGood ? lastGood.config : { ...DEFAULTS };
  }
}

export async function getConfig(): Promise<AppConfig> {
  const now = Date.now();
  if (lastGood && now < lastGood.expiresAt) return lastGood.config;

  // Concurrent callers share one SSM request.
  if (inFlight) return inFlight;

  // Recently failed: do not ask again yet.
  if (now < retryNotBefore) return lastGood ? lastGood.config : { ...DEFAULTS };

  inFlight = refresh().finally(() => {
    inFlight = null;
  });
  return inFlight;
}
