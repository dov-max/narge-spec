// Normalise a connecting address for de-dup only: full IPv4, or the IPv6 /64 prefix.
// The result is fed straight into an HMAC and never stored, returned or logged.
export function normIp(ip: string): string {
  if (!ip) return "";
  if (!ip.includes(":")) return ip.trim();
  let s = ip.trim().toLowerCase();
  const pct = s.indexOf("%");
  if (pct >= 0) s = s.slice(0, pct);
  // IPv4-mapped IPv6 -> IPv4
  const mapped = s.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return mapped[1];
  const [head, tail] = s.split("::");
  const h = head ? head.split(":") : [];
  const t = tail !== undefined ? (tail ? tail.split(":") : []) : [];
  const groups = tail !== undefined ? [...h, ...Array(8 - h.length - t.length).fill("0"), ...t] : h;
  return groups.slice(0, 4).map((g) => parseInt(g || "0", 16).toString(16)).join(":") + "::/64";
}
