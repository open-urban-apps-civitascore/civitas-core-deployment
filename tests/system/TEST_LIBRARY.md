# Test Library

This document provides the initial structure for a GitLab-based test library.

Each reusable test step is represented by a dedicated GitLab issue with a stable `TC-xxx` identifier.
The `TC-xxx` work items are the source of truth for the test library: they define the behavior, test data, expectations, and sequence of checks.
The execution layer implements these `TC-xxx` contracts and must stay aligned with the work-item description.
The Hero Case composes these `TC-xxx` building blocks into a red-line happy path for Open Data and Protected Data.
The same building blocks can also be combined into shorter feature-specific paths, for example `TC-001 -> TC-003 -> TC-007`.

## Purpose

- create traceability between automated tests and the managed test library
- make reusable test steps visible as governed test assets
- allow use cases to be assembled from existing library steps instead of redefining them
- support incremental growth of the test library as features are completed
- keep the happy-path composition readable in the Hero Case suite

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

| ID | Layer | Title | Purpose | Expected Result |
| --- | --- | --- | --- | --- |
| `TC-001` | Backend | Create Data Structure | Create the data structure resource | Resource is created and an ID is returned |
| `TC-002` | Backend | Verify Draft Data Structure Snapshot | Validate the initial data structure payload | Draft snapshot matches expected values |
| `TC-003` | Backend | Create Data Structure Version | Create the first version for the data structure | Version resource is created and linked to the structure |
| `TC-004` | Backend | Verify Data Structure Version Snapshot | Validate the version payload after creation | Version fields match the expected model metadata |
| `TC-005` | Backend | Verify Data Structure References Created Version | Confirm the structure references the created version | Version ID is present in the structure snapshot |
| `TC-006` | Backend | Release Data Structure Version | Release the created structure version | Release call succeeds |
| `TC-007` | Backend | Verify Data Structure Version Snapshot After Release | Re-read the released version | Released version remains readable and consistent |
| `TC-008` | Backend | Release Data Structure | Release the parent data structure | Release call succeeds |
| `TC-009` | Backend | Verify Released Data Structure Snapshot | Validate the released structure state | Structure is `AVAILABLE` and still references the version |
| `TC-010` | Backend | Create Data Source | Create the data source resource | Resource is created and an ID is returned |
| `TC-011` | Backend | Verify Draft Data Source Snapshot | Validate the draft data source payload | Draft snapshot matches expected connector settings |
| `TC-012` | Backend | Patch Data Source With Data Structure Version | Link the datasource to the structure version | Patch call succeeds |
| `TC-013` | Backend | Verify Data Source References Data Structure Version | Confirm the linked version on the datasource | Data source snapshot contains the expected version ID |
| `TC-014` | Backend | Release Data Source | Release the data source | Release call succeeds |
| `TC-015` | Backend | Verify Released Data Source Snapshot | Validate the released data source state | Data source is `AVAILABLE` and correctly configured |
| `TC-016` | Frontend | Create Data Set | Create the dataset resource | Resource is created and an ID is returned |
| `TC-017` | Frontend | Verify Draft Data Set Snapshot | Validate the draft dataset payload | Draft snapshot matches expected access and named API settings |
| `TC-018` | Frontend | Create Pipeline | Create the dataset pipeline | Pipeline resource is created and linked to the dataset |
| `TC-019` | Frontend | Verify Pipeline Snapshot | Validate the created pipeline payload | Pipeline snapshot matches expected source and output configuration |
| `TC-020` | Frontend | Stage Data Set | Stage the dataset for release | Stage call succeeds |
| `TC-021` | Frontend | Wait For Ready Data Set Status | Wait for the dataset to reach `READY` | Dataset reaches `READY` within the timeout |
| `TC-022` | Frontend | Verify Ready Data Set Snapshot | Validate the staged dataset snapshot | Dataset is `READY` and public routes are not exposed yet |
| `TC-023` | Frontend | Release Data Set | Release the dataset | Release call succeeds |
| `TC-024` | Frontend | Wait For Available Data Set | Wait for the released dataset to become available | Dataset reaches `AVAILABLE` and exposes public route metadata |
| `TC-025` | Frontend | Verify Available Data Set Snapshot | Validate the available dataset snapshot | Dataset is `AVAILABLE` and route metadata matches the expectation |
| `TC-026` | Backend | Verify Anonymous Gateway Access | Verify anonymous gateway access for Open Data or Protected Data | Anonymous request returns the expected status code for Open Data or Protected Data |
| `TC-027` | Backend | Verify Anonymous Gateway Response Content | Validate the open-data gateway payload | Response body contains the expected entity content |
| `TC-028` | Backend | Verify Authenticated Gateway Access | Verify authenticated gateway access | Authenticated request returns `200` |
| `TC-029` | Backend | Verify Authenticated Gateway Response Content | Validate the authenticated gateway payload | Response body contains the expected entity content |
| `TC-030` | Backend | Verify Anonymous Gateway Rejection | Verify restricted-data anonymous access is denied | Anonymous request returns `401` |
| `TC-031` | Frontend | Change Data Set Access To Protected | Change the released dataset from open access to protected access | Dataset is updated to protected access and the public route is no longer anonymously accessible |

## Use In Planning

- create one GitLab issue per `TC-xxx` entry
- keep the identifier stable once assigned
- reference the `TC-xxx` issues from hero-case issues and epics
- add new `TC-xxx` entries only when a new reusable test step is introduced
- update existing `TC-xxx` entries when shared behavior changes
- compose Hero Case flows from multiple `TC-xxx` building blocks in the execution layer
- implement the keywords only after the corresponding `TC-xxx` work item is defined
