#!/usr/bin/env python3
"""Run from the approved private QA agent. Input is ONLY the metadata PE output.
Usage: terraform output -json private_endpoints > pe-metadata.json
       python3 verify_private_connectivity.py pe-metadata.json
Does not read state, secret values or job streams. No Azure resources are changed.
"""
import ipaddress
import json
import socket
import ssl
import sys
import time


def records(endpoint):
    found = {}
    for item in endpoint.get("dns_configs", []):
        if item.get("fqdn") and item.get("ipAddresses"):
            found.setdefault(item["fqdn"], set()).update(item["ipAddresses"])
    for group in endpoint.get("dns_zone_groups", []):
        for config in group.get("properties", {}).get("privateDnsZoneConfigs", []):
            for record in config.get("properties", {}).get("recordSets", []):
                if record.get("fqdn") and record.get("ipAddresses"):
                    found.setdefault(record["fqdn"], set()).update(record["ipAddresses"])
    return found


def verify(host, expected):
    if not host.lower().rstrip(".").endswith(".azure-automation.net"):
        raise ValueError("Unexpected Automation DNS suffix")
    resolved = {entry[4][0] for entry in socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)}
    if not expected or not expected.issubset(resolved) or not resolved.issubset(expected):
        raise ValueError("DNS answers do not match the endpoint's expected addresses")
    if not all(ipaddress.ip_address(ip).is_private for ip in resolved):
        raise ValueError("DNS resolved a non-private address")
    context = ssl.create_default_context()
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    with socket.create_connection((host, 443), timeout=10) as tcp:
        with context.wrap_socket(tcp, server_hostname=host):
            pass


def main():
    endpoints = json.load(open(sys.argv[1], encoding="utf-8"))
    if not endpoints:
        raise ValueError("No PE output; bootstrap is not accepted private integration")
    for key, endpoint in endpoints.items():
        checks = records(endpoint)
        if not checks:
            raise ValueError(f"No DNS record metadata for endpoint {key}; supply verified service FQDN records through the networking owner")
        for host, expected in checks.items():
            for attempt in range(6):
                try:
                    verify(host, expected)
                    print(f"PASS {key}: DNS and TLS connectivity verified for {host}")
                    break
                except (OSError, ValueError):
                    if attempt == 5:
                        raise ValueError(f"Private DNS/TLS check failed for endpoint {key}") from None
                    time.sleep(10)
    print("PASS private DNS/TLS checks. Asset consumption and allowed/denied RBAC tests are separate QA gates.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, IndexError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
