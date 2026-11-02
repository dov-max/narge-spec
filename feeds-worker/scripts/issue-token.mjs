// Issue a per-company feed token. Prints the token ONCE (hand it to the company over
// their verified contact) and the KV command that stores only its SHA-256.
// Usage: node scripts/issue-token.mjs <org-id>      (org-id: short slug, e.g. "acme-co")
import { randomBytes, createHash } from "node:crypto";
const org = process.argv[2];
if (!org || !/^[a-z0-9][a-z0-9-]{1,40}$/.test(org) || org === "public") {
  console.error("usage: node scripts/issue-token.mjs <org-slug>"); process.exit(2);
}
const A = "abcdefghijklmnopqrstuvwxyz234567";
const bytes = randomBytes(17); // 136 bits read, 130 used -> 26 base32 chars (>=128 bits)
let bits = 0n; for (const b of bytes) bits = (bits << 8n) | BigInt(b);
let tok = ""; for (let i = 0; i < 26; i++) { tok += A[Number(bits & 31n)]; bits >>= 5n; }
const h = createHash("sha256").update(tok).digest("hex");
console.log(`token (give to ${org} once, do not store): ${tok}`);
console.log(`feed base: https://feeds.thecutline.org/v1/${tok}/`);
console.log(`store:   npx wrangler kv key put --binding TOKENS --remote "t:${h}" '{"org":"${org}","status":"active"}'`);
console.log(`revoke:  npx wrangler kv key put --binding TOKENS --remote "t:${h}" '{"org":"${org}","status":"revoked"}'`);
