# Test Library

This document provides the initial structure for a GitLab-based test library.

Each reusable test step is represented by a dedicated GitLab issue with a stable `TC-xxx` identifier.
The `TC-xxx` work items are the source of truth for the test library: they define the behavior, test data, expectations, and sequence of checks.
The execution layer implements these `TC-xxx` contracts and must stay aligned with the work-item description.
The Hero Case composes these `TC-xxx` building blocks into a red-line happy path for Open Data and Protected Data.
The same building blocks can also be combined into shorter feature-specific paths, for example `TC-001 -> TC-003 -> TC-007`.
Frontend-oriented `TC-xxx` items are shared between backend state setup and portal UI validation and therefore carry both `backend` and `frontend` labels in GitLab.
Geo-related `TC-xxx` items extend the Hero Case with geo persistence, OWS/WFS/WMS API configuration, and layer metadata. DataSpace and datapool behavior stays out of scope for this library.

## Purpose

- create traceability between automated tests and the managed test library
- make reusable test steps visible as governed test assets
- allow use cases to be assembled from existing library steps instead of redefining them
- support incremental growth of the test library as features are completed
- keep the happy-path composition readable in the Hero Case suite
- extend the Hero Case with geo persistence and WFS/WMS building blocks when those capabilities are added

## Naming Convention

- Identifier format: `TC-001`, `TC-002`, `TC-003`
- Issue title format: `TC-001 Create Data Structure`
- One library issue represents one atomic reusable test step
- A Hero Case composes multiple library issues in execution order

## Recommended GitLab Issue Structure

Use the following structure for each test library issue:

```md
# TC-001 Create Data Structure

## Purpose

Create a data structure for the use case.

## Preconditions

- System test run is initialized
- Valid authentication token is available

## Action

- Execute the reusable step to create the data structure

## Expected Result

- The API returns `201 Created`
- A data structure ID is returned
- The created resource can be retrieved afterwards

## Test Data

- data structure name: `Sensor Data Structure <runSuffix>`
- generated suffix source: `Initialize System Test Run`
- description: `Data structure for the hero-case system test`

## Notes

- Reused by multiple use cases
- Extended only if the shared system behavior changes
```

## Traceability Matrix

| ID | Layer | Title | Action | Expected Result |
| --- | --- | --- | --- | --- |
| `TC-001` | Backend | Create Data Structure | Create the data structure resource through the API. | Resource is created and an ID is returned. |
| `TC-002` | Backend | Verify Draft Data Structure Snapshot | Read back the draft data structure and inspect the payload. | Draft snapshot matches expected values. |
| `TC-003` | Backend | Create Data Structure Version | Create the first version for the data structure. | Version resource is created and linked to the structure. |
| `TC-004` | Backend | Verify Data Structure Version Snapshot | Read the created version and inspect the payload. | Version fields match the expected model metadata. |
| `TC-005` | Backend | Verify Data Structure References Created Version | Read the structure snapshot and verify the version reference. | Version ID is present in the structure snapshot. |
| `TC-006` | Backend | Release Data Structure Version | Release the created structure version. | Release call succeeds. |
| `TC-007` | Backend | Verify Data Structure Version Snapshot After Release | Read the released version again and inspect the payload. | Released version remains readable and consistent. |
| `TC-008` | Backend | Release Data Structure | Release the parent data structure. | Release call succeeds. |
| `TC-009` | Backend | Verify Released Data Structure Snapshot | Read the released structure and inspect the payload. | Structure is `AVAILABLE` and still references the version. |
| `TC-010` | Backend | Create Data Source | Create the data source resource through the API. | Resource is created and an ID is returned. |
| `TC-011` | Backend | Verify Draft Data Source Snapshot | Read the draft data source and inspect the payload. | Draft snapshot matches expected connector settings. |
| `TC-012` | Backend | Patch Data Source With Data Structure Version | Patch the datasource with the linked structure version. | Patch call succeeds. |
| `TC-013` | Backend | Verify Data Source References Data Structure Version | Read the datasource snapshot and inspect the version reference. | Data source snapshot contains the expected version ID. |
| `TC-014` | Backend | Release Data Source | Release the data source. | Release call succeeds. |
| `TC-015` | Backend | Verify Released Data Source Snapshot | Read the released data source and inspect the payload. | Data source is `AVAILABLE` and correctly configured. |
| `TC-016` | Backend and Frontend | Create Data Set | Open the dataset management view in the portal UI and create the dataset draft with the generated dataset name, description, open data access state, and named API metadata. | The dataset draft is saved in the portal UI. The generated dataset name and named API configuration remain visible in the browser. The browser stays on the dataset flow with the new dataset selected. |
| `TC-017` | Backend and Frontend | Verify Draft Data Set Snapshot | Open the dataset details page in the portal and inspect the draft snapshot rendered by the UI. | The portal shows the dataset in draft state. The access mode and named API settings match the expected values. The generated dataset name is visible in the browser. |
| `TC-018` | Backend | Create Pipeline | Create the pipeline resource through the API for the dataset and datasource that were prepared earlier. | The pipeline resource is created and linked to the dataset. The configured datasource, generator settings, and output target are persisted. |
| `TC-019` | Backend and Frontend | Verify Pipeline Snapshot | Open the pipeline details in the portal and inspect the rendered snapshot. | The portal shows the expected pipeline source and output configuration. The dataset linkage remains visible in the browser. The pipeline snapshot matches the configured frontend values. |
| `TC-020` | Backend and Frontend | Stage Data Set | Trigger dataset staging from the portal UI after the dataset and pipeline configuration have been saved successfully. | The portal confirms that staging has been started. The dataset remains visible in the browser while the staging transition runs. The UI can be used for the next status check. |
| `TC-021` | Backend and Frontend | Wait For Ready Data Set Status | Refresh or poll the dataset view in the portal until the status badge shows `READY`. | The portal shows `READY` within the configured timeout. The ready state is visible in the browser. The dataset can be used for the next frontend snapshot check. |
| `TC-022` | Backend and Frontend | Verify Ready Data Set Snapshot | Open the staged dataset details page in the portal and inspect the rendered snapshot. | The portal shows the dataset in `READY` state. No public route is exposed in the browser at this stage. The dataset remains in the staged state for release. |
| `TC-023` | Backend and Frontend | Release Data Set | Trigger dataset release from the portal UI after the ready state has been confirmed. | The portal confirms that release has been triggered. The released dataset remains visible in the browser. The dataset can continue into the availability check. |
| `TC-024` | Backend and Frontend | Wait For Available Data Set | Refresh or poll the dataset view in the portal until the status changes to `AVAILABLE`. | The portal shows `AVAILABLE` within the timeout. The public URL and route metadata are visible in the browser. The dataset is ready for the route snapshot verification. |
| `TC-025` | Backend and Frontend | Verify Available Data Set Snapshot | Open the available dataset details page in the portal and inspect the rendered snapshot. | The portal shows the dataset in `AVAILABLE` state. The public route metadata is visible in the browser. The snapshot matches the configured frontend values. |
| `TC-026` | Backend | Verify Anonymous Gateway Access | Send an anonymous gateway request and inspect the HTTP status code. | Anonymous request returns the expected status code for Open Data or Protected Data. |
| `TC-027` | Backend | Verify Anonymous Gateway Response Content | Send an anonymous gateway request and inspect the response body. | Response body contains the expected entity content. |
| `TC-028` | Backend | Verify Authenticated Gateway Access | Send an authenticated gateway request and inspect the HTTP status code. | Authenticated request returns `200`. |
| `TC-029` | Backend | Verify Authenticated Gateway Response Content | Send an authenticated gateway request and inspect the response body. | Response body contains the expected entity content. |
| `TC-030` | Backend | Verify Anonymous Gateway Rejection | Send an anonymous gateway request for protected data and inspect the HTTP status code. | Anonymous request returns `401`. |
| `TC-031` | Backend and Frontend | Change Data Set Access To Protected | Open the access settings for the released dataset in the portal and switch open data access off through the browser. | The portal shows protected access after the change. The dataset remains available in the browser. Anonymous access is no longer permitted. |
| `TC-032` | Backend | Create Geo Pipeline | Create the geo pipeline and persist a POSTGIS data sink that references the prepared data structure version. | The pipeline is created with a POSTGIS sink, the configured table name, and the expected data structure reference. |
| `TC-033` | Backend | Verify Geo Pipeline Snapshot | Read back the geo pipeline and inspect the stored POSTGIS sink configuration. | The pipeline snapshot contains the geo sink, table name, and data structure version summary. |
| `TC-034` | Backend | Create OWS API | Add the WFS/WMS named API to the dataset before release. | The dataset stores the OWS named API with slug `ows` and the expected base metadata. |
| `TC-035` | Backend and Frontend | Verify OWS API Snapshot | Refresh the dataset overview in the portal and open the OWS API card to inspect the base information snapshot. | The portal shows the WFS/WMS API card, the `ows` slug, and the PostGIS persistence choice. |
| `TC-036` | Backend | Create Geo Layer | Create the GeoServer layer for the POSTGIS sink. | The layer is stored with the selected table, geometry field, CRS, and layer metadata. |
| `TC-037` | Backend and Frontend | Verify Geo Layer Snapshot | Open the OWS API detail page in the portal and inspect the layer tab snapshot. | The portal shows the expected layer title, technical name, table, geometry field, and CRS. |
| `TC-038` | Backend | Create DataPool | Create the datapool resource through the API. | Resource is created and an ID is returned. |
| `TC-039` | Backend | Verify DataPool Snapshot | Read back the datapool and inspect the payload. | Snapshot matches name and description. |
| `TC-040` | Backend | Set DataSource Datapool Scope | Update the datasource with a SPECIFIC datapool scope referencing the created datapool. | DataSource is updated and datapoolScope reflects type SPECIFIC with the correct datapool ID. |
| `TC-041` | Backend | Verify DataSource Datapool Scope | Read the datasource and inspect the datapoolScope field. | datapoolScope type is SPECIFIC and contains the expected datapool ID. |
| `TC-042` | Backend | Assign DataSet To DataPool | Update the dataset with the datapool ID to place it under the datapool governance boundary. | Dataset is updated and the datapool summary is present in the response. |
| `TC-043` | Backend | Verify DataSet DataPool Assignment | Read the dataset and inspect the datapool field. | datapool summary contains the expected ID and name. |
| `TC-044` | Backend | Verify DataSources Filtered By DataPool | Query datasources filtered by the datapool ID. | The datasource scoped to the datapool appears in the result set. |

## Use In Planning

- create one GitLab issue per `TC-xxx` entry
- keep the identifier stable once assigned
- reference the `TC-xxx` issues from hero-case issues and epics
- add new `TC-xxx` entries only when a new reusable test step is introduced
- update existing `TC-xxx` entries when shared behavior changes
- compose Hero Case flows from multiple `TC-xxx` building blocks in the execution layer
- implement the keywords only after the corresponding `TC-xxx` work item is defined
