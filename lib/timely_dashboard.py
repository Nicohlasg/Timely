# timely_dashboard.py
# To run: streamlit run timely_dashboard.py

import json
import os
import streamlit as st
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import plotly.express as px
from datetime import datetime, timedelta
from google.api_core.exceptions import GoogleAPICallError, DeadlineExceeded, PermissionDenied, Unauthenticated

# --- Configuration and Firebase Initialization ---

# Page Configuration: Must be the first Streamlit command
st.set_page_config(
    page_title="Timely Admin Dashboard",
    page_icon="🗓️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Function to initialize Firebase (uses Streamlit's caching to run only once)
@st.cache_resource
def init_firebase():
    # Require the secret and accept either TOML table or JSON string
    if "firebase_service_account" not in st.secrets:
        st.error("Add firebase_service_account in Streamlit Secrets.")
        return None

    svc = st.secrets["firebase_service_account"]
    info = json.loads(svc) if isinstance(svc, str) else dict(svc)

    try:
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(info))
        return firestore.client()
    except Exception as e:
        st.error(f"Failed to initialize Firebase: {e}")
        return None

# Initialize Firebase and get the Firestore client (use the return value)
db = init_firebase()
if not db:
    st.stop()

# --- Data Fetching Helpers (bounded, with timeout) ---

@st.cache_data(ttl=600, show_spinner=False)
def fetch_collection(name: str, limit: int = 5000, timeout_sec: float = 20.0) -> pd.DataFrame:
    try:
        docs = db.collection(name).limit(limit).get(timeout=timeout_sec)
        items = []
        for d in docs:
            data = d.to_dict() or {}
            data["id"] = d.id
            items.append(data)
        return pd.DataFrame(items)
    except (DeadlineExceeded, PermissionDenied, Unauthenticated, GoogleAPICallError) as e:
        st.warning(f"Could not load '{name}' (timeout/perm): {e}")
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

def main_dashboard():
    """Main function to build the Streamlit dashboard."""
    st.title("🗓️ Timely - Admin Dashboard")
    st.markdown("Welcome to the central hub for monitoring Timely's growth and user activity.")

    # Load data with clear, bounded spinners (no global function spinner)
    with st.spinner("Loading users..."):
        users_df = fetch_collection("users")
    with st.spinner("Loading events..."):
        events_df = fetch_collection("events")
    with st.spinner("Loading friendships..."):
        friendships_df = fetch_collection("friendships")
    with st.spinner("Loading reports..."):
        reports_df = fetch_collection("reports")

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


def moderation_page():
    """Page for handling user reports and moderation."""
    st.title("🛡️ Moderation Center")
    st.markdown("Review and take action on user-submitted reports.")

    try:
        _, _, _, reports_df = get_all_data()
    except Exception as e:
        st.error(f"Could not load reports from Firestore. Error: {e}")
        return

    if reports_df.empty:
        st.success("🎉 No pending reports. All clear!")
        return

    # Filter for pending reports
    pending_reports = reports_df[reports_df['status'] == 'pending_review'].copy()
    
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
    "📊 Main Dashboard": main_dashboard,
    "🛡️ Moderation Center": moderation_page,
}

st.sidebar.title("Navigation")
selection = st.sidebar.radio("Go to", list(PAGES.keys()))
page = PAGES[selection]

# Run the selected page function
if __name__ == "__main__":
    if init_firebase():
        page()
