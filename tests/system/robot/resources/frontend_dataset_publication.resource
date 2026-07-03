*** Settings ***
Documentation     Browser-based frontend execution library for the dataset API publication Hero Case.
Library           Browser
Resource          ../ui_common.resource

*** Variables ***
${OUR_DATA_SIDEBAR_ITEM}         role=button[name="Unsere Daten"]
${DATASETS_LINK}                 css=[data-testid="sidebarMenuItem-datasets"]
${CREATE_DATASET_BUTTON}         css=[data-testid="addDatasetButton"]
${DATASET_CREATE_FORM}           css=[data-testid="datasetCreateForm"]
${DATASET_NAME_FIELD}            css=[data-testid="datasetCreateForm"] input[name="name"]
${DATASET_DESCRIPTION_FIELD}     css=[data-testid="datasetBaseInfoForm"] textarea[name="description"]
${OPEN_DATA_ACCESS_CHECKBOX}       role=checkbox[name="Open Data"]
${API_CREATE_BUTTON}             role=button[name="API hinzufügen"]
${STA_API_CREATE_BUTTON}         css=a[href*="type=sensorthings"]
${API_CONFIG_FORM}               css=[data-testid="apiConfigForm"]
${NAMED_API_NAME_FIELD}          css=[data-testid="apiConfigForm"] input[name="baseInfo.name"]
${NAMED_API_SLUG_FIELD}          css=[data-testid="apiConfigForm"] input[name="baseInfo.slug"]
${LAYER_TAB}                     role=tab[name="Layer"]
${LAYER_HEADING}                 role=heading[name="Layer"]
${LAYER_CONFIG_TITLE_FIELD}      css=[data-testid="layers.0.titleTextField"]
${LAYER_CONFIG_NAME_FIELD}       css=[data-testid="layers.0.layerNameTextField"]
${LAYER_CONFIG_TABLE_FIELD}      css=[data-testid="layers.0.dataSinkIdSelectTrigger"]
${LAYER_CONFIG_ATTRIBUTE_FIELD}  css=[data-slot="combobox-chips"]:has(#layerAttribute)
${LAYER_CONFIG_GEOMETRY_COLUMN_FIELD}     css=[data-testid="layers.0.geometryColumnRefSelectTrigger"]
${LAYER_CONFIG_CRS_FIELD}                 css=[data-testid="layers.0.crsSelectTrigger"]
${SAVE_AND_CONTINUE_BUTTON}      role=button[name="Erstellen und weiter"]
${BACK_BUTTON}                   role=button[name="Zurück"]
${EDIT_BUTTON}                   css=[data-testid="editButton"]
${SAVE_BUTTON}                   role=button[name="Speichern"]
${STATUS_BUTTON}                 css=[data-testid="statusDropdown"]
${READY_BUTTON}                  role=menuitem[name="Fertig"]
${RELEASE_BUTTON}                role=button[name="Release"]
${ACCESS_SETTINGS_TAB}           role=tab[name="Access"]
${PIPELINE_LINK}                 role=link[name="Saga Pipeline open"]
${PIPELINE_TAB}                  text="Saga Pipeline open"
${GEO_PIPELINE_LINK}             role=link[name="Saga Geo Pipeline open"]
${GEO_PIPELINE_TAB}              text="Saga Geo Pipeline open"
${PIPELINE_CANVAS}               css=.react-flow__pane
${PIPELINE_DATASOURCE_NODE}      css=.react-flow__node-dataSource
${PIPELINE_MAPPING_NODE}         css=.react-flow__node-mapping
${PIPELINE_FROST_NODE}           css=.react-flow__node-frost
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
    New Page    ${PORTAL_URL}
    Wait For Load State    networkidle
    Prepare Frontend Test Data
    Resolve Auth Credentials
    Login Via Keycloak    ${KEYCLOAK_USERNAME}    ${KEYCLOAK_PASSWORD}

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

Open Data Sets Management
    Click    ${OUR_DATA_SIDEBAR_ITEM}
    Wait For Elements State    css=[data-testid="sidebarMenuItem-datasets"]    visible    timeout=10s
    Click    ${DATASETS_LINK}
    Wait For Load State    networkidle

Open Create Data Set Form
    Open Data Sets Management
    Click    ${CREATE_DATASET_BUTTON}
    Wait For Elements State    ${DATASET_CREATE_FORM}    visible    timeout=15s

Create Dataset
    Fill Text    ${DATASET_NAME_FIELD}    ${FRONTEND_DATA_SET_NAME}
    Click        ${SAVE_AND_CONTINUE_BUTTON}
    Wait For Elements State    ${DATASET_DESCRIPTION_FIELD}   visible     timeout=15s

Fill Data Set Form
    Fill Text    ${DATASET_DESCRIPTION_FIELD}    ${FRONTEND_DATA_SET_DESCRIPTION}
    Check Checkbox    ${OPEN_DATA_ACCESS_CHECKBOX}
    Click    ${SAVE_BUTTON}
    Verify Success toast

Create STA API
    Click    ${API_CREATE_BUTTON}
    Click    ${STA_API_CREATE_BUTTON}
    Wait For Elements State    ${API_CONFIG_FORM}   visible     timeout=15s
    Fill Text    ${NAMED_API_NAME_FIELD}    Things
    Fill Text    ${NAMED_API_SLUG_FIELD}    ${FRONTEND_NAMED_API_SLUG}
    Click    ${SAVE_BUTTON}
    Wait For Condition    Url    contains    mode=edit    timeout=15s

Save Form
    Click    ${SAVE_BUTTON}
    Verify Success toast

Go Back
    Click   ${BACK_BUTTON}
    Wait For Load State    networkidle

Assert Data Set Draft Snapshot
    Assert Data Set Status      Entwurf
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${FRONTEND_DATA_SET_NAME}
    Should Contain    ${body}    Things
    Get Attribute    ${OPEN_DATA_ACCESS_CHECKBOX}    aria-checked    ==    true

Open Pipeline Management
    Click    ${PIPELINE_LINK}
    Wait For Elements State    ${PIPELINE_CANVAS}       visible     timeout=15s

Fill Pipeline Form
    Fill Text    label=Name    ${FRONTEND_PIPELINE_NAME}
    Fill Text    label=Description    Robot/Java system test proof of concept
    Fill Text    label=Output URL    http://frost-frost-frost-server-http.frost/FROST-Server/v1.1/Things
    Fill Text    label=Generation interval    1s
    Fill Text    label=Generation count    1
    Fill Text    label=Thing name    ${FRONTEND_GATEWAY_THING_NAME}
    Fill Text    label=Thing description    ${FRONTEND_GATEWAY_THING_DESCRIPTION}

Assert Pipeline Snapshot
    Get Text    css=body    contains    ${FRONTEND_PIPELINE_NAME}
    Get Text    ${PIPELINE_DATASOURCE_NODE}    contains    ${FRONTEND_DATA_SOURCE_NAME}
    Get Text    ${PIPELINE_MAPPING_NODE}    contains    Mapping
    Get Text    ${PIPELINE_FROST_NODE}    contains    Frost Server

Verify OWS API Snapshot
    Reload
    Wait For Elements State    ${OWS_API_CARD}    visible    timeout=15s
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${FRONTEND_GEO_API_NAME}
    Should Contain    ${body}    ${FRONTEND_GEO_API_SLUG}
    Click    ${OWS_API_CARD}
    Wait For Elements State     ${API_CONFIG_FORM}      visible     timeout=15s
    ${body}=    Get Text    css=body
    Should Contain    ${body}    ${FRONTEND_GEO_API_NAME}
    Should Contain    ${body}    ${FRONTEND_GEO_API_SLUG}

Verify Geo Layer Snapshot
    Reload
    Wait For Elements State    ${API_CONFIG_FORM}    visible    timeout=30s
    Click    ${LAYER_TAB}
    Wait For Elements State    ${LAYER_HEADING}    visible    timeout=30s
    # Text inputs: read the field value. Selects/combobox: the selection is rendered as visible text.
    Get Property    ${LAYER_CONFIG_TITLE_FIELD}              value       ==          ${FRONTEND_GEO_LAYER_TITLE}
    Get Property    ${LAYER_CONFIG_NAME_FIELD}              value       ==          ${FRONTEND_GEO_LAYER_NAME}
    Get Text        ${LAYER_CONFIG_TABLE_FIELD}                         contains    ${FRONTEND_GEO_TABLE_NAME}
    Get Text        ${LAYER_CONFIG_ATTRIBUTE_FIELD}                     contains    ${FRONTEND_GEO_LAYER_ATTRIBUTE}
    Get Text        ${LAYER_CONFIG_GEOMETRY_COLUMN_FIELD}               contains    ${FRONTEND_GEO_LAYER_GEOMETRY_COLUMN_REF}
    Get Text        ${LAYER_CONFIG_CRS_FIELD}                           contains    ${FRONTEND_GEO_LAYER_CRS}
    Go Back
    Wait For Load State    networkidle

Stage Data Set In UI
    Navigate via Breadcrumbs       ${FRONTEND_DATA_SET_NAME}
    Click    ${EDIT_BUTTON}
    Click    ${STATUS_BUTTON}
    Click    ${READY_BUTTON}
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
    Uncheck Checkbox    ${OPEN_DATA_ACCESS_CHECKBOX}
    Click    ${SAVE_BUTTON}
    Wait For Load State    networkidle
    ${body}=    Get Text    css=body
    Should Contain    ${body}    Protected

Assert Data Set Status
    [Arguments]    ${expected_status}
    Assert Status    ${expected_status}

TC-016 Create Data Set
    Open Create Data Set Form
    Create Dataset
    Fill Data Set Form
    Create STA API
    Navigate via Breadcrumbs       ${FRONTEND_DATA_SET_NAME}

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
