# Aegis local Vault node 0 — integrated storage (Raft) HA cluster.
#
# Three nodes locally, not one, and deliberately so (ADR-0016): Vault sits on the token path, so a
# single-node dev topology would stop predicting production behaviour exactly where it matters most.
# Leader election, retry_join and follower reads are all exercised locally as a result.
ui = true
disable_mlock = true

storage "raft" {
  path    = "/vault/data"
  node_id = "vault-0"

  retry_join { leader_api_addr = "http://vault-0:8200" }
  retry_join { leader_api_addr = "http://vault-1:8200" }
  retry_join { leader_api_addr = "http://vault-2:8200" }
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  # Local only. Every deployed topology terminates TLS — see the Helm values and Terraform module.
  tls_disable = true
}

api_addr     = "http://vault-0:8200"
cluster_addr = "http://vault-0:8201"

# NOTE: no seal stanza here. Locally the bootstrap script unseals with the keys it just generated.
# In AWS/Azure this is replaced by an awskms / azurekeyvault seal stanza, which is the ONLY role
# cloud KMS retains under ADR-0015 — it no longer sits on the request path.
