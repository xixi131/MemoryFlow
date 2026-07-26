package com.memoryflow.service;

import com.memoryflow.config.AltchaCaptchaProperties;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.altcha.altcha.v2.Altcha;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.Map;

/** Creates and verifies short-lived, self-hosted ALTCHA challenges. */
@Slf4j
@Service
@RequiredArgsConstructor
public class AltchaCaptchaService {

    private static final String CHALLENGE_RATE_LIMIT_PREFIX = "captcha:altcha:challenge:";
    private static final String USED_CHALLENGE_PREFIX = "captcha:altcha:used:";
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final AltchaCaptchaProperties properties;
    private final RedisTemplate<String, Object> redisTemplate;
    private String signatureSecret;

    @PostConstruct
    void initializeSecrets() {
        String configuredSecret = properties.getSecret();
        if (configuredSecret == null || configuredSecret.isBlank()) {
            signatureSecret = generateSecret();
            log.warn("ALTCHA uses an in-memory secret; set ALTCHA_CAPTCHA_SECRET to keep it stable across restarts");
        } else {
            signatureSecret = configuredSecret;
        }
    }

    public Altcha.Challenge createChallenge(String clientIp) {
        if (!isChallengeRequestAllowed(clientIp)) {
            throw new BusinessException(ErrorCode.AUTH_CAPTCHA_FAILED);
        }

        try {
            Altcha.CreateChallengeOptions options = new Altcha.CreateChallengeOptions()
                    .algorithm("PBKDF2/SHA-256")
                    .cost(Math.max(1, properties.getCost()))
                    .expiresInSeconds(Math.max(30, properties.getExpiresInSeconds()))
                    .data(Map.of("scope", "memoryflow-auth"))
                    .hmacSignatureSecret(signatureSecret);
            return Altcha.createChallenge(options);
        } catch (Exception e) {
            log.error("Unable to create ALTCHA challenge: {}", e.getMessage());
            throw new BusinessException(ErrorCode.INTERNAL_ERROR);
        }
    }

    public boolean verifyAndConsume(String payload) {
        if (payload == null || payload.isBlank()) {
            return false;
        }

        try {
            Altcha.Payload parsed = Altcha.parsePayload(payload);
            Altcha.Challenge challenge = parsed.challenge();
            if (!isAuthenticationChallenge(challenge)) {
                return false;
            }

            Altcha.VerifySolutionResult result = Altcha.verifySolution(
                    challenge,
                    parsed.solution(),
                    signatureSecret,
                    null,
                    Altcha.kdf(challenge.parameters().algorithm())
            );
            if (!result.verified()) {
                return false;
            }

            String key = USED_CHALLENGE_PREFIX + sha256(challenge.signature());
            Duration ttl = Duration.ofSeconds(Math.max(30, properties.getExpiresInSeconds()));
            return Boolean.TRUE.equals(redisTemplate.opsForValue().setIfAbsent(key, Boolean.TRUE, ttl));
        } catch (Exception e) {
            // Fail closed and do not log the payload, which contains the proof.
            log.warn("ALTCHA proof rejected: {}", e.getMessage());
            return false;
        }
    }

    private boolean isChallengeRequestAllowed(String clientIp) {
        try {
            String ip = clientIp == null || clientIp.isBlank() ? "unknown" : clientIp;
            String key = CHALLENGE_RATE_LIMIT_PREFIX + sha256(ip);
            Long count = redisTemplate.opsForValue().increment(key);
            if (count != null && count == 1) {
                redisTemplate.expire(key, Duration.ofMinutes(1));
            }
            return count != null && count <= Math.max(1, properties.getMaxChallengeRequestsPerMinute());
        } catch (Exception e) {
            log.error("ALTCHA challenge rate limit unavailable: {}", e.getMessage());
            return false;
        }
    }

    private static boolean isAuthenticationChallenge(Altcha.Challenge challenge) {
        return challenge != null
                && challenge.signature() != null
                && challenge.parameters() != null
                && challenge.parameters().data() != null
                && "memoryflow-auth".equals(challenge.parameters().data().get("scope"));
    }

    private static String generateSecret() {
        byte[] bytes = new byte[48];
        SECURE_RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static String sha256(String value) {
        try {
            return Altcha.bytesToHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 is unavailable", e);
        }
    }
}
