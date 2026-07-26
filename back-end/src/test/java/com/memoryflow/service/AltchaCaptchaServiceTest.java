package com.memoryflow.service;

import com.memoryflow.config.AltchaCaptchaProperties;
import org.altcha.altcha.v2.Altcha;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class AltchaCaptchaServiceTest {

    @Test
    void acceptsAValidProofOnlyOnce() throws Exception {
        AltchaCaptchaProperties properties = new AltchaCaptchaProperties();
        properties.setSecret("test-secret-that-is-long-enough-for-altcha");
        properties.setCost(1);
        properties.setExpiresInSeconds(180);

        @SuppressWarnings("unchecked")
        RedisTemplate<String, Object> redisTemplate = mock(RedisTemplate.class);
        @SuppressWarnings("unchecked")
        ValueOperations<String, Object> values = mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(values);
        when(values.increment(anyString())).thenReturn(1L);
        when(redisTemplate.expire(anyString(), any(Duration.class))).thenReturn(true);
        when(values.setIfAbsent(anyString(), any(), any(Duration.class)))
                .thenReturn(true)
                .thenReturn(false);

        AltchaCaptchaService service = new AltchaCaptchaService(properties, redisTemplate);
        service.initializeSecrets();
        Altcha.Challenge challenge = service.createChallenge("203.0.113.8");
        Altcha.Solution solution = Altcha.solveChallenge(challenge, Altcha.kdf("PBKDF2/SHA-256"));
        String payload = encodePayload(challenge, solution);

        assertThat(service.verifyAndConsume(payload)).isTrue();
        assertThat(service.verifyAndConsume(payload)).isFalse();
    }

    private static String encodePayload(Altcha.Challenge challenge, Altcha.Solution solution) {
        String json = "{\"challenge\":" + challenge.toJson()
                + ",\"solution\":{\"counter\":" + solution.counter()
                + ",\"derivedKey\":\"" + solution.derivedKey() + "\"}}";
        return Base64.getEncoder().encodeToString(json.getBytes(StandardCharsets.UTF_8));
    }
}
