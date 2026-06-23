*** Settings ***
Documentation     Browser-based frontend execution library for the dataset API publication Hero Case.
Library           Browser

*** Variables ***
${PORTAL_FRONTEND_URL}           %{PORTAL_FRONTEND_URL=http://localhost:3000}
${SYSTEM_TEST_AUTH_USER}         %{SYSTEM_TEST_AUTH_USER=dev@civitas.local}
${SYSTEM_TEST_AUTH_PASSWORD}     %{SYSTEM_TEST_AUTH_PASSWORD=dev123}

${DATASETS_LINK}                 role=link[name="Datasets"]
${CREATE_DATASET_BUTTON}         role=button[name="Create dataset"]
${DATASET_NAME_FIELD}            label=Name
${DATASET_DESCRIPTION_FIELD}     label=Description
${OPEN_DATA_ACCESS_TOGGLE}       label=Open data access
${NAMED_API_NAME_FIELD}          label=API name
${NAMED_API_SLUG_FIELD}          label=Slug
${NAMED_API_STANDARD_FIELD}      label=Standard
${NAMED_API_VERSION_FIELD}       label=Version
${SAVE_BUTTON}                   role=button[name="Save"]
${STAGE_BUTTON}                  role=button[name="Stage"]
${RELEASE_BUTTON}                role=button[name="Release"]
${ACCESS_SETTINGS_TAB}           role=tab[name="Access"]
${PIPELINE_TAB}                  role=tab[name="Pipeline"]
${OWS_API_CARD}                  css=[data-testid="apiCard-ows"]
${FRONTEND_GEO_API_NAME}         %{FRONTEND_GEO_API_NAME=WFS/WMS API}
${FRONTEND_GEO_API_SLUG}         %{FRONTEND_GEO_API_SLUG=ows}
${FRONTEND_GEO_PIPELINE_NAME}    %{FRONTEND_GEO_PIPELINE_NAME=Saga Geo Pipeline}
${FRONTEND_GEO_TABLE_NAME}       %{FRONTEND_GEO_TABLE_NAME=geo_data}
${FRONTEND_GEO_LAYER_NAME}       %{FRONTEND_GEO_LAYER_NAME=geo_layer}
${FRONTEND_GEO_LAYER_TITLE}      %{FRONTEND_GEO_LAYER_TITLE=Geo Layer}
${FRONTEND_GEO_LAYER_DESCRIPTION}    %{FRONTEND_GEO_LAYER_DESCRIPTION=Geo layer for the system test proof of concept}
${FRONTEND_GEO_LAYER_ATTRIBUTE}  %{FRONTEND_GEO_LAYER_ATTRIBUTE=value}
${FRONTEND_GEO_LAYER_GEOMETRY_COLUMN_REF}    %{FRONTEND_GEO_LAYER_GEOMETRY_COLUMN_REF=value}
${FRONTEND_GEO_LAYER_CRS}        %{FRONTEND_GEO_LAYER_CRS=EPSG:4326}

*** Keywords ***
Initialize Frontend Test Run
    New Browser    chromium    headless=True
    New Context    viewport={'width': 1600, 'height': 1200}
    New Page    ${PORTAL_FRONTEND_URL}
    Wait For Load State    networkidle
    Prepare Frontend Test Data
    Login To Portal

Cleanup Frontend Test Run
    Close Browser

Prepare Frontend Test Data
    ${data_set_name}=    Get Generated Data Set Name
    ${data_set_description}=    Set Variable    Dataset for the system test proof of concept
    ${pipeline_name}=    Get Generated Pipeline Name
    ${data_source_name}=    Get Generated Data Source Name
    ${named_api_slug}=    Get Named API Slug
    ${gateway_thing_name}=    Get Expected Gateway Thing Name
    ${gateway_thing_description}=    Get Expected Gateway Thing Description
    ${geo_api_name}=    Get Generated OWS API Name
    ${geo_api_slug}=    Get Generated OWS API Slug
    ${geo_pipeline_name}=    Get Generated Geo Pipeline Name
    ${geo_table_name}=    Get Generated Geo Data Sink Table Name
    ${geo_layer_name}=    Get Generated Geo Layer Name
    ${geo_layer_title}=    Get Generated Geo Layer Title
    ${geo_layer_description}=    Get Generated Geo Layer Description
    ${geo_layer_attribute}=    Get Generated Geo Layer Attribute
    ${geo_layer_geometry_column_ref}=    Get Generated Geo Layer Geometry Column Ref
    ${geo_layer_crs}=    Get Generated Geo Layer CRS
    Set Suite Variable    ${FRONTEND_DATA_SET_NAME}    ${data_set_name}
    Set Suite Variable    ${FRONTEND_DATA_SET_DESCRIPTION}    ${data_set_description}
    Set Suite Variable    ${FRONTEND_PIPELINE_NAME}    ${pipeline_name}
    Set Suite Variable    ${FRONTEND_DATA_SOURCE_NAME}    ${data_source_name}
    Set Suite Variable    ${FRONTEND_NAMED_API_SLUG}    ${named_api_slug}
    Set Suite Variable    ${FRONTEND_GATEWAY_THING_NAME}    ${gateway_thing_name}
    Set Suite Variable    ${FRONTEND_GATEWAY_THING_DESCRIPTION}    ${gateway_thing_description}
    Set Suite Variable    ${FRONTEND_GEO_API_NAME}    ${geo_api_name}
    Set Suite Variable    ${FRONTEND_GEO_API_SLUG}    ${geo_api_slug}
    Set Suite Variable    ${FRONTEND_GEO_PIPELINE_NAME}    ${geo_pipeline_name}
    Set Suite Variable    ${FRONTEND_GEO_TABLE_NAME}    ${geo_table_name}
    Set Suite Variable    ${FRONTEND_GEO_LAYER_NAME}    ${geo_layer_name}
    Set Suite Variable    ${FRONTEND_GEO_LAYER_TITLE}    ${geo_layer_title}
    Set Suite Variable    ${FRONTEND_GEO_LAYER_DESCRIPTION}    ${geo_layer_description}
    Set Suite Variable    ${FRONTEND_GEO_LAYER_ATTRIBUTE}    ${geo_layer_attribute}
    Set Suite Variable    ${FRONTEND_GEO_LAYER_GEOMETRY_COLUMN_REF}    ${geo_layer_geometry_column_ref}
    Set Suite Variable    ${FRONTEND_GEO_LAYER_CRS}    ${geo_layer_crs}

Login To Portal
    Go To    ${PORTAL_FRONTEND_URL}/datasets
    Wait For Load State    networkidle
    Run Keyword And Ignore Error    Click    role=link[name="Login"]
    Run Keyword And Ignore Error    Click    role=button[name="Login"]
    ${login_visible}=    Run Keyword And Return Status    Wait For Elements State    css=input[name="username"]    visible    timeout=10s
    IF    ${login_visible}
        Fill Text    css=input[name="username"]    ${SYSTEM_TEST_AUTH_USER}
        Fill Text    css=input[name="password"]    ${SYSTEM_TEST_AUTH_PASSWORD}
        Click    css=button[type="submit"]
        Wait For Load State    networkidle
    END
    Wait For Elements State    ${DATASETS_LINK}    visible    timeout=30s

Open Data Sets Management
    Click    ${DATASETS_LINK}
    Wait For Load State    networkidle

Open Create Data Set Form
    Open Data Sets Management
    Click    ${CREATE_DATASET_BUTTON}
    Wait For Load State    networkidle

Fill Data Set Form
    Fill Text    ${DATASET_NAME_FIELD}    ${FRONTEND_DATA_SET_NAME}
    Fill Text    ${DATASET_DESCRIPTION_FIELD}    ${FRONTEND_DATA_SET_DESCRIPTION}
    Check Checkbox    ${OPEN_DATA_ACCESS_TOGGLE}
    Fill Text    ${NAMED_API_NAME_FIELD}    Things
    Fill Text    ${NAMED_API_SLUG_FIELD}    ${FRONTEND_NAMED_API_SLUG}
    Fill Text    ${NAMED_API_STANDARD_FIELD}    STA
    Fill Text    ${NAMED_API_VERSION_FIELD}    1.1

Save Form
    Click    ${SAVE_BUTTON}
    Wait For Load State    networkidle

Assert Data Set Draft Snapshot
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${FRONTEND_DATA_SET_NAME}
    Should Contain    ${body}    ${FRONTEND_DATA_SET_DESCRIPTION}
    Should Contain    ${body}    Things
    Should Contain    ${body}    ${FRONTEND_NAMED_API_SLUG}
    Should Contain    ${body}    STA
    Should Contain    ${body}    1.1

Open Pipeline Management
    Click    ${PIPELINE_TAB}
    Wait For Load State    networkidle

Fill Pipeline Form
    Fill Text    label=Name    ${FRONTEND_PIPELINE_NAME}
    Fill Text    label=Description    Robot/Java system test proof of concept
    Fill Text    label=Output URL    http://frost-frost-frost-server-http.frost/FROST-Server/v1.1/Things
    Fill Text    label=Generation interval    1s
    Fill Text    label=Generation count    1
    Fill Text    label=Thing name    ${FRONTEND_GATEWAY_THING_NAME}
    Fill Text    label=Thing description    ${FRONTEND_GATEWAY_THING_DESCRIPTION}

Assert Pipeline Snapshot
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${FRONTEND_PIPELINE_NAME}
    Should Contain    ${body}    ${FRONTEND_DATA_SOURCE_NAME}
    Should Contain    ${body}    ${FRONTEND_GATEWAY_THING_NAME}
    Should Contain    ${body}    ${FRONTEND_GATEWAY_THING_DESCRIPTION}

Verify OWS API Snapshot
    Reload Page
    Wait For Load State    networkidle
    Wait For Elements State    ${OWS_API_CARD}    visible    timeout=30s
    Click    ${OWS_API_CARD}
    Wait For Load State    networkidle
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${FRONTEND_GEO_API_NAME}
    Should Contain    ${body}    ${FRONTEND_GEO_API_SLUG}
    Should Contain    ${body}    PostGIS Geo Persistence
    Go Back
    Wait For Load State    networkidle

Verify Geo Layer Snapshot
    Reload Page
    Wait For Load State    networkidle
    Wait For Elements State    ${OWS_API_CARD}    visible    timeout=30s
    Click    ${OWS_API_CARD}
    Wait For Load State    networkidle
    Click    role=tab[name="Layer"]
    Wait For Load State    networkidle
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${FRONTEND_GEO_LAYER_TITLE}
    Should Contain    ${body}    ${FRONTEND_GEO_LAYER_NAME}
    Should Contain    ${body}    ${FRONTEND_GEO_TABLE_NAME}
    Should Contain    ${body}    ${FRONTEND_GEO_LAYER_ATTRIBUTE}
    Should Contain    ${body}    ${FRONTEND_GEO_LAYER_GEOMETRY_COLUMN_REF}
    Should Contain    ${body}    ${FRONTEND_GEO_LAYER_CRS}
    Go Back
    Wait For Load State    networkidle

Stage Data Set In UI
    Click    ${STAGE_BUTTON}
    Wait For Load State    networkidle

Wait For Ready Data Set Status In UI
    Wait Until Keyword Succeeds    2 min    5 sec    Assert Data Set Status    READY

Assert Ready Data Set Snapshot
    Assert Data Set Status    READY
    ${body}=    Get Text    css=body
    Should Not Contain    ${body}    Public URL
    Should Not Contain    ${body}    Named API route

Release Data Set In UI
    Click    ${RELEASE_BUTTON}
    Wait For Load State    networkidle

Wait For Available Data Set Status In UI
    Wait Until Keyword Succeeds    3 min    5 sec    Assert Data Set Status    AVAILABLE

Assert Available Data Set Snapshot
    Assert Data Set Status    AVAILABLE
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${FRONTEND_DATA_SET_NAME}
    Should Contain    ${body}    Things
    Should Contain    ${body}    Public URL

Change Data Set Access To Protected In UI
    Click    ${ACCESS_SETTINGS_TAB}
    Wait For Load State    networkidle
    Uncheck Checkbox    ${OPEN_DATA_ACCESS_TOGGLE}
    Click    ${SAVE_BUTTON}
    Wait For Load State    networkidle
    ${body}=    Get Text    css=body
    Should Contain    ${body}    Protected

Assert Data Set Status
    [Arguments]    ${expected_status}
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${expected_status}

TC-016 Create Data Set
    Open Create Data Set Form
    Fill Data Set Form
    Save Form
    Assert Data Set Draft Snapshot

TC-017 Verify Draft Data Set Snapshot
    Assert Data Set Draft Snapshot

TC-019 Verify Pipeline Snapshot
    Open Pipeline Management
    Assert Pipeline Snapshot

TC-020 Stage Data Set
    Stage Data Set In UI

TC-021 Wait For Ready Data Set Status
    Wait For Ready Data Set Status In UI

TC-022 Verify Ready Data Set Snapshot
    Assert Ready Data Set Snapshot

TC-023 Release Data Set
    Release Data Set In UI

TC-024 Wait For Available Data Set
    Wait For Available Data Set Status In UI

TC-025 Verify Available Data Set Snapshot
    Assert Available Data Set Snapshot

TC-031 Change Data Set Access To Protected
    Change Data Set Access To Protected In UI

TC-035 Verify OWS API Snapshot
    Verify OWS API Snapshot

TC-037 Verify Geo Layer Snapshot
    Verify Geo Layer Snapshot
