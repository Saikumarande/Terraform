# CTG-27 Automation Account module

Creates one account, its SystemAssigned identity, declared encrypted variables/credentials,
optional account-scoped CanNotDelete lock and optional PE/DNS zone-group resources.
Existing RGs, subnets, DNS zones, endpoints, RBAC assignments and platform locks are read
without adopting ownership. No diagnostics, UAMI, RBAC creation, runbooks, schedules,
jobs, workers or shared networking are created.

## Naming and fixed controls

`aa-<appname>-<component>-<instance>-<appenv>-<region>`; component defaults to
`automation`, instance to `01`. Approved location/three-character region catalog is
supplied by the governed caller; no raw account-name/region override is exposed.
The name must be 6–50 characters. Basic SKU and disabled public/local authentication
are fixed. Every variable is encrypted. Mandatory global-* tags come from the actual
subscription. Governed Application/ApplicationId/Environment/Owner/Context/
ApplicationCategory tags cannot be overridden; additional CostCentre is required.
Global-tag naming and the caller catalog need enterprise review before release.

## Values and secrets

Define each variable in `automation_variables`; inject its JSON-encoded value in
`variable_values_json` using the same key. Types: string, int (signed int32), bool,
datetime (RFC3339), object (JSON object, not array). Example non-secret encodings:
`"\"payments\""`, `"3"`, `"true"`, `"\"2026-10-08T00:00:00Z\""`, `"{\"retries\":3}"`.
Credential definitions contain metadata; `credential_values` supplies matching
username/password objects. Resolve approved versioned secret references in the
pipeline; this module does not fetch Key Vault secret values. Neither passwords nor
variable values appear in outputs. Sensitive inputs, provider-computed account keys,
state and saved plans still need a protected encrypted backend and restricted access.
Do not publish raw state or JSON plans as QA evidence. Do not commit secrets/tfvars.

## PE integration and phased deployment

Default `deployment_phase="integrated"` requires PE entries. Each specifies `create`
or `existing`, Automation subresource DSCAndHybridWorker/Webhook and expected existing
private DNS zone IDs for privatelink.azure-automation.net (Azure public cloud).
Create mode supplies subnet, PE resource group and PE location. Existing mode supplies
only the external PE ID plus expected DNS zones/subresource; it never retargets the PE.
ARM lookups block on wrong target/subresource, unapproved connection, failed provisioning
or missing expected DNS zone-group associations. DNS-zone-group management is conditional
on PE creation; DNS zones, VNet links/resolvers remain external.

For a new separately owned PE: (1) use bootstrap with empty PE map to create account,
(2) networking creates PE using automation_account_id, (3) change to integrated/existing
and supply that PE ID. Bootstrap reports incomplete integration; it is not deployment
acceptance and must be disallowed by the production acceptance/promotion gate. Public
access remains disabled throughout. Never wire a whole-module depends_on cycle between
account/networking states. Real DNS/connectivity remains a separate gate, not a Terraform
metadata claim. This module does not put cloud execution into a VNet.

## Encryption and locks

Null CMK input uses service-managed account encryption. Optional customer_managed_key_id
adds the supported encryption block using the existing account system identity, not UAMI.
First create the account, have the separate RBAC owner grant its identity required access
to the existing enabled key, then update the key URI. Verify vault firewall/private
connectivity, key permissions, rotation and Azure CMK acceptance before release. No key,
vault or key permissions are created here. Do not request CMK during first account creation
without a separately verified identity/key access sequence.

Optional lock defaults off. Do not enable it when platform locks already apply. Existing
platform lock references are verified. Remove a module-created lock in a separate apply
before destroy; Terraform destroy ordering alone is not a reliable lock-removal workflow.
Review account/identity/PE replacement impact with networking, RBAC and CTG-26 owners.
Existing resource adoption needs import and a reviewed migration. Partial applies do not
roll back automatically; reconcile through the original owning state/pipeline.

## Validation and tests

Reference provider pins: AzureRM 4.38.1; AzAPI 2.3.0. Required engine >=1.6.
The source uses supported optional typed inputs and pre/postconditions. Re-run all checks
when upgrading providers. Commit the generated lock file. Providers are configured only
in the consumer and receive approved pipeline authentication. The required providers
must be registered in advance; the example disables automatic registration.

Commands from an approved agent:

```sh
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform test                  # Terraform >=1.7 mock runner; authored suite
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

OpenTofu 1.6 can use the module but does not run Terraform's mock-provider test syntax.
Use a Terraform >=1.7 runner (reference 1.9.8), or port fixtures to your approved OpenTofu
harness. Static analysis/security/policy compliance use your platform's approved tools;
the package does not claim your existing Harness pipeline already runs those tools.

After deployment, on an approved private QA agent:

```sh
terraform output -json private_endpoints > pe-metadata.json
python3 ../module/scripts/verify_private_connectivity.py pe-metadata.json
```

The script checks actual DNS answers against expected endpoint addresses, then verified
TLS >=1.2 connectivity. It does not prove asset consumption or effective RBAC. Fail the
acceptance gate for bootstrap, Pending/Rejected links, missing DNS metadata, failed private
connectivity or failed access tests. It uses bounded retries and does not retrieve secrets.

Additional Azure QA: account configuration/identity; all declared variable types; secure
credential and variable consumption through approved CTG-26/existing worker fixture;
allowed/denied principal operations; propagation/error distinctions; unchanged reapply;
expected value updates/drift; CMK if selected; optional lock enforcement/removal; outputs
versus observed resources; published JFrog module consumption once; UAT/policy/regression;
cleanup of module-owned resources only through their owning pipeline.

## Verification performed for this deliverable

- Terraform 1.9.8 formatting/parser check: passed.
- Official version-tagged provider docs/source reviewed; provider binaries downloaded.
- Four offline DNS/TLS-checker unit tests: passed (no network/Azure evidence).
- Provider-schema validation and Terraform mock tests: NOT executed successfully here.
  Provider processes cannot create local Unix sockets in this environment.
- Actual Azure plan/apply, OpenTofu engine execution, private DNS/TLS, CMK, asset execution,
  RBAC, locks, policy, Harness/JFrog and acceptance scenarios: pending on your approved agents.

## References

https://registry.terraform.io/providers/hashicorp/azurerm/4.38.1/docs/resources/automation_account
https://registry.terraform.io/providers/hashicorp/azurerm/4.38.1/docs/resources/automation_variable_datetime
https://registry.terraform.io/providers/hashicorp/azurerm/4.38.1/docs/resources/automation_variable_object
https://registry.terraform.io/providers/Azure/azapi/2.3.0/docs/data-sources/resource
https://registry.terraform.io/providers/Azure/azapi/2.3.0/docs/data-sources/resource_list
https://learn.microsoft.com/en-us/azure/automation/how-to/private-link-security
