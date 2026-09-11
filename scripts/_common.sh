#!/bin/bash

bridge_load_settings() {
    portal_app=$(ynh_app_setting_get --key=portal_app)
    dolibarr_app=$(ynh_app_setting_get --key=dolibarr_app)
    gateway_url=$(ynh_app_setting_get --key=gateway_url)
    gateway_key=$(ynh_app_setting_get --key=gateway_key)
    pairing_code=$(ynh_app_setting_get --key=pairing_code)
}

bridge_validate() {
    [[ "$portal_app" =~ ^arcenalportail(__[0-9]+)?$ ]] || ynh_die "Sélectionnez une instance ARCenal Portail valide."
    [[ "$dolibarr_app" =~ ^dolibarr(__[0-9]+)?$ ]] || ynh_die "Sélectionnez une instance Dolibarr valide."
    [[ "$gateway_url" =~ ^https://.+/custom/arcenalqsse/gateway\.php$ ]] || ynh_die "L’URL de passerelle est invalide."
    if [[ ! "$gateway_key" =~ ^[a-f0-9]{64}$ && ! "$pairing_code" =~ ^[a-f0-9]{48}$ ]]; then
        ynh_die "Un code d’appairage ARCenal QSSE valide est requis."
    fi
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

bridge_exchange_pairing() {
    if [[ "$gateway_key" =~ ^[a-f0-9]{64}$ ]]; then
        return 0
    fi
    local response
    set +x
    response=$(curl --silent --show-error --fail --connect-timeout 8 --max-time 20 --request POST \
        --header 'Content-Type: application/json' \
        --data "{\"operation\":\"pair\",\"pairing_code\":\"$pairing_code\"}" \
        "$gateway_url") || ynh_die "Le code d’appairage a été refusé ou la passerelle QSSE est indisponible."
    gateway_key=$(printf '%s' "$response" | php -r '$data=json_decode(stream_get_contents(STDIN),true);$key=is_array($data)?($data["gateway_key"]??""):"";if(!is_string($key)||!preg_match("/^[a-f0-9]{64}$/D",$key)){fwrite(STDERR,"Réponse d’appairage invalide\n");exit(1);}echo $key;') || ynh_die "Réponse d’appairage QSSE invalide."
    ynh_app_setting_set --key=gateway_key --value="$gateway_key"
    ynh_app_setting_delete --key=pairing_code
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
    bridge_exchange_pairing
    bridge_write_portal_config
    ynh_app_setting_set --key=bridge_permission --value="$bridge_permission"
    ynh_app_setting_set --key=bridge_relative_path --value="$bridge_relative_path"
    ynh_print_success "Liaison ARCenal opérationnelle."
}

bridge_test() {
    bridge_load_settings
    bridge_validate
    local body timestamp nonce signature response status
    body='{"operation":"health","uid":"__bridge_health"}'
    timestamp=$(date +%s)
    nonce=$(openssl rand -hex 16) || ynh_die "Impossible de générer un contrôle de liaison."
    set +x
    signature=$(BRIDGE_TEST_KEY="$gateway_key" BRIDGE_TEST_TIMESTAMP="$timestamp" BRIDGE_TEST_NONCE="$nonce" BRIDGE_TEST_BODY="$body" php -r 'echo hash_hmac("sha256",getenv("BRIDGE_TEST_TIMESTAMP")."\n".getenv("BRIDGE_TEST_NONCE")."\n".getenv("BRIDGE_TEST_BODY"),getenv("BRIDGE_TEST_KEY"));')
    response=$(curl --silent --show-error --fail --connect-timeout 5 --max-time 10 --request POST \
        --header 'Content-Type: application/json' \
        --header "X-Arcenal-Timestamp: $timestamp" \
        --header "X-Arcenal-Nonce: $nonce" \
        --header "X-Arcenal-Signature: $signature" \
        --data "$body" "$gateway_url") || ynh_die "La passerelle QSSE ne répond pas correctement."
    status=$(printf '%s' "$response" | php -r '$data=json_decode(stream_get_contents(STDIN),true);echo is_array($data)&&($data["status"]??"")==="ok"?"ok":"invalid";')
    [[ "$status" == "ok" ]] || ynh_die "La passerelle a répondu, mais son contrôle de sécurité a échoué."
    ynh_print_success "Liaison ARCenal vérifiée."
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
