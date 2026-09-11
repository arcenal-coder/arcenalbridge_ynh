# Architecture

ARCenal QSSE (Dolibarr) remains the source of business data and owns the PAO workflows.

ARCenal Portail is the mobile interface for LDAP-authenticated employees. It contains no Dolibarr administrator access and no cross-application permission logic.

ARCenal Bridge owns the integration lifecycle: pairing, scoped gateway permission, connectivity check and detachment. The bridge permission is owned by the selected Dolibarr YunoHost application and points only to `/custom/arcenalqsse/gateway.php`.
