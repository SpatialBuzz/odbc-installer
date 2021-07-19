
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function info {
    printf "\r💬 ${BLUE}INFO:${NC} %s\n" "${1}"
}
function fail {
    printf "\r🗯 ${RED}ERROR:${NC} %s\n" "${1}"
    exit 1
}
function warn {
    printf "\r⚠️ ${YELLOW}WARNING:${NC} %s\n" "${1}"
}

function brew_install {
    package=$1
    if brew list --formula | grep -q "$package" ;
    then
        info "Installing ${package}"
        brew install "$package"
    else
        info "Upgrading ${package}"
        brew upgrade "$package"
    fi
}

# based upon https://apple.stackexchange.com/a/311511
function install_dmg {
    tempd=$(mktemp -d)
    curl -fsSL "$1" > "$tempd/pkg.dmg"
    listing=$(sudo hdiutil attach "$tempd/pkg.dmg" | grep Volumes)
    volume=$(echo "$listing" | cut -f 3)
    for app in "$volume"/*.app ; do
        if [ -e "${app}" ] ; then
            echo sudo cp -rf "$volume"/*.app /Applications
        fi
    done
    for pkg in "$volume"/*.pkg ; do
        if [ -e "${pkg}" ] ; then
            echo sudo installer -pkg "$volume"/"$pkg" -target /
        fi
    done
    disk=$(echo "$listing" | cut -f 1 -d ' ')
    sudo hdiutil detach "${disk}"
    rm -rf "$tempd"
}

function get_customer_name {
    info "Enter the Customer ID e.g. demo_uk"
    read -r -p "Customer ID: " CUSTOMER_ID
    echo

    CUSTOMER_ID_WITH_DASH="${CUSTOMER_ID//_/-}"
}

function get_sudo_credentials {
    # clear any sudo credentials to force a password prompt
    sudo -k
    info "Enter the password for user '$(whoami)'"
    sudo echo
    echo
}

function get_credentials {
    # ask for Amazon credentials
    info "Enter the Amazon Athena credentials for customer ${CUSTOMER_ID}"
    read -r -p "Access Key: " AWS_KEY
    read -r -s -p "Secret Key: " AWS_SECRET
    echo
    echo
}

function install_xcode {
    # xcode command line tools
    info "Installing xcode command line tools"
    if xcode-select -p 2>&1 | grep -q 'unable to get active developer directory' ; then
        # Install xcode command line tools
        xcode-select --install
    fi
}

function install_homebrew {
    # homebrew
    info "Installing homebrew"
    if [[ -z "$(which brew)" ]] ; then
        # Install Homebrew
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        brew update
    fi

    # install packages
    info "Installing homebrew packages"
    brew_install gdal
    brew_install unixodbc 
    brew_install xmlstarlet
}

function install_athena_driver {

    # install Athena ODBC driver
    info "Installing Athena ODBC driver - ignore any installation windows that appear"
    install_dmg "https://s3.amazonaws.com/athena-downloads/drivers/ODBC/SimbaAthenaODBC_1.1.10.1000/OSX/Simba+Athena+1.1.dmg"
}

function install_iodbc_admin {
    # install iODBC Administrator
    info "Installing ODBC Administrator - ignore any installation windows that appear"
    MACOS_MAJOR_VER="$(sw_vers -productVersion | awk -F '.' '{print $1}')"
    install_dmg "https://github.com/openlink/iODBC/releases/download/v3.52.15/iODBC-SDK-3.52.15-macOS${MACOS_MAJOR_VER}.dmg"
}

function check_user_odbc_settings {
    
    # check to see if ODBC settings already exist

    if [[ -e ~/Library/ODBC/odbcinst.ini || -e  ~/Library/ODBC/odbc.ini ]]
    then
        warn "User ODBC settings exist"
        echo
        warn "contents of ~/Library/ODBC/odbcinst.ini"
        cat ~/Library/ODBC/odbcinst.ini || true
        echo
        warn "contents of ~/Library/ODBC/odbc.ini"
        cat ~/Library/ODBC/odbc.ini || true
        echo

        read -p "OK to replace User ODBC settings ? " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            REPLACE_ODBC=1
        else
            REPLACE_ODBC=0
        fi
    fi
}

function install_dsn {

    # install User DSN
    info "Installing ODBC User DSN"
    sudo mkdir -p /Library/ODBC/
    sudo mkdir -p ~/Library/ODBC/
    sudo chown -R "$(whoami)":staff ~/Library/ODBC/

    cat << EOF > ~/Library/ODBC/odbcinst.ini
[ODBC Drivers]
Simba Athena ODBC Driver 64-bit = Installed

[Simba Athena ODBC Driver 64-bit]
Driver=/Library/simba/athenaodbc/lib/libathenaodbc_sb64.dylib
Description=Simba Athena ODBC Driver (64-bit)
EOF

    cat << EOF > ~/Library/ODBC/odbc.ini
[ODBC Data Sources]
${CUSTOMER_ID} = Simba Athena ODBC Driver 64-bit

[${CUSTOMER_ID}]
Driver             = /Library/simba/athenaodbc/lib/libathenaodbc_sb64.dylib
Description        = ${CUSTOMER_ID}
S3OutputLocation   = s3://transfer-${CUSTOMER_ID_WITH_DASH}-athena-query-results-prod/queries/
AwsRegion          = eu-west-1
AuthenticationType = IAM Credentials
UID                = 
PWD                = 
EOF

    sudo chmod 644 ~/Library/ODBC/odbc*.ini
}

function test_odbc {

    # create test VRT
    TEST_VRT=~/Desktop/test-odbc-${CUSTOMER_ID}.vrt
    TEST_SQLLITE=~/Desktop/test-odbc-${CUSTOMER_ID}.sqlite
    TEST_SQL=~/Desktop/test-odbc-${CUSTOMER_ID}.sql

    cat << EOF > "${TEST_SQL}"
select
      id
    , timestamp_normalised
    , date_normalised
    , bearer_tech
    , radio_bearer_tech
    , meas_type
    , cell_info_dbm
    , cell_info_rsrq
    , throughput_kbps
    , throughput_direction
    , ping_avg_ms
    , data_error_code
    , site_identity
    , cgi
    , site_to_meas_distance_m
    , site_to_meas_bearing_deg
    , geom_tag_01
    , geom_tag_02
    , geom_tag_14
    , geom_tag_15
    , st_asbinary(st_point(lon, lat)) as geom
from meas.measurement_v007
where
        platform = 'Android'
    and radio_bearer_tech = 40
    and cell_info_dbm is not null
    and device_accuracy_horiz_m < 50

-- always filter on the date_normalised column as the Athena table is partitioned by this field
    and date_normalised >= date_add('week', -1, date_trunc('week', CURRENT_DATE))
    and date_normalised <  date_trunc('week', CURRENT_DATE)

-- only add order by if strictly necessary, as it will significantly slow down the query for large time spans
-- order by timestamp_normalised

-- limit for testing
limit 200;
EOF

    # when including the SQL, we need to escape special XML characters
    cat << EOF > "${TEST_VRT}"
<OGRVRTDataSource>
    <OGRVRTLayer name='meas'>
        <SrcDataSource relativeToVRT="0">ODBC:${AWS_KEY}/${AWS_SECRET}@${CUSTOMER_ID}</SrcDataSource>
        <SrcSQL>
$(xml esc < "${TEST_SQL}")
        </SrcSQL>
        <GeometryType>wkbPoint</GeometryType>
        <GeometryField encoding="WKB" field="geom"/>
        <LayerSRS>WGS84</LayerSRS>
    </OGRVRTLayer>
</OGRVRTDataSource>
EOF

    info "Testing VRT can connect to ODBC DSN to Athena"

    CMD=(ogrinfo "${TEST_VRT}" -so meas)
    info "Running: "
    info " ${CMD[*]}"
    info ""
    "${CMD[@]}"

    info ""
    info "Creating Spatialite version of VRT"
    CMD=(ogr2ogr -lco 'OVERWRITE=YES' "${TEST_SQLLITE}" "${TEST_VRT}")
    info "Running: "
    info " ${CMD[*]}"
    info ""
    "${CMD[@]}"

    info ""
    CMD=(ogrinfo "${TEST_SQLLITE}" -so meas)
    info "Running: "
    info " ${CMD[*]}"
    info ""
    "${CMD[@]}"
}

function launch_qgis {
    info "Launching QGIS with the test file"
    open /Applications/QGIS.app "${TEST_SQLLITE}" || true
}

function launch_odbc_admin {
    info "Launching iODBC Administrator64"
    open '/Applications/iODBC/iODBC Administrator64.app' || true
}
