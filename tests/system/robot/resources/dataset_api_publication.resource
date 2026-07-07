*** Settings ***
Documentation     Shared backend execution library for the dataset API publication Hero Case.
Library           Remote    ${REMOTE_URL}

*** Keywords ***
Execute Dataset API Publication Scenario
    [Arguments]    ${expected_anonymous_status}    ${verify_anonymous_content}    ${expected_authenticated_status}    ${verify_authenticated_content}
    TC-001 Create Data Structure
    TC-003 Create Data Structure Version
    TC-006 Release Data Structure Version
    TC-008 Release Data Structure
    TC-010 Create Data Source
    TC-012 Patch Data Source With Data Structure Version
    TC-014 Release Data Source
    TC-015 Verify Released Data Source Snapshot
    TC-018 Create Pipeline
    TC-026 Verify Anonymous Gateway Access    ${expected_anonymous_status}
    Run Keyword If    ${verify_anonymous_content}    TC-027 Verify Anonymous Gateway Response Content
    TC-028 Verify Authenticated Gateway Access    ${expected_authenticated_status}
    Run Keyword If    ${verify_authenticated_content}    TC-029 Verify Authenticated Gateway Response Content
    TC-030 Verify Anonymous Gateway Rejection

TC-001 Create Data Structure
    Create Data Structure

TC-002 Verify Draft Data Structure Snapshot
    Verify Data Structure Snapshot    DRAFT    ${FALSE}

TC-003 Create Data Structure Version
    Create Data Structure Version

TC-004 Verify Data Structure Version Snapshot
    Verify Data Structure Version Snapshot    DRAFT

TC-005 Verify Data Structure References Created Version
    Verify Data Structure Snapshot    DRAFT    ${TRUE}

TC-006 Release Data Structure Version
    Release Data Structure Version

TC-007 Verify Data Structure Version Snapshot After Release
    Verify Data Structure Version Snapshot    AVAILABLE

TC-008 Release Data Structure
    Release Data Structure

TC-009 Verify Released Data Structure Snapshot
    Verify Data Structure Snapshot    AVAILABLE    ${TRUE}

TC-010 Create Data Source
    Create Data Source

TC-011 Verify Draft Data Source Snapshot
    Verify Data Source Snapshot    DRAFT    ${FALSE}

TC-012 Patch Data Source With Data Structure Version
    Patch Data Source With Data Structure Version

TC-013 Verify Data Source References Data Structure Version
    Verify Data Source Snapshot    DRAFT    ${TRUE}

TC-014 Release Data Source
    Release Data Source

TC-015 Verify Released Data Source Snapshot
    Verify Data Source Snapshot    AVAILABLE    ${TRUE}

TC-018 Create Pipeline
    Create Pipeline

TC-032 Create Geo Pipeline
    Create Geo Pipeline

TC-033 Verify Geo Pipeline Snapshot
    Verify Geo Pipeline Snapshot

TC-034 Create OWS API
    Create OWS API

TC-036 Create Geo Layer
    Create Geo Layer

TC-026 Verify Anonymous Gateway Access
    [Arguments]    ${expected_status}
    Verify Gateway Access    ${expected_status}    ${FALSE}

TC-027 Verify Anonymous Gateway Response Content
    Verify Gateway Response Content    Test Sensor    test

TC-028 Verify Authenticated Gateway Access
    [Arguments]    ${expected_status}
    Verify Gateway Access    ${expected_status}    ${TRUE}

TC-029 Verify Authenticated Gateway Response Content
    Verify Gateway Response Content    Test Sensor    test    ${TRUE}

TC-030 Verify Anonymous Gateway Rejection
    Verify Gateway Access    401    ${FALSE}

TC-038 Create Data Pool
    Create Data Pool

TC-039 Verify Data Pool Snapshot
    Verify Data Pool Snapshot

TC-040 Set Data Source Datapool Scope
    Set Data Source Datapool Scope

TC-041 Verify Data Source Datapool Scope
    Verify Data Source Datapool Scope

TC-042 Assign Data Set To Data Pool
    Assign Data Set To Data Pool

TC-043 Verify Data Set Data Pool Assignment
    Verify Data Set Data Pool Assignment

TC-044 Verify Data Sources Filtered By Data Pool
    Verify Data Sources Filtered By Data Pool
