# System Test Library

This document provides the initial structure for a GitLab-based system test library.

Each reusable test step is represented by a dedicated GitLab issue with a stable `TB-xxx` identifier.
The Robot Framework suites reference these identifiers directly in the test case names.

## Purpose

- create traceability between automated system tests and the managed test library
- make reusable system-test steps visible as governed test assets
- allow use cases to be assembled from existing library steps instead of redefining them
- support incremental growth of the test library as features are completed

## Naming Convention

- Identifier format: `TB-001`, `TB-002`, `TB-003`
- Issue title format: `TB-001 Create Data Structure`
- One library issue represents one reusable system-test step
- One Robot test case maps to one library issue

## Recommended GitLab Issue Structure

Use the following structure for each test library issue:

```md
# TB-001 Create Data Structure

## Purpose

Create a data structure for the system-test use case.

## Preconditions

- System test run is initialized
- Valid authentication token is available

## Action

- Execute the reusable step to create the data structure

## Expected Result

- The API returns `201 Created`
- A data structure ID is returned
- The created resource can be retrieved afterwards

## Robot Mapping

- Suite: `open_data_dataset_saga_publication.robot`
- Suite: `restricted_data_dataset_saga_publication.robot`
- Test case: `TB-001 Create Data Structure`

## Notes

- Reused by multiple use cases
- Extended only if the shared system behavior changes
```

## Traceability Matrix

| ID | Title | Purpose | Expected Result | Robot Mapping |
| --- | --- | --- | --- | --- |
| `TB-001` | Create Data Structure | Create the data structure resource | Resource is created and an ID is returned | open, restricted |
| `TB-002` | Verify Draft Data Structure Snapshot | Validate the initial data structure payload | Draft snapshot matches expected values | open, restricted |
| `TB-003` | Create Data Structure Version | Create the first version for the data structure | Version resource is created and linked to the structure | open, restricted |
| `TB-004` | Verify Data Structure Version Snapshot | Validate the version payload after creation | Version fields match the expected model metadata | open, restricted |
| `TB-005` | Verify Data Structure References Created Version | Confirm the structure references the created version | Version ID is present in the structure snapshot | open, restricted |
| `TB-006` | Release Data Structure Version | Release the created structure version | Release call succeeds | open, restricted |
| `TB-007` | Verify Data Structure Version Snapshot After Release | Re-read the released version | Released version remains readable and consistent | open, restricted |
| `TB-008` | Release Data Structure | Release the parent data structure | Release call succeeds | open, restricted |
| `TB-009` | Verify Released Data Structure Snapshot | Validate the released structure state | Structure is `AVAILABLE` and still references the version | open, restricted |
| `TB-010` | Create Data Source | Create the data source resource | Resource is created and an ID is returned | open, restricted |
| `TB-011` | Verify Draft Data Source Snapshot | Validate the draft data source payload | Draft snapshot matches expected connector settings | open, restricted |
| `TB-012` | Patch Data Source With Data Structure Version | Link the datasource to the structure version | Patch call succeeds | open, restricted |
| `TB-013` | Verify Data Source References Data Structure Version | Confirm the linked version on the datasource | Data source snapshot contains the expected version ID | open, restricted |
| `TB-014` | Release Data Source | Release the data source | Release call succeeds | open, restricted |
| `TB-015` | Verify Released Data Source Snapshot | Validate the released data source state | Data source is `AVAILABLE` and correctly configured | open, restricted |
| `TB-016` | Create Data Set | Create the dataset resource | Resource is created and an ID is returned | open, restricted |
| `TB-017` | Verify Draft Data Set Snapshot | Validate the draft dataset payload | Draft snapshot matches expected access and named API settings | open, restricted |
| `TB-018` | Create Pipeline | Create the dataset pipeline | Pipeline resource is created and linked to the dataset | open, restricted |
| `TB-019` | Verify Pipeline Snapshot | Validate the created pipeline payload | Pipeline snapshot matches expected source and output configuration | open, restricted |
| `TB-020` | Stage Data Set | Stage the dataset for release | Stage call succeeds | open, restricted |
| `TB-021` | Wait For Ready Data Set Status | Wait for the dataset to reach `READY` | Dataset reaches `READY` within the timeout | open, restricted |
| `TB-022` | Verify Ready Data Set Snapshot | Validate the staged dataset snapshot | Dataset is `READY` and public routes are not exposed yet | open, restricted |
| `TB-023` | Release Data Set | Release the dataset | Release call succeeds | open, restricted |
| `TB-024` | Wait For Available Data Set | Wait for the released dataset to become available | Dataset reaches `AVAILABLE` and exposes public route metadata | open, restricted |
| `TB-025` | Verify Available Data Set Snapshot | Validate the available dataset snapshot | Dataset is `AVAILABLE` and route metadata matches the expectation | open, restricted |
| `TB-026` | Verify Anonymous Gateway Access | Verify open-data anonymous access | Anonymous request returns `200` | open |
| `TB-027` | Verify Anonymous Gateway Response Content | Validate the open-data gateway payload | Response body contains the expected entity content | open |
| `TB-028` | Verify Authenticated Gateway Access | Verify authenticated gateway access | Authenticated request returns `200` | open, restricted |
| `TB-029` | Verify Authenticated Gateway Response Content | Validate the authenticated gateway payload | Response body contains the expected entity content | open, restricted |
| `TB-030` | Verify Anonymous Gateway Rejection | Verify restricted-data anonymous access is denied | Anonymous request returns `401` | restricted |

## Use In Planning

- create one GitLab issue per `TB-xxx` entry
- keep the identifier stable once assigned
- reference the `TB-xxx` issues from use-case issues and epics
- add new `TB-xxx` entries only when a new reusable system-test step is introduced
- update existing `TB-xxx` entries when shared behavior changes
