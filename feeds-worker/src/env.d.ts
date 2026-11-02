interface Env {
  ASSETS: Fetcher;
  TOKENS: KVNamespace;
  STATS: KVNamespace;
  COUNTER: DurableObjectNamespace<import("./counter").FetchCounter>;
  RL?: RateLimit;
  K_MIN?: string;
  COUNTER_SECRET?: string;
}
