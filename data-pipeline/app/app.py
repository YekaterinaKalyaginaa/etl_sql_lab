import streamlit as st
import pandas as pd
from db import fetch_one, fetch_all, exec_sql

st.set_page_config(page_title="DQ Dashboard", layout="wide")

st.title("Data Quality Dashboard")
st.caption("Источник: PostgreSQL views s_psql_dds.v_dq_dashboard и s_psql_dds.v_dq_alert")

# --- Панель управления: период для пересчёта DQ ---
with st.sidebar:
    st.header("Управление")
    start_dt = st.date_input("start_dt", value=pd.to_datetime("1900-01-01").date())
    end_dt = st.date_input("end_dt", value=pd.to_datetime("2100-01-01").date())

    if st.button("Запустить DQ проверки"):
        exec_sql(
            "select s_psql_dds.fn_dq_checks_load(%s::date, %s::date);",
            (start_dt, end_dt),
        )
        st.success("DQ проверки запущены. Обнови страницу или нажми кнопку ниже.")

    if st.button("Обновить данные"):
        st.rerun()

# --- ALERT ---
alert = fetch_one("select * from s_psql_dds.v_dq_alert;")
if alert:
    level = alert.get("alert_level", "UNKNOWN")
    if level == "OK":
        st.success(f"ALERT: {level}")
    elif level == "WARNING":
        st.warning(f"ALERT: {level}")
    elif level == "CRITICAL":
        st.error(f"ALERT: {level}")
    else:
        st.info(f"ALERT: {level}")

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Last run", str(alert.get("last_execution_date")))
    c2.metric("Passed", int(alert.get("passed_cnt", 0)))
    c3.metric("Failed", int(alert.get("failed_cnt", 0)))
    c4.metric("Error", int(alert.get("error_cnt", 0)))
else:
    st.info("Нет данных для алерта. Сначала запусти DQ проверки.")

st.divider()

# --- DASHBOARD (1 строка KPI) ---
dash = fetch_one("select * from s_psql_dds.v_dq_dashboard;")
if dash:
    col1, col2, col3, col4, col5 = st.columns(5)
    col1.metric("Total checks", int(dash.get("total_checks", 0)))
    col2.metric("Passed", int(dash.get("passed_checks", 0)))
    col3.metric("Failed", int(dash.get("failed_checks", 0)))
    col4.metric("Errors", int(dash.get("error_checks", 0)))
    col5.metric("Rows in DM", int(dash.get("dm_rows_total", 0)))

    st.subheader("Детали")
    st.write("**Failed details:**", dash.get("failed_details", ""))
    k1, k2, k3 = st.columns(3)
    k1.metric("NULL full_name", int(dash.get("null_full_name_rows", 0)))
    k2.metric("NULL monthly_income", int(dash.get("null_income_rows", 0)))
    k3.metric("NULL segment_id", int(dash.get("null_segment_id_rows", 0)))
else:
    st.info("Дашборд пуст. Запусти DQ проверки.")
    st.stop()

st.divider()

# --- История проверок (таблица логов) ---
st.subheader("История DQ проверок (последние 50)")
rows = fetch_all("""
select
  check_id,
  check_type,
  table_name,
  execution_date,
  status,
  error_message
from s_psql_dds.t_dq_check_results
where table_name = 's_psql_dm.v_dm_task'
order by execution_date desc, check_id desc
limit 50;
""")
df = pd.DataFrame(rows)
st.dataframe(df, use_container_width=True)

st.divider()

# --- Витрина (немного данных) ---
st.subheader("Пример данных витрины v_dm_task (первые 20 строк)")
dm = fetch_all("""
select
  customer_id,
  full_name,
  gender_id,
  city_id,
  segment_id,
  age,
  monthly_income,
  signup_date,
  valid_from,
  valid_to
from s_psql_dm.v_dm_task
order by signup_date desc nulls last
limit 20;
""")
st.dataframe(pd.DataFrame(dm), use_container_width=True)
