*** Settings ***
Documentation     Restricted-data dataset publication flow. Each test case maps to a GitLab test library issue via its TB identifier.
Library           Remote    ${REMOTE_URL}
Suite Setup       Initialize System Test Run    suffix=restricted    openDataAccess=${FALSE}
Suite Teardown    Cleanup System Test Run

*** Test Cases ***
TB-001 Create Data Structure
    Create Data Structure

TB-002 Verify Draft Data Structure Snapshot
    Verify Data Structure Snapshot    DRAFT    ${FALSE}

TB-003 Create Data Structure Version
    Create Data Structure Version

TB-004 Verify Data Structure Version Snapshot
    Verify Data Structure Version Snapshot

TB-005 Verify Data Structure References Created Version
    Verify Data Structure Snapshot    DRAFT    ${TRUE}

TB-006 Release Data Structure Version
    Release Data Structure Version

TB-007 Verify Data Structure Version Snapshot After Release
    Verify Data Structure Version Snapshot

TB-008 Release Data Structure
    Release Data Structure

TB-009 Verify Released Data Structure Snapshot
    Verify Data Structure Snapshot    AVAILABLE    ${TRUE}

TB-010 Create Data Source
    Create Data Source

TB-011 Verify Draft Data Source Snapshot
    Verify Data Source Snapshot    DRAFT    ${FALSE}

TB-012 Patch Data Source With Data Structure Version
    Patch Data Source With Data Structure Version

TB-013 Verify Data Source References Data Structure Version
    Verify Data Source Snapshot    DRAFT    ${TRUE}

TB-014 Release Data Source
    Release Data Source

TB-015 Verify Released Data Source Snapshot
    Verify Data Source Snapshot    AVAILABLE    ${TRUE}

TB-016 Create Data Set
    Create Data Set

TB-017 Verify Draft Data Set Snapshot
    Verify Data Set Snapshot    DRAFT    ${FALSE}

TB-018 Create Pipeline
    Create Pipeline

TB-019 Verify Pipeline Snapshot
    Verify Pipeline Snapshot

TB-020 Stage Data Set
    Stage Data Set

TB-021 Wait For Ready Data Set Status
    Wait For Data Set Status    READY    60    2

TB-022 Verify Ready Data Set Snapshot
    Verify Data Set Snapshot    READY    ${FALSE}

TB-023 Release Data Set
    Release Data Set

TB-024 Wait For Available Data Set
    Wait For Data Set Available

TB-025 Verify Available Data Set Snapshot
    Verify Data Set Snapshot

TB-030 Verify Anonymous Gateway Rejection
    Verify Gateway Access    401    ${FALSE}

TB-028 Verify Authenticated Gateway Access
    Verify Gateway Access    200    ${TRUE}

TB-029 Verify Authenticated Gateway Response Content
    Verify Gateway Response Content    Test Sensor    test
