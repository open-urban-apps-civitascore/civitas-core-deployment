package de.civitascore.systemtests.client;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import de.civitascore.systemtests.ApiResponse;
import de.civitascore.systemtests.SystemTestConfig;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.LinkedHashMap;
import java.util.Map;

public class PortalBackendClient {
  private final SystemTestConfig config;
  private final HttpClient httpClient;
  private final ObjectMapper mapper;

  public PortalBackendClient(SystemTestConfig config, HttpClient httpClient, ObjectMapper mapper) {
    this.config = config;
    this.httpClient = httpClient;
    this.mapper = mapper;
  }

  public ApiResponse getJson(String path, String bearerToken, int expectedStatus) {
    return send("GET", path, bearerToken, Map.of(), null, expectedStatus);
  }

  public ApiResponse getText(String absoluteUrl, String bearerToken, int expectedStatus) {
    return sendAbsolute("GET", absoluteUrl, bearerToken, Map.of(), null, expectedStatus);
  }

  public ApiResponse getText(String absoluteUrl, String bearerToken, Map<String, String> headers, int expectedStatus) {
    return sendAbsolute("GET", absoluteUrl, bearerToken, headers, null, expectedStatus);
  }

  public ApiResponse postJson(String path, JsonNode body, String bearerToken, int expectedStatus) {
    return send("POST", path, bearerToken, Map.of(), body, expectedStatus);
  }

  public ApiResponse patchJson(String path, JsonNode body, String bearerToken, int expectedStatus) {
    return send("PATCH", path, bearerToken, Map.of(), body, expectedStatus);
  }

  public ApiResponse putJson(String path, JsonNode body, String bearerToken, int expectedStatus) {
    return send("PUT", path, bearerToken, Map.of(), body, expectedStatus);
  }

  public ApiResponse postVoid(String path, String bearerToken, int expectedStatus) {
    return send("POST", path, bearerToken, Map.of(), null, expectedStatus);
  }

  public ApiResponse delete(String path, String bearerToken, int expectedStatus) {
    return send("DELETE", path, bearerToken, Map.of(), null, expectedStatus);
  }

  private ApiResponse send(
      String method,
      String path,
      String bearerToken,
      Map<String, String> headers,
      JsonNode body,
      int expectedStatus) {
    Map<String, String> allHeaders = new LinkedHashMap<>(headers);
    allHeaders.put("X-Allowed-Scope-Ids", "*");
    return sendAbsolute(method, config.backendBaseUrl + path, bearerToken, allHeaders, body, expectedStatus);
  }

  private ApiResponse sendAbsolute(
      String method,
      String absoluteUrl,
      String bearerToken,
      Map<String, String> headers,
      JsonNode body,
      int expectedStatus) {
    HttpRequest.Builder builder = HttpRequest.newBuilder()
        .uri(URI.create(absoluteUrl))
        .timeout(config.requestTimeout);
    if (bearerToken != null && !bearerToken.isBlank()) {
      builder.header("Authorization", "Bearer " + bearerToken);
    }
    if (headers != null) {
      for (Map.Entry<String, String> entry : headers.entrySet()) {
        builder.header(entry.getKey(), entry.getValue());
      }
    }
    if (body != null) {
      builder.header("Content-Type", "application/json");
      try {
        builder.method(method, HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(body)));
      } catch (JsonProcessingException ex) {
        throw new RuntimeException("Failed to serialise JSON request body", ex);
      }
    } else {
      builder.method(method, HttpRequest.BodyPublishers.noBody());
    }
    try {
      HttpResponse<String> response = httpClient.send(builder.build(), HttpResponse.BodyHandlers.ofString());
      return ApiResponse.fromResponse(method + " " + absoluteUrl, response, mapper, expectedStatus);
    } catch (IOException ex) {
      throw new UncheckedIOException("HTTP request failed for " + absoluteUrl, ex);
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
      throw new RuntimeException("HTTP request interrupted for " + absoluteUrl, ex);
    }
  }
}
