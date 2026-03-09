package com.memoryflow.exception;

import lombok.Getter;
import lombok.AllArgsConstructor;

@Getter
@AllArgsConstructor
public enum ErrorCode {

    // 通用错误 1000-1999
    SUCCESS(200, "操作成功"),
    BAD_REQUEST(400, "请求参数错误"),
    UNAUTHORIZED(401, "未授权访问"),
    FORBIDDEN(403, "访问被拒绝"),
    NOT_FOUND(404, "资源不存在"),
    INTERNAL_ERROR(500, "服务器内部错误"),

    // 认证错误 2000-2999
    AUTH_EMAIL_EXISTS(2001, "邮箱已被注册"),
    AUTH_EMAIL_INVALID(2002, "邮箱格式不正确"),
    AUTH_PASSWORD_INVALID(2003, "密码格式不正确（需要字母+数字，8-20位）"),
    AUTH_CREDENTIALS_INVALID(2004, "邮箱或密码错误"),
    AUTH_ACCOUNT_LOCKED(2005, "账号已被锁定，请稍后再试"),
    AUTH_ACCOUNT_DISABLED(2006, "账号已被禁用"),
    AUTH_TOKEN_EXPIRED(2007, "Token已过期"),
    AUTH_TOKEN_INVALID(2008, "Token无效"),
    AUTH_REGISTER_LIMIT(2009, "注册频率过高，请稍后再试"),
    AUTH_VERIFY_CODE_INVALID(2010, "验证码无效或已过期"),
    USER_NOT_FOUND(2011, "用户不存在"),
    AUTH_CAPTCHA_FAILED(2012, "人机验证失败"),
    AUTH_EMAIL_NOT_INVITED(2013, "该邮箱未获得注册邀请"),

    // 目标相关错误 3000-3999
    GOAL_NOT_FOUND(3001, "目标不存在"),
    GOAL_ACCESS_DENIED(3002, "无权访问此目标"),

    // 科目相关错误 4000-4999
    SUBJECT_NOT_FOUND(4001, "科目不存在"),
    SUBJECT_ACCESS_DENIED(4002, "无权访问此科目"),
    SUBJECT_DSL_PARSE_ERROR(4003, "内容格式解析错误"),
    ARTICLE_NOT_FOUND(4004, "文章不存在"),

    // 章节相关错误 5000-5999
    CHAPTER_NOT_FOUND(5001, "章节不存在"),

    // 要点相关错误 6000-6999
    POINT_NOT_FOUND(6001, "要点不存在"),
    POINT_ACCESS_DENIED(6002, "无权访问此要点"),

    // 复习相关错误 7000-7999
    REVIEW_NOT_READY(7001, "该要点尚未到复习时间"),
    REVIEW_ALREADY_COMPLETED(7002, "该要点已完成所有复习"),

    // 单词/课程相关错误 8000-8999
    COURSE_NOT_FOUND(8001, "课程不存在"),
    WORD_NOT_FOUND(8002, "单词不存在"),
    WORD_ALREADY_LEARNED(8003, "该单词已学习"),
    WORD_NOT_LEARNED(8004, "该单词尚未学习"),

    // Todo 相关错误 9000-9999
    TODO_LIST_NOT_FOUND(9001, "待办清单不存在"),
    TODO_LIST_ACCESS_DENIED(9002, "无权访问此待办清单"),
    TODO_LIST_NAME_DUPLICATED(9003, "待办清单名称已存在"),
    TODO_DEFAULT_LIST_DELETE_DENIED(9004, "默认清单不允许删除"),
    TODO_TASK_NOT_FOUND(9101, "待办任务不存在"),
    TODO_TASK_ACCESS_DENIED(9102, "无权访问此待办任务"),
    TODO_TAG_NOT_FOUND(9201, "待办标签不存在"),
    TODO_TAG_ACCESS_DENIED(9202, "无权访问此待办标签"),
    TODO_TAG_NAME_DUPLICATED(9203, "待办标签名称已存在"),
    TODO_SUBTASK_NOT_FOUND(9301, "子任务不存在"),
    TODO_SUBTASK_ACCESS_DENIED(9302, "无权访问此子任务");

    private final int code;
    private final String message;
}
