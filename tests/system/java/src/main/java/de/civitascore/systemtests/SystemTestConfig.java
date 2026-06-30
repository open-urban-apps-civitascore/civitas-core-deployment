package de.civitascore.systemtests;

import java.time.Duration;
import java.util.Map;

public class SystemTestConfig {
  public final String backendBaseUrl;
  public final String keycloakBaseUrl;
  public final String keycloakRealm;
  public final String keycloakClientId;
  public final String gatewayBaseUrl;
  public final String frostBaseUrl;
  public final String authUser;
  public final String authPassword;
  public final Duration requestTimeout;

  private SystemTestConfig(
      String backendBaseUrl,
      String keycloakBaseUrl,
      String keycloakRealm,
      String keycloakClientId,
      String gatewayBaseUrl,
      String frostBaseUrl,
      String authUser,
      String authPassword,
      Duration requestTimeout) {
    this.backendBaseUrl = backendBaseUrl;
    this.keycloakBaseUrl = keycloakBaseUrl;
    this.keycloakRealm = keycloakRealm;
    this.keycloakClientId = keycloakClientId;
    this.gatewayBaseUrl = gatewayBaseUrl;
    this.frostBaseUrl = frostBaseUrl;
    this.authUser = authUser;
    this.authPassword = authPassword;
    this.requestTimeout = requestTimeout;
  }

  public static SystemTestConfig fromEnvironment() {
    Map<String, String> env = System.getenv();
    String backendBaseUrl = nonBlank(
        env.get("PORTAL_BACKEND_URL"),
        nonBlank(env.get("API_BASE_URL"), "http://localhost:8089/v1"));
    String keycloakBaseUrl = nonBlank(env.get("KEYCLOAK_URL"), "http://localhost:8080");
    String keycloakRealm = nonBlank(env.get("KEYCLOAK_REALM"), "civitas-core");
    String keycloakClientId = nonBlank(env.get("KEYCLOAK_CLIENT_ID"), "portal-frontend");
    String gatewayBaseUrl = nonBlank(
        env.get("APISIX_GATEWAY_URL"),
        nonBlank(env.get("PUBLIC_GATEWAY_URL"), "http://localhost:9080"));
    String frostBaseUrl = nonBlank(
        env.get("FROST_BASE_URL"),
        "http://frost-frost-frost-server-http.frost/FROST-Server/v1.1");
    String authUser = nonBlank(
        env.get("SYSTEM_TEST_AUTH_USER"),
        nonBlank(env.get("AUTH_USER"), "dev@civitas.local"));
    String authPassword = nonBlank(
        env.get("SYSTEM_TEST_AUTH_PASSWORD"),
        nonBlank(env.get("AUTH_PASSWORD"), "dev123"));
    Duration requestTimeout = Duration.ofSeconds(
        parseLongOrDefault(env.get("SYSTEM_TEST_HTTP_TIMEOUT_SECONDS"), 30));
    return new SystemTestConfig(
        backendBaseUrl,
        keycloakBaseUrl,
        keycloakRealm,
        keycloakClientId,
        gatewayBaseUrl,
        frostBaseUrl,
        authUser,
        authPassword,
        requestTimeout);
  }

  private static String nonBlank(String first, String second) {
    return (first != null && !first.isBlank()) ? first.trim() : second;
  }

  private static long parseLongOrDefault(String raw, long fallback) {
    if (raw == null || raw.isBlank()) {
      return fallback;
    }
    try {
      long value = Long.parseLong(raw.trim());
      return value > 0 ? value : fallback;
    } catch (NumberFormatException ex) {
      return fallback;
    }
  }
}
