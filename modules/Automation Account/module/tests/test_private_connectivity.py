"""Offline logic tests; not Azure connectivity evidence."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch, MagicMock

spec = importlib.util.spec_from_file_location("verify", Path(__file__).parents[1] / "scripts" / "verify_private_connectivity.py")
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)

class ConnectivityTests(unittest.TestCase):
    def test_zone_group_record_extraction(self):
        endpoint = {"dns_zone_groups": [{"properties": {"privateDnsZoneConfigs": [{"properties": {"recordSets": [{"fqdn": "a.jrds.ue2.azure-automation.net", "ipAddresses": ["10.0.0.4"]}]}}]}}]}
        self.assertEqual(v.records(endpoint), {"a.jrds.ue2.azure-automation.net": {"10.0.0.4"}})

    def test_wrong_dns_is_rejected(self):
        with patch.object(v.socket, "getaddrinfo", return_value=[(2, 1, 6, "", ("10.0.0.5", 443))]):
            with self.assertRaises(ValueError):
                v.verify("a.jrds.ue2.azure-automation.net", {"10.0.0.4"})

    def test_public_ip_is_rejected(self):
        with patch.object(v.socket, "getaddrinfo", return_value=[(2, 1, 6, "", ("8.8.8.8", 443))]):
            with self.assertRaises(ValueError):
                v.verify("a.jrds.ue2.azure-automation.net", {"8.8.8.8"})

    def test_matching_dns_requires_tls(self):
        context = MagicMock()
        with patch.object(v.socket, "getaddrinfo", return_value=[(2, 1, 6, "", ("10.0.0.4", 443))]), patch.object(v.socket, "create_connection", return_value=MagicMock()), patch.object(v.ssl, "create_default_context", return_value=context):
            v.verify("a.jrds.ue2.azure-automation.net", {"10.0.0.4"})
        context.wrap_socket.assert_called_once()
        self.assertEqual(context.minimum_version, v.ssl.TLSVersion.TLSv1_2)

if __name__ == "__main__":
    unittest.main()
