package com.memoryflow.scheduler;

import com.memoryflow.service.EmailReminderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 定时任务调度器
 * 负责执行各种定时任务，如邮件提醒
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ReminderScheduler {

    private final EmailReminderService emailReminderService;

    /**
     * 每天早上8点检查并发送逾期复习提醒
     * Cron表达式: 秒 分 时 日 月 周
     */
    @Scheduled(cron = "0 0 8 * * ?")
    public void sendDailyOverdueReminders() {
        log.info("执行每日逾期复习提醒定时任务...");
        try {
            emailReminderService.checkAndSendOverdueReminders();
            log.info("每日逾期复习提醒定时任务执行完成");
        } catch (Exception e) {
            log.error("每日逾期复习提醒定时任务执行失败: {}", e.getMessage(), e);
        }
    }

    /**
     * 每天晚上8点再次检查（给用户第二次提醒机会）
     */
    @Scheduled(cron = "0 0 20 * * ?")
    public void sendEveningReminders() {
        log.info("执行晚间逾期复习提醒定时任务...");
        try {
            emailReminderService.checkAndSendOverdueReminders();
            log.info("晚间逾期复习提醒定时任务执行完成");
        } catch (Exception e) {
            log.error("晚间逾期复习提醒定时任务执行失败: {}", e.getMessage(), e);
        }
    }
}
