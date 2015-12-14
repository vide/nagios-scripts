#!/usr/bin/env bash

WP=$(which wp)
WP_USER=$(id -u)
WP_PATH="$(pwd)"
CHECK_WHAT="core"
SEVERITY="warning"

function print_help() {

cat >&2 <<EOF
$@
  Usage: $(basename $0)
    [--check core|plugins]
      DEFAULT: core
      Chck whether WordPress core or plugins are up-to-datee
    [--path /path/to/wordpress]
      DEFAULT: current working directory
      Specify where to find the WordPress installation
    [--url http://wp.multisite.install]
      Mandatory in a multisite install (otherwise check will fail), specify which
      URL you are checking
    [--severity warning|critical]
      DEFAULT: warning
      If check is triggered, return this severity to Nagios
    [--help]
      This help page

EOF

exit 3

}

function wp_cli_works() {

 $WP_CLI core check-update > /dev/null 2>&1
 return $?
}

function wp_plugins_need_update() {

  # just check ENABLED plugins
  $WP_CLI plugin status | grep -q "^ U[AN]" 2> /dev/null
  return $?
}

function wp_core_need_update() {

  $WP_CLI core check-update | grep -qv "WordPress is at the latest version" 2> /dev/null
  return $?
}

function parse_options() {

  if [ -x "$WP_CLI" ]
  then
    echo "CRITICAL: wp CLI executable not found"
    exit 2
  fi

  OOPTIONS=$(getopt --longoptions "path:,url:,check:,severity:,help" "p:U:c:s:h" "$@")
  eval set -- "${OOPTIONS}"

  while [ $# -gt 0 ]
  do
    case "$1" in
      --path|-p)     WP_PATH="$2";    shift 2;;
      --url|-U)      WP_URL="$2";     shift 2;;
      --check|-c)    CHECK_WHAT="$2"; shift 2;;
      --severity|-s) SEVERITY="$2";   shift 2;;
      --)          shift;;
      --help|-h)   print_help "Help page" ;;
      *)           print_help "Wrong or missing parameter" ;;
    esac
  done

  if [ $WP_USER -eq 0 ]
  then
   WP_CLI="${WP} --allow-root"
  else
   WP_CLI=$WP
  fi

  WP_CLI+=" --path=$WP_PATH"

  [ -n "$WP_URL" ] && WP_CLI+=" --url=${WP_URL}"

  case "${SEVERITY}" in
    warning)
     EXIT_STATUS=1
     ERROR_TAG="WARNING"
     ;;
    critical)
     EXIT_STATUS=2
     ERROR_TAG="CRITICAL"
     ;;
    *)
     print_help "Invalid value for --severity param"
     ;;
  esac

}

# main starts here

parse_options "$@"

if ! wp_cli_works
then
  echo "CRITICAL: wp generic error. Maybe it's a multisite?"
  exit 2
fi

case "${CHECK_WHAT}" in
  core)
    if wp_core_need_update
    then
      RETURN_MSG="${ERROR_TAG}: WP core in ${WP_PATH} needs update"
    else
      RETURN_MSG="OK: WP core in ${WP_PATH} is up-to-date"
      EXIT_STATUS=0
    fi
    ;;
  plugins)
    if wp_plugins_need_update
    then
      RETURN_MSG="${ERROR_TAG}: at least one plugin in ${WP_PATH} needs update"
    else
      RETURN_MSG="OK: all WP plugins in ${WP_PATH} are up-to-date"
      EXIT_STATUS=0
    fi
    ;;
  *)
    print_help "Invalid value for --check param"
    ;;
esac

[ -n "$WP_URL" ] && RETURN_MSG+=" (URL: ${WP_URL})"
echo $RETURN_MSG
exit $EXIT_STATUS
