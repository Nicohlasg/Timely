# timely_dashboard.py
# To run: streamlit run timely_dashboard.py

import json, os, hashlib
from datetime import datetime
import pandas as pd
import streamlit as st
import firebase_admin
from firebase_admin import credentials, firestore
from google.api_core.exceptions import GoogleAPICallError, DeadlineExceeded, PermissionDenied, Unauthenticated

# --- Configuration and Firebase Initialization ---

# Page Configuration: Must be the first Streamlit command
st.set_page_config(
    page_title="Timely Admin Dashboard",
    page_icon="🗓️",
    layout="wide",
    initial_sidebar_state="expanded"
)

def _secret_fingerprint() -> str:
    """Changes when firebase_service_account changes, to refresh cached init."""
    if "firebase_service_account" in st.secrets:
        svc = st.secrets["firebase_service_account"]
        src = svc if isinstance(svc, str) else json.dumps(dict(svc), sort_keys=True)
        return hashlib.sha256(src.encode()).hexdigest()[:12]
    # fallback to path if you use local file
    path = st.secrets.get("firebase_credentials_path") or os.environ.get("FIREBASE_CREDENTIALS_PATH") or ""
    return f"path:{path}"

# Function to initialize Firebase (uses Streamlit's caching to run only once)
@st.cache_resource
def init_firebase(_fp: str):
    # Require secret; accept TOML table or JSON string. Fallback to path if provided.
    svc = st.secrets.get("firebase_service_account")
    try:
        if svc:
            info = json.loads(svc) if isinstance(svc, str) else dict(svc)
            cred = credentials.Certificate(info)
        else:
            path = st.secrets.get("firebase_credentials_path") or os.environ.get("FIREBASE_CREDENTIALS_PATH")
            if not path:
                st.error("Add firebase_service_account in Streamlit Secrets.")
                return None
            cred = credentials.Certificate(path)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        st.error(f"Failed to initialize Firebase: {e}")
        return None

def current_project_id() -> str | None:
    svc = st.secrets.get("firebase_service_account")
    if not svc:
        return None
    info = json.loads(svc) if isinstance(svc, str) else dict(svc)
    return info.get("project_id")

# Manual cache clear for convenience
with st.sidebar:
    if st.button("Clear cache and reconnect"):
        try:
            st.cache_resource.clear()
            st.cache_data.clear()
        except Exception:
            pass
        st.rerun()

# Initialize Firebase and get the Firestore client (use the return value)
db = init_firebase(_secret_fingerprint())
if not db:
    st.stop()

# Global sidebar control for max docs per collection
with st.sidebar:
    max_docs = st.number_input(
        "Max docs per collection",
        min_value=100, max_value=10000, value=500, step=100,
        help="Caps how many documents are fetched from each Firestore collection."
    )
    st.session_state["max_docs"] = int(max_docs)

# --- Data Fetching Helpers (bounded, with timeout) ---

@st.cache_data(ttl=600, show_spinner=False)
def fetch_collection(name: str, limit: int = 500, timeout_sec: float = 15.0) -> pd.DataFrame:
    try:
        q = firestore.Client().collection(name).limit(limit)  # use same client config under the hood
        docs = list(q.stream(timeout=timeout_sec))
        rows = []
        for d in docs:
            obj = d.to_dict() or {}
            obj["id"] = d.id
            rows.append(obj)
        return pd.DataFrame(rows)
    except (DeadlineExceeded, PermissionDenied, Unauthenticated, GoogleAPICallError) as e:
        st.warning(f"Could not load '{name}': {e}")
        return pd.DataFrame()
    except Exception as e:
        st.warning(f"Error loading '{name}': {e}")
        return pd.DataFrame()

def parse_iso_string(s):
    """Safely parses ISO string to datetime object."""
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00'))
    except (TypeError, ValueError, AttributeError):
        return None

# --- Main Dashboard App ---

def main_dashboard(db):
    """Main function to build the Streamlit dashboard."""
    st.title("🗓️ Timely - Admin Dashboard")
    st.markdown("Welcome to the central hub for monitoring Timely's growth and user activity.")

    # Load data with clear, bounded spinners (use the global limit)
    lim = st.session_state.get("max_docs", 500)
    with st.spinner("Loading users..."):
        users_df = fetch_collection("users", limit=lim)
    with st.spinner("Loading events..."):
        events_df = fetch_collection("events", limit=lim)
    with st.spinner("Loading friendships..."):
        friendships_df = fetch_collection("friendships", limit=lim)
    with st.spinner("Loading reports..."):
        reports_df = fetch_collection("reports", limit=lim)

    # Add createdAt/report dates normalization for robustness
    if not users_df.empty and "createdAt" in users_df.columns:
        users_df["createdAt"] = pd.to_datetime(users_df["createdAt"], errors="coerce")

    if not events_df.empty and "start" in events_df.columns:
        events_df["start_time"] = events_df["start"].apply(parse_iso_string)
        events_df.dropna(subset=["start_time"], inplace=True)

    # --- High-Level Metrics ---
    st.header("Key Performance Indicators (KPIs)")

    total_users = len(users_df)
    total_events = len(events_df)
    total_friendships = friendships_df[friendships_df.get("status") == "accepted"].shape[0] if not friendships_df.empty else 0
    pending_reports = reports_df[reports_df.get("status") == "pending_review"].shape[0] if not reports_df.empty else 0

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Users", f"{total_users}")
    col2.metric("Total Events Created", f"{total_events}")
    col3.metric("Active Friendships", f"{total_friendships}")
    col4.metric("Pending Reports", f"{pending_reports}", delta=pending_reports, delta_color="inverse")

    st.divider()

    # --- Visualizations ---
    st.header("Analytics & Insights")

    # Customization Sidebar
    st.sidebar.header("Chart Customization")
    time_range = st.sidebar.slider(
        "Select Time Range (Days)",
        min_value=1, max_value=90, value=30,
        help="Filter charts to show data from the last X days."
    )
    
    # Prepare data for time-series charts
    if not users_df.empty and 'createdAt' in users_df.columns:
        users_df['createdAt'] = pd.to_datetime(users_df['createdAt'], errors='coerce')
        recent_users_df = users_df[users_df['createdAt'] > datetime.now() - timedelta(days=time_range)]
        user_signups_by_day = recent_users_df.set_index('createdAt').resample('D').size().reset_index(name='count')
    else:
        user_signups_by_day = pd.DataFrame({'createdAt': [], 'count': []})

    if not events_df.empty and 'start' in events_df.columns:
        events_df['start_time'] = events_df['start'].apply(parse_iso_string)
        events_df.dropna(subset=['start_time'], inplace=True)
        recent_events_df = events_df[events_df['start_time'] > datetime.now() - timedelta(days=time_range)]
        events_by_day = recent_events_df.set_index('start_time').resample('D').size().reset_index(name='count')
    else:
        events_by_day = pd.DataFrame({'start_time': [], 'count': []})

    # Display Charts
    col_a, col_b = st.columns(2)
    with col_a:
        st.subheader("User Signups Over Time")
        if not user_signups_by_day.empty:
            fig_users = px.line(user_signups_by_day, x='createdAt', y='count', title="Daily New Users", labels={'createdAt': 'Date', 'count': 'Number of Signups'})
            fig_users.update_layout(xaxis_title="Date", yaxis_title="Signups")
            st.plotly_chart(fig_users, use_container_width=True)
        else:
            st.info("No user signup data available for the selected period.")

    with col_b:
        st.subheader("Event Creation Over Time")
        if not events_by_day.empty:
            fig_events = px.bar(events_by_day, x='start_time', y='count', title="Daily Events Created", labels={'start_time': 'Date', 'count': 'Number of Events'})
            fig_events.update_layout(xaxis_title="Date", yaxis_title="Events Created")
            st.plotly_chart(fig_events, use_container_width=True)
        else:
            st.info("No event creation data available for the selected period.")

    st.divider()

    # --- Raw Data Explorer ---
    st.header("Data Explorer")
    
    # Customization for Data Explorer
    dataset_to_view = st.selectbox("Choose a dataset to view:", ("Users", "Events", "Friendships", "Reports"))
    
    if dataset_to_view == "Users":
        st.dataframe(users_df)
    elif dataset_to_view == "Events":
        st.dataframe(events_df)
    elif dataset_to_view == "Friendships":
        st.dataframe(friendships_df)
    elif dataset_to_view == "Reports":
        st.dataframe(reports_df)


def moderation_page(db):
    """Page for handling user reports and moderation."""
    st.title("🛡️ Moderation Center")
    st.markdown("Review and take action on user-submitted reports.")

    # Fetch reports directly (replace missing get_all_data)
    lim = st.session_state.get("max_docs", 500)
    reports_df = fetch_collection("reports", limit=lim)
    if "createdAt" in reports_df.columns:
        reports_df["createdAt"] = pd.to_datetime(reports_df["createdAt"], errors="coerce")

    if reports_df.empty:
        st.success("🎉 No pending reports. All clear!")
        return

    # Filter for pending reports
    pending_reports = reports_df[reports_df.get("status") == "pending_review"].copy()
    if pending_reports.empty:
        st.success("🎉 No pending reports. All clear!")
        return

    st.info(f"You have **{len(pending_reports)}** pending report(s) to review.")
    
    # Display reports in an interactive way
    for index, report in pending_reports.iterrows():
        with st.expander(f"Report ID: {report['id']} - Reason: **{report['reason']}**"):
            st.markdown(f"**Reported User ID:** `{report['reportedUserId']}`")
            st.markdown(f"**Reporter ID:** `{report['reporterId']}`")
            st.markdown(f"**Date:** {report['createdAt'].strftime('%Y-%m-%d %H:%M')}")
            st.markdown("**Details Provided:**")
            st.info(report['details'] if report['details'] else "No additional details were provided.")

            st.markdown("---")
            st.subheader("Moderation Actions")
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                if st.button("Mark as Resolved", key=f"resolve_{report['id']}"):
                    db.collection('reports').document(report['id']).update({'status': 'resolved'})
                    st.success(f"Report {report['id']} marked as resolved.")
                    st.experimental_rerun()

            with col2:
                if st.button("Dismiss as False", key=f"dismiss_{report['id']}"):
                    db.collection('reports').document(report['id']).update({'status': 'dismissed_false'})
                    st.success(f"Report {report['id']} dismissed as false.")
                    st.experimental_rerun()

            with col3:
                # In a real app, this would trigger a Cloud Function to handle user suspension safely.
                # Directly modifying user accounts from the dashboard is risky.
                if st.button("⚠️ Suspend User (Placeholder)", key=f"suspend_{report['id']}"):
                    st.warning(f"This would suspend user {report['reportedUserId']}. This action is a placeholder.")
                    # Example: db.collection('users').document(report['reportedUserId']).update({'isSuspended': True})


# --- Page Navigation ---
PAGES = {
    "📊 Main Dashboard": lambda: main_dashboard(db),
    "🧪 Smoke Test":     lambda: smoke_test(db),
    "🛡️ Moderation Center": lambda: moderation_page(db),
}
selection = st.sidebar.radio("Go to", list(PAGES.keys()), index=0)
PAGES[selection]()
