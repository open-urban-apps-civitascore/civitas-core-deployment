package de.civitascore.systemtests.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import de.civitascore.systemtests.ApiResponse;
import de.civitascore.systemtests.SystemTestConfig;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Map;

public class KeycloakClient {
  private final SystemTestConfig config;
  private final HttpClient httpClient;
  private final ObjectMapper mapper;

  public KeycloakClient(SystemTestConfig config, HttpClient httpClient, ObjectMapper mapper) {
    this.config = config;
    this.httpClient = httpClient;
    this.mapper = mapper;
  }

  public String getAccessToken() {
    if (config.authUser == null || config.authUser.isBlank()) {
      throw new IllegalStateException("SYSTEM_TEST_AUTH_USER or AUTH_USER must be set");
    }
    if (config.authPassword == null || config.authPassword.isBlank()) {
      throw new IllegalStateException("SYSTEM_TEST_AUTH_PASSWORD or AUTH_PASSWORD must be set");
    }
    String formBody = form(
        Map.of(
            "grant_type", "password",
            "client_id", config.keycloakClientId,
            "username", config.authUser,
            "password", config.authPassword));
    HttpRequest request = HttpRequest.newBuilder()
        .uri(URI.create(config.keycloakBaseUrl
            + "/realms/"
            + encodePath(config.keycloakRealm)
            + "/protocol/openid-connect/token"))
        .timeout(config.requestTimeout)
        .header("Content-Type", "application/x-www-form-urlencoded")
        .POST(HttpRequest.BodyPublishers.ofString(formBody))
        .build();
    ApiResponse response = send(request, 200);
    JsonNode json = response.json();
    String token = json.path("access_token").asText(null);
    if (token == null || token.isBlank()) {
      throw new AssertionError("Keycloak token response did not contain access_token: " + response.body());
    }
    return token;
  }

  private ApiResponse send(HttpRequest request, int expectedStatus) {
    try {
      HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
      return ApiResponse.fromResponse("Keycloak token request", response, mapper, expectedStatus);
    } catch (IOException ex) {
      throw new UncheckedIOException("Keycloak request failed", ex);
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
      throw new RuntimeException("Keycloak request was interrupted", ex);
    }
  }

  private static String form(Map<String, String> values) {
    StringBuilder builder = new StringBuilder();
    for (Map.Entry<String, String> entry : values.entrySet()) {
      if (builder.length() > 0) {
        builder.append('&');
      }
      builder.append(encodeQuery(entry.getKey()))
          .append('=')
          .append(encodeQuery(entry.getValue()));
    }
    return builder.toString();
  }

  private static String encodeQuery(String value) {
    return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
  }

  private static String encodePath(String value) {
    return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8).replace("+", "%20");
  }
}
