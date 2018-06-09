# Recursion protection utils

if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# -----------------------------------------------------------------------------

set -e; # fail on errors


# get obj_name for key
function __recursion_get_obj_name {
    echo "__RECURSION_PROTECTION__OBJ_${1}__"
}


# Initialize recursion protection for key
# recursion_protection_init <key>
function recursion_protection_init {
    local obj_name=$(__recursion_get_obj_name $1);
    if [ -z "${!obj_name:-''}" ]; then
        return 1;
    fi

    declare -gA "$obj_name";
    return 0;
}

# Check recursion protection for key,value
# This function check if value for key already checked.
# If not them mark it as checked.
# If passed value already was checked by this function,
# then return non-zero exit code. If passed value was not checked before,
# then return zero exit code.
#
# recursion_protection_check <key> <value>
function recursion_protection_check {
    # Exit with 2 code if no key and value specified
    if [ -z $1 ] || [ -z $2 ]; then
        return 2;
    fi

    local key=$1;
    local value=$(echo "$2" | sed -r "s/[^A-Za-z0-9]/_/g");

    local obj_name=$(__recursion_get_obj_name $key);
    local res="$(eval echo \"\${${obj_name}[$value]}\")"

    if [ -z "${res:-}" ]; then
        eval "${obj_name}['$value']=1";
        return 0;
    else
        return 1;
    fi
}


# Close recursion protection for a key
#
# recursion_protection_close <key>
function recursion_protection_close {
    unset $(__recursion_get_obj_name $1);
}


# Simplified call to recursion protection
#
# recursion_protection_easy_check <key> <value>
function recursion_protection_easy_check {
    recursion_protection_init $1 || true;

    if recursion_protection_check $1 $2; then
        return 0;
    else
        return 1;
    fi
}
