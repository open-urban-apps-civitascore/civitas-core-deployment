*** Settings ***
Library           Remote    ${REMOTE_URL}
Suite Setup       Initialize System Test Run    suffix=restricted    openDataAccess=${FALSE}
Suite Teardown    Cleanup System Test Run

*** Test Cases ***
Create Data Structure
    Create Data Structure

Create Data Structure Version
    Create Data Structure Version

Release Data Structure Version
    Release Data Structure Version

Release Data Structure
    Release Data Structure

Create Data Source
    Create Data Source

Patch Data Source
    Patch Data Source With Data Structure Version

Release Data Source
    Release Data Source

Create Data Set
    Create Data Set

Create Pipeline
    Create Pipeline

Stage Data Set
    Stage Data Set

Release Data Set
    Release Data Set

Wait For Availability
    Wait For Data Set Available

Verify Data Set Snapshot
    Verify Data Set Snapshot

Verify Anonymous Gateway Rejection
    Verify Gateway Access    401    ${FALSE}

Verify Authenticated Gateway Access
    Verify Gateway Access    200    ${TRUE}
