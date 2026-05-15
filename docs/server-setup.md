# Server setup — iodine on Ubuntu

This guide walks through setting up an iodine DNS-tunnel server on an Ubuntu/Debian VPS. After this, you can use the **DNS Tunnel** macOS client to connect to it.

## Prerequisites

- A VPS with public IPv4 (any cheap provider — RUVDS, Hetzner, DigitalOcean, OVH, ...)
- Root SSH access
- A domain you control (must be able to add NS and A records)
- ~10 minutes

## Step 1 — Set up DNS delegation

You need to delegate a subdomain to your VPS, so the internet routes DNS queries for `*.t.yourdomain.com` to your VPS, where iodine will answer them.

In your domain's DNS panel (Cloudflare, reg.ru, Namecheap, ...), add **two records**:

| Subdomain | Type | Value | Purpose |
|---|---|---|---|
| `ns1` | A | `<VPS public IP>` | Glue record — `ns1.yourdomain.com` resolves to your VPS |
| `t` | NS | `ns1.yourdomain.com.` | Delegates `t.yourdomain.com` zone to your VPS |

⚠️ **Order matters** — add the A record first, then the NS. The trailing dot in the NS value matters.

⚠️ The subdomain `t` is intentionally short — DNS labels are limited to 63 chars, total query 255. The shorter your subdomain, the more payload bytes per query.

Wait 1–4 hours for propagation. Verify:

```bash
dig A ns1.yourdomain.com @8.8.8.8 +short
# expected: <VPS public IP>

dig NS t.yourdomain.com @8.8.8.8 +short
# expected: ns1.yourdomain.com.
```

## Step 2 — Install iodine on the VPS

```bash
ssh root@your-vps
apt update
apt install -y iodine
```

On Ubuntu, the iodine package may install with a Debian-style "masked" systemd unit (the package suppresses auto-start). Unmask it:

```bash
rm -f /etc/systemd/system/iodined.service
systemctl unmask iodined.service 2>/dev/null || true
systemctl daemon-reload
```

## Step 3 — Open port 53 in iptables

```bash
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -p tcp --dport 53 -j ACCEPT
```

If you have `netfilter-persistent` installed, save the rules so they survive reboot:

```bash
apt install -y iptables-persistent  # if not already
netfilter-persistent save
```

## Step 4 — Enable IP forwarding + NAT (for exit-node behaviour)

The iodine clients get IPs in `10.0.66.0/24`. To let them reach the actual internet through your VPS, enable forwarding and add a NAT rule:

```bash
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

# Replace eth0 with your actual default interface (check: ip route show default)
iptables -t nat -A POSTROUTING -s 10.0.66.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -s 10.0.66.0/24 -j ACCEPT
iptables -A FORWARD -d 10.0.66.0/24 -j ACCEPT

netfilter-persistent save
```

## Step 5 — Generate a strong password

```bash
openssl rand -base64 24 | tr -d '/+=' | cut -c1-28
# example output: vqXig2K7plz1nfoZpdUVkI7cJJcl
```

Save this — you'll need it both server-side and in the macOS client.

## Step 6 — Create systemd service

Create `/etc/systemd/system/iodined.service`:

```ini
[Unit]
Description=Iodine DNS Tunnel Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/iodined -f -c -P YOUR_PASSWORD_HERE -n YOUR_VPS_IP 10.0.66.1/24 t.yourdomain.com
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Replace `YOUR_PASSWORD_HERE`, `YOUR_VPS_IP`, and `t.yourdomain.com`.

Flags:
- `-f` foreground (required for systemd)
- `-c` disable IP source check (lets clients on CGNAT/mobile reconnect cleanly)
- `-P PASS` shared secret
- `-n IP` external IP that the server announces to clients
- `10.0.66.1/24` internal tunnel subnet — server gets `.1`, clients get `.2+`

```bash
chmod 600 /etc/systemd/system/iodined.service   # password is in here
systemctl daemon-reload
systemctl enable --now iodined.service
systemctl status iodined.service
```

## Step 7 — Verify externally

From any machine outside the VPS:

```bash
dig NS t.yourdomain.com +trace 2>&1 | tail -5
# expect to see: t.yourdomain.com. ... NS ns.t.yourdomain.com.
# (this NS is announced by iodine itself — that means traffic is reaching your server)
```

You can also use the official check page:
**https://code.kryo.se/iodine/check-it/** — enter your tunnel domain.

## Step 8 — Connect from macOS

Install the **DNS Tunnel.app** on your Mac, open it, click **Servers → + Add**, and enter:

- **Name:** anything (`My VPS`)
- **Tunnel domain:** `t.yourdomain.com`
- **Password:** the one you generated
- **Server IP:** your VPS public IP

Click **Status** tab → **Connect**.

## Security notes

- Port 53 open to the internet means your VPS will receive constant DNS scan/amplification probes. iodine only answers for its own zone, so you're not an open resolver — but logs (and fail2ban) will fill up. Consider `iptables` rate limits.
- The password is shared — anyone who has it can use your tunnel. Treat it like a VPN credential.
- iodine's traffic is **detectable by DPI** (base32-encoded DNS labels are unmistakable). For environments with active DPI (РКН, China), DNS tunneling will eventually be blocked. Use it where DNS is the only way out, not as your daily VPN.

## Troubleshooting

**Tunnel doesn't come up on the client:**
- Verify NS delegation: `dig NS t.yourdomain.com +trace`
- Check iodined is running: `systemctl status iodined`
- Check logs: `journalctl -u iodined -f`
- Check the network you're testing from actually allows DNS (some captive portals block 53/UDP entirely until you accept TOS)

**iodine reports "Could not detect external IP":**
- Probably the resolver can't reach your VPS at all. Test: `dig anything.t.yourdomain.com @8.8.8.8`. If that fails, NS delegation is broken.

**RAM usage growing on the server:**
- iodine itself is tiny (~5 MB), but each client connection uses some buffers. If you have many users, monitor `free -h`. On 1 GB VPS, expect to support 5–10 simultaneous clients comfortably.

## Want a different server?

This client is universal — point it at any iodine server you have access to. Just enter the domain, password, and IP in the Servers tab.
