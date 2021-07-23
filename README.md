# Connecting QGIS to the Ookla SpatialBuzz Athena Measurements Database

## Overview

As QGIS cannot directly connect to Athena databases, we recommend that a GDAL Virtual Dataset (VRT file) is used to act as a proxy to Athena via an ODBC database connection.

We recommended converting the VRT containing the dynamic query into a Spatialite database. This will force the download of the measurement data locally, and also creates a spatial index to improve QGIS map viewing performance.

## Packages

The following packages will be installed if required:
* homebrew (GDAL, UnixODBC and XMLStarlet)
* XCode command line tools
* Simba Athena ODBC driver
* iODBC Administrator

**NOTE: This script will overwrite your User ODBC profile settings.**

## Installation

Extract the release ZIP file into a folder. Open a terminal prompt and then `cd` into the directory containing the installation files. 

Run `./install.sh` to start the installation. 

You will be prompted for:
* Customer ID e.g. demo_uk (use an underscore rather than minus)
* Your password

The install may take some time. Please wait until the prompt confirms the installation has finished.

Please do not interact with the windows that briefly appear as the drivers are installed. 


## Verify Installation

Once the installation is complete, run `./test-odbc.sh` to confirm you can connect successfully to Athena and create the Spatialite point file.

You will be prompted for:
* Customer ID e.g. demo_uk (use an underscore rather than minus)
* Your Athena credentials

Once the `./test-odbc.sh` script has completed, three files will be created in `~/Desktop/`:
* `test-odbc-CUSTOMER_ID.sql` - example SQL file
* `test-odbc-CUSTOMER_ID.vrt` - GDAL virtual dataset file
* `test-odbc-CUSTOMER_ID.sqlite` - Spatialite point file

If QGIS is installed, the `test-odbc-CUSTOMER_ID.sqlite` file will be opened automatically.

**Note: The VRT file contains your personal Athena credentials, so please keep that file secure.**


## Creating a Spatialite file from an SQL file

You can create your own or modify the test SQL file to extract different columns and time periods from Athena.

Use the `./create_spatialite_from_sql.sh` command to perform all the steps involved.

For example:

```
./create_spatialite_from_sql.sh ~/Desktop/test-odbc-demo_uk.sql

💬 INFO: Enter the Customer ID e.g. demo_uk
Customer ID: demo_uk

💬 INFO: Enter the Amazon Athena credentials for customer demo_uk
Access Key: AKIAxxxxxxxxxxxxxxxx
Secret Key:

💬 INFO: Testing VRT can connect to ODBC DSN to Athena
💬 INFO: Running:
💬 INFO:  ogrinfo /Users/fred/Desktop/test-odbc-demo_uk.vrt -so meas
💬 INFO:
INFO: Open of `/Users/fred/Desktop/test-odbc-demo_uk.vrt'
      using driver `OGR_VRT' successful.

Layer name: meas
Geometry: Point
Feature Count: 200

...

💬 INFO:
💬 INFO: Creating Spatialite version of VRT
💬 INFO: Running:
💬 INFO:  ogr2ogr -f SQLite -lco OVERWRITE=YES -nln meas -lco SPATIAL_INDEX=YES -dsco SPATIALITE=YES -gt 65536 /Users/fred/Desktop/test-odbc-demo_uk.sqlite /Users/fred/Desktop/test-odbc-demo_uk.vrt
💬 INFO:
💬 INFO:
💬 INFO: Testing Spatialite file
💬 INFO: Running:
💬 INFO:  ogrinfo /Users/fred/Desktop/test-odbc-demo_uk.sqlite -so meas
💬 INFO:
INFO: Open of `/Users/fred/Desktop/test-odbc-demo_uk.sqlite'
      using driver `SQLite' successful.

Layer name: meas
Geometry: Point
Feature Count: 200

...

💬 INFO: Created: /Users/fred/Desktop/test-odbc-demo_uk.vrt
💬 INFO: Created: /Users/fred/Desktop/test-odbc-demo_uk.sqlite

```

## Manually creating a Spatialite file

The following example shows the command line arguments to `ogr2ogr` to convert a VRT to Spatialite format.  

`ogr2ogr -f SQLite -lco OVERWRITE=YES -nln meas -lco SPATIAL_INDEX=YES -dsco SPATIALITE=YES -gt 65536 /Users/fred/Desktop/test-odbc-demo_uk.sqlite /Users/fred/Desktop/test-odbc-demo_uk.vrt`

Note: the VRT file is in XML format and contains the Athena SQL query. 

Your SQL query may contain forbidden XML characters and so must be escaped. The `create_spatialite_from_sql.sh` script handles that escaping automatically for you, but if you prefer to edit that file directly, you must replace the following characters:

* `>` with `&gt;`
* `<` with `&lt;`

**Example SQL escaped within a VRT file**

```
<OGRVRTDataSource>
    <OGRVRTLayer name='Measurements'>
        <SrcDataSource relativeToVRT="0">ODBC:AWS_ACCESS_KEY/AWS_SECRET_KEY@USER_DSN_NAME</SrcDataSource>
        <SrcSQL>
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
    and device_accuracy_horiz_m &lt; 50

-- always filter on the date_normalised column as the Athena table is partitioned by this field
    and date_normalised &gt;= date_add('week', -1, date_trunc('week', CURRENT_DATE))
    and date_normalised &lt;  date_trunc('week', CURRENT_DATE)

-- only add order by if strictly necessary, as it will significantly slow down the query for large time spans
-- order by timestamp_normalised

-- limit for testing
limit 200;
        </SrcSQL>
        <GeometryType>wkbPoint</GeometryType>
        <GeometryField encoding="WKB" field="geom"/>
        <LayerSRS>WGS84</LayerSRS>
    </OGRVRTLayer>
</OGRVRTDataSource>
```
