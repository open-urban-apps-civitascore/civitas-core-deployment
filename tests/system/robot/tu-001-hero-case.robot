*** Settings ***
Documentation     Hero case for dataset publication. The suite covers backend orchestration and frontend browser flows.
Resource          resources/dataset_api_publication.resource
Resource          resources/frontend_dataset_publication.resource

*** Test Cases ***
Hero Case - Open and Protected Data
    # Red line: create the backend prerequisites, then execute the browser-based dataset management flow,
    # validate the public route, switch to protected access, and confirm the rejection path.
    # Shorter feature paths can reuse subsets of the same blocks, for example:
    # TC-001 -> TC-003 -> TC-007

    Initialize System Test Run    suffix=open    openDataAccess=${TRUE}
    TC-038 Create Data Pool
    TC-039 Verify Data Pool Snapshot
    TC-001 Create Data Structure
    TC-002 Verify Draft Data Structure Snapshot
    TC-003 Create Data Structure Version
    TC-004 Verify Data Structure Version Snapshot
    TC-005 Verify Data Structure References Created Version
    TC-006 Release Data Structure Version
    TC-007 Verify Data Structure Version Snapshot After Release
    TC-008 Release Data Structure
    TC-009 Verify Released Data Structure Snapshot
    TC-010 Create Data Source
    TC-011 Verify Draft Data Source Snapshot
    TC-040 Set Data Source Datapool Scope
    TC-041 Verify Data Source Datapool Scope
    TC-044 Verify Data Sources Filtered By Data Pool
    TC-012 Patch Data Source With Data Structure Version
    TC-013 Verify Data Source References Data Structure Version
    TC-014 Release Data Source
    TC-015 Verify Released Data Source Snapshot
    TC-018 Create Pipeline

    Initialize Frontend Test Run
    TC-016 Create Data Set
    TC-017 Verify Draft Data Set Snapshot
    TC-042 Assign Data Set To Data Pool
    TC-043 Verify Data Set Data Pool Assignment
    TC-032 Create Geo Pipeline
    TC-033 Verify Geo Pipeline Snapshot
    TC-034 Create OWS API
    TC-036 Create Geo Layer
    TC-035 Verify OWS API Snapshot
    TC-037 Verify Geo Layer Snapshot
    TC-019 Verify Pipeline Snapshot
    TC-020 Stage Data Set
    TC-021 Wait For Ready Data Set Status
    TC-022 Verify Ready Data Set Snapshot
    TC-023 Release Data Set
    TC-024 Wait For Available Data Set
    TC-025 Verify Available Data Set Snapshot

    TC-026 Verify Anonymous Gateway Access    200
    TC-027 Verify Anonymous Gateway Response Content
    TC-028 Verify Authenticated Gateway Access    200
    TC-029 Verify Authenticated Gateway Response Content
    TC-031 Change Data Set Access To Protected
    TC-030 Verify Anonymous Gateway Rejection

    Cleanup Frontend Test Run
    Cleanup System Test Run
