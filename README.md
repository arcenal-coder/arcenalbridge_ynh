# ARCenal Bridge for YunoHost

ARCenal Bridge is the administration component that connects ARCenal Portal with the ARCenal QSSE module in Dolibarr.

## Role

It selects both installed applications, verifies that the gateway address belongs to the chosen Dolibarr instance, creates a YunoHost permission limited to that route, exchanges the temporary module code, and writes the portal configuration.

The portal never changes Dolibarr. Dolibarr never exposes its general interface to employees.

## Administrator flow

1. Install ARCenal Portal and select the employee LDAP group.
2. In Dolibarr, create a temporary code in ARCenal QSSE.
3. Install ARCenal Bridge, select the portal and Dolibarr, then enter the displayed URL and code.
4. Use the “Check connection” Bridge configuration button.

The code is consumed once. To reconnect, generate a new code in Dolibarr and enter it in Bridge.

## Status

This branch is the new architecture baseline. It requires qualification on a YunoHost 12.1 staging instance before it can be published in the ARCenal catalog.
