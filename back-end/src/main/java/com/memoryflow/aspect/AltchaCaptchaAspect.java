package com.memoryflow.aspect;

import com.memoryflow.annotation.RequiresCaptcha;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.service.AltchaCaptchaService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/** Enforces a self-hosted ALTCHA proof before protected authentication actions. */
@Slf4j
@Aspect
@Component
@RequiredArgsConstructor
public class AltchaCaptchaAspect {

    private final AltchaCaptchaService captchaService;

    @Around("@annotation(requiresCaptcha)")
    public Object checkCaptcha(ProceedingJoinPoint joinPoint, RequiresCaptcha requiresCaptcha) throws Throwable {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes == null) {
            throw new BusinessException(ErrorCode.AUTH_CAPTCHA_FAILED);
        }

        HttpServletRequest request = attributes.getRequest();
        String payload = request.getHeader("X-ALTCHA-Payload");
        if (payload == null || payload.isBlank()) {
            log.warn("Missing ALTCHA proof for request: {}", request.getRequestURI());
            throw new BusinessException(ErrorCode.AUTH_CAPTCHA_FAILED);
        }

        if (!captchaService.verifyAndConsume(payload)) {
            log.warn("ALTCHA proof was rejected for request: {}", request.getRequestURI());
            throw new BusinessException(ErrorCode.AUTH_CAPTCHA_FAILED);
        }
        return joinPoint.proceed();
    }
}
