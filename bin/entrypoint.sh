#!/bin/bash

# Configures and Start LDAP

if [[ "${DEBUG}" == "true" ]]; then
    set -x
fi

escurl() {
    echo $1 | sed 's|/|%2F|g'
}

display_info() {
    echo -e "\033[1;32mInfo: $1\033[0m"
}

display_error() {
    echo -e "\033[1;31mError: $1\033[0m"
}

if [[ ! -f "${CA_FILE}" ]] || [[ ! -f "${KEY_FILE}" ]] || [[ ! -f "${CERT_FILE}" ]]; then
    ENABLE_SSL="false"
else
    ENABLE_SSL="true"
fi

SLAPD_CONF_DIR="/etc/openldap/slapd.d"
SLAPD_CONF_FILE="/etc/openldap/slapd.conf"
SLAPD_IPC_SOCKET="/run/openldap/ldapi"

if [[ ! -d "${SLAPD_CONF_DIR}" ]]; then
    # Default Variables
    [[ -z "${ORGANISATION_NAME}" ]] && export ORGANISATION_NAME="Example Ltd"
    [[ -z "${SUFFIX}" ]] && export SUFFIX="dc=example,dc=com"
    [[ -z "${ROOT_USER}" ]] && export ROOT_USER="admin"
    [[ -z "${ROOT_PW}" ]] && export ROOT_PW="admin"
    [[ -z "${LOG_LEVEL}" ]] && export LOG_LEVEL="stats"

    if [[ "${ENABLE_SSL}" == "true" ]]; then
        display_info "CA_FILE: ${CA_FILE}."
        display_info "KEY_FILE: ${KEY_FILE}."
        display_info "CERT_FILE: ${CERT_FILE}."

        sed -i "s~%CA_FILE%~${CA_FILE}~g" "${SLAPD_CONF_FILE}"
        sed -i "s~%KEY_FILE%~${KEY_FILE}~g" "${SLAPD_CONF_FILE}"
        sed -i "s~%CERT_FILE%~${CERT_FILE}~g" "${SLAPD_CONF_FILE}"
        if [[ -n "${TLS_VERIFY_CLIENT}" ]]; then
            sed -i "/TLSVerifyClient/ s/demand/${TLS_VERIFY_CLIENT}/" "${SLAPD_CONF_FILE}"
        fi
    else
        # Comment out TLS configuration
        sed -i "s~TLSCACertificateFile~#&~" "${SLAPD_CONF_FILE}"
        sed -i "s~TLSCertificateKeyFile~#&~" "${SLAPD_CONF_FILE}"
        sed -i "s~TLSCertificateFile~#&~" "${SLAPD_CONF_FILE}"
        sed -i "s~TLSVerifyClient~#&~" "${SLAPD_CONF_FILE}"
    fi

    sed -i "s~%ROOT_USER%~${ROOT_USER}~g" "${SLAPD_CONF_FILE}"
    sed -i "s~%SUFFIX%~${SUFFIX}~g" "${SLAPD_CONF_FILE}"

    # Encrypt root password before replacing
    ROOT_PW=$(slappasswd -o module-load=pw-pbkdf2.so -h {PBKDF2-SHA512} -s "${ROOT_PW}")
    sed -i "s~%ROOT_PW%~${ROOT_PW}~g" "${SLAPD_CONF_FILE}"

    # Generating configuration
    mkdir -p "${SLAPD_CONF_DIR}"
    slaptest -f "${SLAPD_CONF_FILE}" -F "${SLAPD_CONF_DIR}" >/dev/null 2>&1

    # Start slapd for init configuration
    slapd -h "ldap:/// ldapi://$(escurl ${SLAPD_IPC_SOCKET})" -F "${SLAPD_CONF_DIR}" -d "${LOG_LEVEL}" &
    SLAPD_PID=$!

    display_info "Waiting for Server [${SLAPD_PID}] to Start..."
    let index=0
    while [[ ${index} -lt 60 ]]
    do
        printf "."
        ldapsearch -Y EXTERNAL -H ldapi://$(escurl ${SLAPD_IPC_SOCKET}) -s base -b '' >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            printf "\n"
            break
        else
            sleep 1
        fi
        let index=$((index + 1))
    done
	if [[ $? -eq 0 ]]; then
        display_info "Server running an ready to be configured."
        rm -f /etc/openldap/slapd.conf
        rm -f /etc/openldap/slapd.ldif
        rm -f /etc/openldap/DB_CONFIG.example
	else
        display_error "OMG, the service is not started, please check the configuration file!"
	fi

    # Init Custom ldif, Order is important
    display_info "Adding system config from /ldif/*.ldif"
    for ldif in /etc/openldap/ldif/*.ldif
    do
        display_info "Entrypoint: adding ${ldif}"
        sed -i "s~%SUFFIX%~${SUFFIX}~g" "${ldif}"
        sed -i "s~%ORGANISATION_NAME%~${ORGANISATION_NAME}~g" "${ldif}"
        ldapmodify -Y EXTERNAL -H ldapi://$(escurl ${SLAPD_IPC_SOCKET}) -f "${ldif}" -c
    done

	if [[ -d "/ldif" ]]; then
		display_info "Adding user config from /ldif/*.ldif"
		for ldif in /ldif/*.ldif
        do
            display_info "Entrypoint: adding ${ldif}"
            ldapmodify -Y EXTERNAL -H ldapi://$(escurl ${SLAPD_IPC_SOCKET}) -f "${ldif}" -c
		done
	fi

    display_info "Waiting for Server [${SLAPD_PID}] to Stop..."
    kill -SIGTERM ${SLAPD_PID}
    sleep 3
fi

if [[ "${ENABLE_SSL}" == "true" ]]; then
    display_info "Starting LDAPS Server..."
    slapd -d "${LOG_LEVEL}" -h "ldaps:/// ldapi://$(escurl ${SLAPD_IPC_SOCKET})" -F "${SLAPD_CONF_DIR}"
else
    display_info "Starting LDAP Server..."
    slapd -d "${LOG_LEVEL}" -h "ldap:/// ldapi://$(escurl ${SLAPD_IPC_SOCKET})" -F "${SLAPD_CONF_DIR}"
fi
