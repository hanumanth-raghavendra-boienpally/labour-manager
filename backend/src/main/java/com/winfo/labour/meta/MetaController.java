package com.winfo.labour.meta;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.winfo.labour.agent.AgentPlaybookReader;
import com.winfo.labour.auth.AuthService;
import com.winfo.labour.db.Db2;
import com.winfo.labour.db.Rows;

/** DC and business-date pickers. */
@RestController
@RequestMapping("/api/meta")
public class MetaController {

    private final AuthService auth;
    private final AgentPlaybookReader agent;
    private final Db2 db2;

    public MetaController(AuthService auth, AgentPlaybookReader agent, Db2 db2) {
        this.auth = auth;
        this.agent = agent;
        this.db2 = db2;
    }

    /**
     * DCs from DB1 that the agent plans for (the CONTROL cohort stays on static planning and sends no requests), each with
     * how many dates have a request, how many wait for the store manager and how many allocations exist (DB2).
     */
    @GetMapping("/dcs")
    public List<Map<String, Object>> dcs(@RequestHeader(value = "Authorization", required = false) String authorization) {
        auth.require(authorization);
        Map<Integer, Map<String, Object>> counts = new HashMap<>();
        for (Map<String, Object> c : db2.rows("select r.dc_id, count(distinct r.business_date)::int as requests, "
                + "count(*) filter (where r.status = 'PENDING_REVIEW')::int as pending, "
                + "count(a.allocation_id)::int as allocations "
                + "from workflow.forecast_request r left join workflow.allocation a on a.request_id = r.request_id group by r.dc_id")) {
            counts.put(Rows.i(c, "dc_id"), c);
        }
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> d : agent.agentDcs()) {
            Map<String, Object> c = counts.get(Rows.i(d, "dcId"));
            if ("CONTROL".equals(Rows.s(d, "cohort")) && c == null) continue;
            d.put("requests", c == null ? 0 : c.get("requests"));
            d.put("pending", c == null ? 0 : c.get("pending"));
            d.put("allocations", c == null ? 0 : c.get("allocations"));
            out.add(d);
        }
        return out;
    }

    /** Business dates for which the agent sent a request (DB2), newest first, with the latest request and allocation state. */
    @GetMapping("/dates")
    public List<Map<String, Object>> dates(@RequestHeader(value = "Authorization", required = false) String authorization,
                                           @RequestParam("dcId") int dcId) {
        auth.require(authorization);
        return db2.rows("select x.business_date::text as date, to_char(x.business_date, 'Dy DD Mon YYYY') as label, "
                + "x.request_id as \"requestId\", x.forecast_code as \"forecastCode\", x.status as \"forecastStatus\", "
                + "a.status as \"allocationStatus\" "
                + "from (select distinct on (r.business_date) r.business_date, r.request_id, r.forecast_code, r.status "
                + "      from workflow.forecast_request r where r.dc_id = ? order by r.business_date, r.version desc) x "
                + "left join workflow.allocation a on a.request_id = x.request_id "
                + "order by x.business_date desc", dcId);
    }
}
