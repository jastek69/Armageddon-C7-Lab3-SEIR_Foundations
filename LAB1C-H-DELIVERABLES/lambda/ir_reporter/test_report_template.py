from handler import REPORT_TEMPLATE


def test_report_template_format():
    rendered = REPORT_TEMPLATE.format(
        incident_id="test-incident",
        title="Test Alarm",
        impact="TBD",
        symptoms="TBD",
        detection="CloudWatch Alarm",
        severity="TBD",
        start_time="TBD",
        end_time="TBD",
        duration="TBD",
        alarm_time="2026-02-01T00:00:00Z",
        first_error_time="TBD",
        triage_time="TBD",
        rca_time="TBD",
        fix_time="TBD",
        restore_time="TBD",
        alarm_clear_time="TBD",
        components="TBD",
        entry_point="ALB/WAF",
        downstream="RDS",
        regions="us-west-2",
        alarm_name="Test Alarm",
        alarm_metric="TestMetric",
        alarm_threshold="1",
        alarm_state="ALARM",
        app_log_summary="0 records",
        waf_log_summary="0 records",
        ssm_path="/lab/db/",
        secret_name="taaops/rds/mysql",
        drift_notes="TBD",
        root_cause_category="TBD",
        failure_mechanism="TBD",
        why_not_prevented="TBD",
        contributing_factors="TBD",
        actions_taken="TBD",
        validation_checks="TBD",
        recovery_evidence="TBD",
        prevent_immediate="TBD",
        prevent_short="TBD",
        prevent_long="TBD",
        cli_commands="TBD",
        queries_used="TBD",
        model_id="anthropic.claude-3-haiku-20240307-v1:0",
    )

    assert "Incident Report" in rendered
    assert "Test Alarm" in rendered


if __name__ == "__main__":
    test_report_template_format()
    print("OK")
