package com.memoryflow.aspect;

import com.memoryflow.exception.BusinessException;
import com.memoryflow.service.AltchaCaptchaService;
import jakarta.servlet.http.HttpServletRequest;
import org.aspectj.lang.ProceedingJoinPoint;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AltchaCaptchaAspectTest {

    private final AltchaCaptchaService captchaService = Mockito.mock(AltchaCaptchaService.class);
    private final AltchaCaptchaAspect aspect = new AltchaCaptchaAspect(captchaService);

    @AfterEach
    void clearRequestContext() {
        RequestContextHolder.resetRequestAttributes();
    }

    @Test
    void rejectsRequestWithoutCaptchaHeader() throws Throwable {
        setRequest(new MockHttpServletRequest("POST", "/api/auth/login"));
        ProceedingJoinPoint joinPoint = Mockito.mock(ProceedingJoinPoint.class);

        assertThatThrownBy(() -> aspect.checkCaptcha(joinPoint, null))
                .isInstanceOf(BusinessException.class)
                .hasMessage("人机验证失败");
        verify(captchaService, never()).verifyAndConsume(anyString());
    }

    @Test
    void allowsRequestWhenAltchaProofPasses() throws Throwable {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/auth/login");
        request.addHeader("X-ALTCHA-Payload", "proof");
        setRequest(request);
        when(captchaService.verifyAndConsume("proof")).thenReturn(true);
        ProceedingJoinPoint joinPoint = Mockito.mock(ProceedingJoinPoint.class);
        when(joinPoint.proceed()).thenReturn("allowed");

        assertThat(aspect.checkCaptcha(joinPoint, null)).isEqualTo("allowed");
        verify(joinPoint).proceed();
    }

    @Test
    void rejectsRequestWhenAltchaProofFails() throws Throwable {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/auth/login");
        request.addHeader("X-ALTCHA-Payload", "proof");
        setRequest(request);
        when(captchaService.verifyAndConsume("proof")).thenReturn(false);
        ProceedingJoinPoint joinPoint = Mockito.mock(ProceedingJoinPoint.class);

        assertThatThrownBy(() -> aspect.checkCaptcha(joinPoint, null))
                .isInstanceOf(BusinessException.class)
                .hasMessage("人机验证失败");
        verify(joinPoint, never()).proceed();
    }

    private static void setRequest(HttpServletRequest request) {
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
    }
}
