# Connecting QGIS to the Ookla SpatialBuzz Athena Measurements Database

## Overview

As QGIS cannot directly connect to Athena databases, we recommend that a GDAL Virtual Dataset (VRT file) is used to act as a proxy to Athena via an ODBC database connection.

We recommended converting the VRT containing the dynamic query into a Spatialite database. This will force the download of the measurement data locally, and also gives the option of creating a spatial index to improve QGIS map viewing performance.

## Packages

The following packages will be installed if required:
* homebrew (GDAL, UnixODBC and XMLStarlet)
* XCode command line tools
* Simba Athena ODBC driver
* iODBC Administrator

**NOTE: This script will overwrite your User ODBC profile settings.**

## Installation

Open a terminal prompt and `cd` into the directory containing the installation files. Then run `./install.sh`

You will be prompted for:
* Customer ID e.g. demo_uk
* Your password
* Your Athena credentials

Please do not interact with the windows that briefly appear as the drivers are installed. 

## Connecting to Athena using a GDAL VRT file

At the end of the installation a test GDAL VRT file will be created in `~/Desktop/`. The VRT contains an SQL query to connect to Athena.

The VRT file is in XML format, so the SQL operators `>` and `<` must be escaped:

* replace `>` with `&gt;`
* replace `<` with `&lt;`

**Example VRT file**

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

During the installation, the test VRT is also converted to Spatialite (.sqlite) format and previewed using QGIS.

**Note: The VRT file contains your personal Athena credentials, so please keep that file secure.**
