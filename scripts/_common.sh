#!/bin/bash

bridge_load_settings() {
    portal_app=$(ynh_app_setting_get --key=portal_app)
    dolibarr_app=$(ynh_app_setting_get --key=dolibarr_app)
    gateway_url=$(ynh_app_setting_get --key=gateway_url)
    gateway_key=$(ynh_app_setting_get --key=gateway_key)
}

bridge_validate() {
    [[ "$portal_app" =~ ^arcenalportail(__[0-9]+)?$ ]] || ynh_die "Sélectionnez une instance ARCenal Portail valide."
    [[ "$dolibarr_app" =~ ^dolibarr(__[0-9]+)?$ ]] || ynh_die "Sélectionnez une instance Dolibarr valide."
    [[ "$gateway_url" =~ ^https://.+/custom/arcenalqsse/gateway\.php$ ]] || ynh_die "L’URL de passerelle est invalide."
    [[ "$gateway_key" =~ ^[a-fA-F0-9]{64}$ ]] || ynh_die "La clé d’appairage doit contenir 64 caractères hexadécimaux."
    ynh_app_setting_get --app="$portal_app" --key=install_dir >/dev/null || ynh_die "ARCenal Portail n’est pas installé."
    ynh_app_setting_get --app="$dolibarr_app" --key=install_dir >/dev/null || ynh_die "Dolibarr n’est pas installé."
}

bridge_resolve_gateway() {
    bridge_info=$(BRIDGE_GATEWAY_URL="$gateway_url" BRIDGE_DOLIBARR_APP="$dolibarr_app" yunohost tools shell -c '
import json
import os
from urllib.parse import urlparse
from yunohost.app import app_setting

app = os.environ["BRIDGE_DOLIBARR_APP"]
url = urlparse(os.environ["BRIDGE_GATEWAY_URL"])
domain = app_setting(app, "domain")
path = app_setting(app, "path")
if url.scheme != "https" or url.hostname != domain or not isinstance(path, str):
    raise SystemExit("The gateway URL does not belong to the selected Dolibarr application")
base = "/" + path.strip("/")
if base == "/":
    relative = url.path
elif url.path.startswith(base + "/"):
    relative = url.path[len(base):]
else:
    raise SystemExit("The gateway URL is outside the selected Dolibarr path")
if relative != "/custom/arcenalqsse/gateway.php":
    raise SystemExit("Unexpected gateway path")
print(json.dumps({"permission": app + ".arcenalqsse_gateway", "relative": relative}))
' 2>&1) || ynh_die "Impossible de vérifier l’emplacement de la passerelle : $bridge_info"

    bridge_permission=$(printf '%s' "$bridge_info" | python3 -c 'import json,sys; print(json.load(sys.stdin)["permission"])')
    bridge_relative_path=$(printf '%s' "$bridge_info" | python3 -c 'import json,sys; print(json.load(sys.stdin)["relative"])')
}

bridge_configure_permission() {
    BRIDGE_PERMISSION="$bridge_permission" BRIDGE_RELATIVE_PATH="$bridge_relative_path" yunohost tools shell -c '
import os
from yunohost.permission import permission_create, permission_url, user_permission_list

permission = os.environ["BRIDGE_PERMISSION"]
relative = os.environ["BRIDGE_RELATIVE_PATH"]
app = permission.split(".", 1)[0]
permissions = user_permission_list(full=True, apps=[app])["permissions"]
if permission in permissions:
    permission_url(permission, url=relative, auth_header=False)
else:
    permission_create(permission, allowed=["visitors"], url=relative, auth_header=False, show_tile=False, protected=True)
'
}

bridge_write_portal_config() {
    local portal_dir config_path
    portal_dir=$(ynh_app_setting_get --app="$portal_app" --key=install_dir)
    config_path="$portal_dir/config.php"
    install -d -o "$portal_app" -g www-data -m 750 "$portal_dir"
    BRIDGE_CONFIG_PATH="$config_path" BRIDGE_GATEWAY_URL="$gateway_url" BRIDGE_GATEWAY_KEY="$gateway_key" php -r '
$path = getenv("BRIDGE_CONFIG_PATH");
$config = [
    "trusted_sso" => true,
    "paired" => true,
    "gateway_url" => getenv("BRIDGE_GATEWAY_URL"),
    "gateway_key" => getenv("BRIDGE_GATEWAY_KEY"),
];
if (file_put_contents($path, "<?php\nreturn " . var_export($config, true) . ";\n", LOCK_EX) === false) {
    fwrite(STDERR, "Unable to write portal configuration\n");
    exit(1);
}
'
    chown "$portal_app:www-data" "$config_path"
    chmod 400 "$config_path"
}

bridge_apply() {
    bridge_load_settings
    bridge_validate
    bridge_resolve_gateway
    bridge_configure_permission
    bridge_write_portal_config
    ynh_app_setting_set --key=bridge_permission --value="$bridge_permission"
    ynh_app_setting_set --key=bridge_relative_path --value="$bridge_relative_path"
    ynh_print_success "Liaison ARCenal opérationnelle."
}

bridge_test() {
    bridge_load_settings
    bridge_validate
    local status
    status=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --connect-timeout 5 --max-time 10 --request POST "$gateway_url" || true)
    if [[ "$status" == "302" || "$status" == "301" || "$status" == "000" ]]; then
        ynh_die "La passerelle QSSE ne répond pas correctement."
    fi
    ynh_print_success "Passerelle joignable (réponse HTTP $status)."
}

bridge_detach() {
    bridge_load_settings
    local permission
    permission=$(ynh_app_setting_get --key=bridge_permission)
    if [[ -n "$permission" ]]; then
        BRIDGE_PERMISSION="$permission" yunohost tools shell -c '
import os
from yunohost.permission import permission_delete, user_permission_list
permission = os.environ["BRIDGE_PERMISSION"]
app = permission.split(".", 1)[0]
if permission in user_permission_list(full=True, apps=[app])["permissions"]:
    permission_delete(permission, force=True)
'
    fi
    ynh_app_setting_delete --key=bridge_permission
    ynh_app_setting_delete --key=bridge_relative_path
    ynh_print_success "Liaison ARCenal déconnectée."
}
