package com.winfo.labour.notify;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.winfo.labour.auth.Roles;
import com.winfo.labour.db.Db2;
import com.winfo.labour.web.ApiException;

/**
 * In-app notifications, stored in DB2. The browser polls /api/notifications every few seconds and shows the bell
 * and, depending on the role, a popup:
 *   store manager  REQUEST_RECEIVED                      popup "New forecast request" (the agent wrote a forecast into DB1)
 *   user           FORECAST_APPROVED / FORECAST_REJECTED popup (the store manager decided; the outcome is in DB2)
 *   admin          everything, in the bell only
 * Each notification carries the request it is about, so the bell and the popups open that exact request.
 */
@Service
public class NotificationService {

    public static final String REQUEST_RECEIVED = "REQUEST_RECEIVED";
    public static final String FORECAST_APPROVED = "FORECAST_APPROVED";
    public static final String FORECAST_REJECTED = "FORECAST_REJECTED";
    public static final String FORECAST_REOPENED = "FORECAST_REOPENED";

    private final Db2 db2;

    public NotificationService(Db2 db2) {
        this.db2 = db2;
    }

    /** Sends one notification to every active user with the given role. */
    public void notifyRole(String role, String type, String title, String body, Integer requestId, Integer allocationId) {
        db2.exec("insert into workflow.notification (user_id, type, title, body, request_id, allocation_id) "
                        + "select user_id, ?::text, ?::text, ?::text, ?::int, ?::int from workflow.app_user where role = ?::text and is_active",
                type, title, body, requestId, allocationId, role);
    }

    /**
     * The store manager's "new forecast request" prompt for this request is settled (it was decided, or the agent replaced it):
     * mark it read so the popup does not come up again. The admin's bell keeps its own unread state.
     */
    public void settleRequestPrompt(int requestId) {
        db2.exec("update workflow.notification n set read_at = now() from workflow.app_user u "
                + "where u.user_id = n.user_id and u.role = ?::text and n.request_id = ? and n.type = ?::text and n.read_at is null",
                Roles.STORE_MANAGER, requestId, REQUEST_RECEIVED);
    }

    public Map<String, Object> list(int userId) {
        List<Map<String, Object>> items = db2.rows(
                "select n.notification_id as id, n.type, n.title, n.body, n.created_at as \"createdAt\", n.read_at as \"readAt\", "
                        + "n.request_id as \"requestId\", n.allocation_id as \"allocationId\", r.dc_id as \"dcId\", "
                        + "r.business_date::text as \"businessDate\", r.forecast_code as \"forecastCode\", r.status as \"requestStatus\" "
                        + "from workflow.notification n left join workflow.forecast_request r on r.request_id = n.request_id "
                        + "where n.user_id = ? order by n.created_at desc, n.notification_id desc limit 40", userId);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("unread", db2.intValue("select count(*) from workflow.notification where user_id = ? and read_at is null", userId));
        out.put("items", items);
        return out;
    }

    public void markRead(int userId, int notificationId) {
        int n = db2.exec("update workflow.notification set read_at = coalesce(read_at, now()) where notification_id = ? and user_id = ?",
                notificationId, userId);
        if (n == 0) throw ApiException.notFound("Notification not found.");
    }

    public void markAllRead(int userId) {
        db2.exec("update workflow.notification set read_at = now() where user_id = ? and read_at is null", userId);
    }
}
