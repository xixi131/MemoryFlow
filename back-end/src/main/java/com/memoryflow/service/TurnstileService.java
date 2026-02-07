package com.memoryflow.service;

import com.memoryflow.config.TurnstileProperties;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.util.List;

import org.springframework.web.client.HttpClientErrorException;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Cloudflare Turnstile 验证服务
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TurnstileService {

    private final TurnstileProperties turnstileProperties;
    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 验证 Turnstile Token
     *
     * @param token 前端传递的 token
     * @return 验证是否通过
     */
    public boolean verify(String token) {
        if (token == null || token.isEmpty()) {
            return false;
        }

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

            String secretKey = turnstileProperties.getSecretKey();
            // Debug log to check secret key (mask part of it for security in prod, but show length here)
            log.debug("Verifying Turnstile token. Secret key length: {}, Token length: {}", 
                    secretKey != null ? secretKey.length() : "null", token.length());

            MultiValueMap<String, String> map = new LinkedMultiValueMap<>();
            map.add("secret", secretKey);
            map.add("response", token);

            HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(map, headers);

            ResponseEntity<TurnstileResponse> response = restTemplate.postForEntity(
                    turnstileProperties.getSiteVerifyUrl(),
                    request,
                    TurnstileResponse.class
            );

            TurnstileResponse body = response.getBody();
            if (body != null && body.isSuccess()) {
                return true;
            } else {
                log.warn("Turnstile verification failed: {}", body != null ? body.getErrorCodes() : "null response");
                return false;
            }
        } catch (HttpClientErrorException e) {
            // Handle 4xx errors gracefully
            log.error("Turnstile API Error: {} - Response: {}", e.getStatusCode(), e.getResponseBodyAsString());
            try {
                // Try to parse the error response as it might contain business error codes despite 400 status
                TurnstileResponse errorResponse = objectMapper.readValue(e.getResponseBodyAsString(), TurnstileResponse.class);
                log.warn("Parsed error response: success={}, errorCodes={}", errorResponse.isSuccess(), errorResponse.getErrorCodes());
            } catch (Exception parseEx) {
                log.error("Failed to parse error response", parseEx);
            }
            return false;
        } catch (Exception e) {
            log.error("Turnstile verification error", e);
            return false;
        }
    }

    @Data
    public static class TurnstileResponse {
        private boolean success;
        private String challenge_ts;
        private String hostname;
        @com.fasterxml.jackson.annotation.JsonProperty("error-codes")
        private List<String> errorCodes;
    }
}
