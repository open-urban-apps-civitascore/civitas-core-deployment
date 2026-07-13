*** Settings ***
Documentation     Shared keywords and variables for Browser-based UI system tests.
Library           Browser

*** Variables ***
${PORTAL_URL}             %{PORTAL_FRONTEND_URL=http://localhost:3000}
${KEYCLOAK_USERNAME}      ${EMPTY}
${KEYCLOAK_PASSWORD}      ${EMPTY}
${TOAST_SUCCESS}          css=[data-sonner-toast][data-type="success"]

*** Keywords ***
Resolve Auth Credentials
    [Documentation]    Resolve Keycloak credentials from variables or environment with defaults.
    ${user}=    Get Variable Value    ${KEYCLOAK_USERNAME}    ${EMPTY}
    ${pass}=    Get Variable Value    ${KEYCLOAK_PASSWORD}    ${EMPTY}
    IF    '${user}' == '${EMPTY}'
        ${user}=    Evaluate    __import__('os').environ.get('SYSTEM_TEST_AUTH_USER', __import__('os').environ.get('AUTH_USER', 'dev@civitas.local'))
    END
    IF    '${pass}' == '${EMPTY}'
        ${pass}=    Evaluate    __import__('os').environ.get('SYSTEM_TEST_AUTH_PASSWORD', __import__('os').environ.get('AUTH_PASSWORD', 'dev123'))
    END
    Set Suite Variable    ${KEYCLOAK_USERNAME}    ${user}
    Set Suite Variable    ${KEYCLOAK_PASSWORD}    ${pass}

Login Via Keycloak
    [Arguments]    ${username}    ${password}
    [Documentation]    Authenticate through the Keycloak login page and wait until the portal is loaded.
    Click    "Sign in with Keycloak"
    Wait For Elements State    css=input#username    visible    timeout=30s
    Fill Text    css=input#username    ${username}
    Fill Text    css=input#password    ${password}
    Click    css=#kc-login
    # Back on the portal once the Keycloak login form is gone (language-/page-independent).
    Wait For Elements State    css=input#username    detached    timeout=30s
    Wait For Load State    networkidle

Verify Success Toast
    [Documentation]    Wait for a success toast to appear and then disappear again.
    Wait For Elements State    ${TOAST_SUCCESS}    visible    timeout=15s
    Wait For Elements State    ${TOAST_SUCCESS}    hidden    timeout=15s

Navigate Via Breadcrumbs
    [Arguments]    ${crumb_name}
    [Documentation]    Click a breadcrumb link by its visible name.
    Click    nav[aria-label="breadcrumb"] >> role=link[name="${crumb_name}"]

Assert Status
    [Arguments]    ${expected_status}
    [Documentation]    Assert the status dropdown shows the expected status.
    Get Text    css=[data-testid="statusDropdown"]    ==    ${expected_status}
