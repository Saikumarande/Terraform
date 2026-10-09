# Consumer

Copy terraform.tfvars.example to a local uncommitted terraform.tfvars and replace ****.
Approve the location catalog, subscription global-* tags, enterprise metadata and DNS
zone references. Inject values through Harness secret variables. Do not commit secret values.
Copy backend.hcl.example to backend.hcl; configure the existing encrypted/restricted state
backend. The storage/RG/container must already exist. Authenticate via approved OIDC/ARM_*.

Run `terraform init -backend-config=backend.hcl`, formatting, validation, approved static
analysis/policy checks, plan review and approved apply. Source ../module is the local package;
replace with your approved JFrog module source and release version when publishing.

- Create mode: integrated/create and the approved PE subnet/RG/location/DNS zone IDs.
- External mode: bootstrap first, deploy external PE with the account ID, then
  integrated/existing plus the external PE ID and expected DNS zone IDs.
- Do not change the identity/public access security baseline to work around networking.
- Supply variable definitions and matching JSON-encoded values only when assets are needed.
- Supply credential definitions and matching sensitive usernames/passwords only when needed.
- Additional externally assigned RBAC dependency references can be passed for metadata checks.
- Optional CMK is a staged update after key-access grants; optional module lock must be removed
  separately before destroy. Do not duplicate platform locks.

Review module README for full testing/acceptance requirements. Do not treat successful apply
or Terraform metadata checks as private-network execution evidence.
