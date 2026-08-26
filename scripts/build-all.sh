#!/usr/bin/env bash
# Builds the whole polyrepo in dependency order: parent POM -> commons -> services.
# Installs the shared artifacts to ~/.m2 so the services resolve them, then packages the
# service fat jars that the compose 'build' step copies into images.
set -euo pipefail

# Resolve the workspace root (this repo's parent directory).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

mvn_cmd() { mvn -q -B "$@"; }

echo "==> 1/3 platform parent POM + BOM"
mvn_cmd -f aegis-platform-bom/pom.xml install

echo "==> 2/3 platform commons libraries"
mvn_cmd -f aegis-platform-commons/pom.xml install

echo "==> 3/3 service fat jars"
for svc in aegis-authorization-server aegis-identity-service aegis-tenant-service \
           aegis-edge-gateway aegis-mfa-webauthn-service aegis-saml-idp-service \
           aegis-social-broker-service aegis-scim-provisioning-service aegis-admin-api-service \
           aegis-agent-registry-service aegis-threat-analysis-service; do
  echo "    - $svc"
  # `clean` matters: `package` alone considers a module up to date when only a DEPENDENCY changed,
  # so a rebuilt commons jar silently does not reach the service fat jar — and the stale jar then
  # fails at runtime with an error that points at the wrong place entirely.
  mvn_cmd -f "$svc/pom.xml" -DskipTests clean package
done

echo "==> done."
echo "    next: (cd aegis-platform-infra/compose && docker compose up -d)"
echo "    then: aegis-platform-infra/scripts/e2e-agent-flow.sh"
