# gaire.lab — Network & Server Inventory
**Maintained by:** Ramesh Gaire  
**Last updated:** May 2026  
**Domain:** gaire.lab

---

## Network Infrastructure

| Component | Model | Role |
|---|---|---|
| Firewall | SonicWall TZ370 | Perimeter security, NAT |
| Router | Netcomm NL20 | Home internet gateway |
| Remote Access | Tailscale (WireGuard) | Zero-trust mesh VPN |

**Internal subnet:** 10.10.10.0/24 (static IPs)  
**IPv6:** Disabled  
**DNS:** SYD-DC01 (10.10.10.10), SYD-DC02 (10.10.10.11)

---

## Server Inventory

| Hostname | Role | Internal IP | Tailscale IP | OS | Host |
|---|---|---|---|---|---|
| SYD-DC01 | Primary Domain Controller | 10.10.10.10 | Pending | WS2022 | SYD-HV01 (direct) |
| SYD-DC02 | Secondary Domain Controller | 10.10.10.11 | Pending | WS2022 | SYD-HV02 (direct) |
| SYD-VM01 | Ubuntu / Docker host | 10.10.10.12 | 100.69.145.33 | Ubuntu 24.04 LTS | SYD-CL01 cluster |
| SYD-SQL01 | SQL Database Server | 10.10.10.15 | Pending | WS2022 | SYD-CL01 cluster |
| SYD-RDS01 | RDS Broker / Web / Session Host | 10.10.10.21 | Pending | WS2022 | SYD-CL01 cluster |
| SYD-HV01 | Hyper-V Host 01 | 10.10.10.50 | 100.95.115.103 | WS2022 | Physical |
| SYD-HV02 | Hyper-V Host 02 (Management) | 10.10.10.51 | 100.127.39.113 | WS2022 | Physical |
| SYD-STOR01 | Storage / File Server / Quorum | 10.10.10.60 | 100.64.122.68 | WS2022 | SYD-CL01 cluster |

---

## Cluster Architecture

- **SYD-CL01** — Hyper-V Failover Cluster object (not a physical machine)
- SYD-DC01 runs directly on SYD-HV01 — pinned, not in cluster
- SYD-DC02 runs directly on SYD-HV02 — pinned, not in cluster
- All other VMs are cluster members — can live-migrate between HV01 and HV02
- SYD-STOR01 provides CSV (Cluster Shared Volume) and Quorum witness
- SYD-SQL01 hosts SQL instance used for RDS HA configuration

---

## Docker Stack — SYD-VM01 (10.10.10.12)

| Service | URL | Port | Purpose |
|---|---|---|---|
| Portainer | https://100.69.145.33:9443 | 9443 | Docker management GUI |
| n8n | http://100.69.145.33:5678 | 5678 | Automation workflows |
| Ollama | http://100.69.145.33:11434 | 11434 | Local LLM engine |
| Open WebUI | http://100.69.145.33:3000 | 3000→8080 | Private AI chat interface |

**Model installed:** phi3 (2.2GB — Microsoft, CPU-compatible)

---

## Monitoring

**Tool:** n8n workflows + Python health_check.py  
**Script location:** /home/lab.admin@gaire.lab/gaire-lab-automation/health_check.py  
**Alerts:** ntfy.sh/gaire-lab-alerts (push notifications)

| Workflow | Schedule | Purpose |
|---|---|---|
| gaire-lab - Full Infrastructure Monitor | Every 5 min | Alert on any server down |
| gaire-lab - Daily Health Report | 8:00 AM daily | Morning status summary |

**Monitoring protocols used:**

| Server type | Protocol | Port | Reason |
|---|---|---|---|
| Domain Controllers | TCP | 389 | LDAP — confirms AD DS is responding |
| SQL Server | TCP | 1433 | SQL port — confirms DB engine is up |
| RDS Server | TCP | 3389 | RDP port — confirms RDS is accessible |
| Hypervisor hosts | TCP | 5985 | WinRM — confirms remote management |
| File/Storage server | TCP | 445 | SMB — confirms file sharing is up |
| Docker services | HTTP/HTTPS | various | Web apps — confirms application layer |
| Internet | HTTPS | 443 | Confirms outbound connectivity |

---

## GitHub Repository

**URL:** https://github.com/rameshgaire/gaire-lab-automation  
**Purpose:** Automation scripts, infrastructure code, lab documentation  

| File | Purpose |
|---|---|
| health_check.py | Multi-protocol infrastructure monitor |
| docker/docker-compose.yml | Full Docker stack definition |
| lab-inventory.md | This document |
| lab-log.md | Session notes and learning log |

---

## Remote Access

From any location with Tailscale installed:

```bash
# SSH into Ubuntu Docker host
ssh lab.admin@100.69.145.33

# Access Docker management
https://100.69.145.33:9443

# Access automation workflows
http://100.69.145.33:5678

# Access private AI
http://100.69.145.33:3000
```