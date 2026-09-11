# ARCenal Bridge for YunoHost

ARCenal Bridge is the administrative connector between ARCenal Portail and the
ARCenal QSSE Dolibarr module.

It owns the only cross-application operation: a protected YunoHost permission
for the signed QSSE gateway. It never changes Dolibarr’s main permission and it
does not grant employee access to Dolibarr.

## Installation order

1. Activate ARCenal QSSE in Dolibarr and generate its pairing key.
2. Install ARCenal Portail for the `equipiers` group.
3. Install ARCenal Bridge, select the Portal and Dolibarr applications, and
   provide the HTTPS gateway URL and pairing key.
4. Use the Bridge configuration panel to check the connection.

## Operational guarantee

The portal and the bridge have separate update lifecycles. Updating ARCenal
Portail never changes a Dolibarr permission. Bridge is the only package allowed
to create, verify or remove the narrowly scoped gateway permission.
