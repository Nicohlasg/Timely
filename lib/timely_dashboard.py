# timely_dashboard.py
# To run: streamlit run timely_dashboard.py

import json, os
from datetime import datetime, timedelta
import pandas as pd
import streamlit as st
import plotly.express as px
import firebase_admin
from firebase_admin import credentials, firestore

# --- Page Configuration ---
st.set_page_config(
    page_title="Timely Admin Dashboard",
    page_icon="🗓️",
    layout="wide",
    initial_sidebar_state="expanded",
)

# --- Custom Styling ---
st.markdown("""
<style>
    /* Main headers */
    .stApp h1, .stApp h2 {
        color: #FFFFFF;
    }
    /* Metric labels */
    .st-emotion-cache-1g6gooi {
        color: #A0AEC0 !important; /* A light gray for metric labels */
    }
    /* Expander headers */
    .st-emotion-cache-p5msec {
        font-weight: bold;
    }
    /* Dataframe styling */
    .stDataFrame {
        border: 1px solid #4A5568;
        border-radius: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)


# --- Firebase Connection (Simplified & Robust) ---
@st.cache_resource
def init_firebase():
    """Initializes the Firebase connection using Streamlit secrets."""
    try:
        if not firebase_admin._apps:
            # Recommended: Store the entire JSON as a single secret string
            service_account_str = st.secrets.get("firebase_service_account")
            if service_account_str:
                service_account_info = json.loads(service_account_str)
                cred = credentials.Certificate(service_account_info)
            # Fallback: Use path if the secret string isn't available
            else:
                path = st.secrets.get("firebase_credentials_path")
                if not path:
                    st.error("Firebase credentials not found. Please set `firebase_service_account` or `firebase_credentials_path` in your Streamlit secrets.")
                    return None
                cred = credentials.Certificate(path)
            
            firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        st.error(f"🔥 Firebase Initialization Error: {e}. Please ensure your secrets are configured correctly.")
        return None

db = init_firebase()
if not db:
    st.stop()

# --- Data Fetching & Processing ---
@st.cache_data(ttl=300) # Cache for 5 minutes
def fetch_data():
    """Fetches all necessary collections and performs initial cleaning."""
    collections = ["users", "events", "friendships", "reports", "eventProposals"]
    data = {}
    for collection in collections:
        docs = db.collection(collection).stream()
        records = []
        for doc in docs:
            record = doc.to_dict()
            record['id'] = doc.id
            records.append(record)
        data[collection] = pd.DataFrame(records)

    # --- Standardize Timestamps ---
    for df_name, col_name in [("users", "createdAt"), ("events", "start"), ("friendships", "createdAt"), ("reports", "createdAt"), ("eventProposals", "createdAt")]:
        if df_name in data and col_name in data[df_name].columns:
            # Handle both Firestore Timestamps and ISO strings
            data[df_name][col_name] = pd.to_datetime(data[df_name][col_name], errors='coerce')

    return data

# --- App State Management ---
if 'data' not in st.session_state:
    st.session_state.data = fetch_data()

# --- Sidebar Controls ---
st.sidebar.title("🛠️ Controls & Customization")
if st.sidebar.button("🔄 Refresh Data"):
    st.cache_data.clear()
    st.session_state.data = fetch_data()
    st.toast("Dashboard data has been refreshed!", icon="✅")
    st.rerun()

st.sidebar.markdown("---")
st.sidebar.header("Date Range Filter")
time_range_days = st.sidebar.slider(
    "Select time range for charts (days)",
    min_value=7, max_value=365, value=90, step=1,
    help="Filters time-series charts to show data from the last X days."
)
date_filter_cutoff = datetime.now() - timedelta(days=time_range_days)


# --- Page Navigation ---
PAGES = {
    "📊 Main Dashboard": "main_dashboard",
    "🛡️ Moderation Center": "moderation_page",
}
selection = st.sidebar.radio("Go to", list(PAGES.keys()), index=0)

# ==============================================================================
# PAGE 1: MAIN DASHBOARD
# ==============================================================================
def main_dashboard():
    st.title("📊 Main Dashboard")
    st.markdown("An overview of Timely's key metrics and user activity.")

    # Unpack data from session state
    users_df = st.session_state.data.get("users", pd.DataFrame())
    events_df = st.session_state.data.get("events", pd.DataFrame())
    friendships_df = st.session_state.data.get("friendships", pd.DataFrame())
    proposals_df = st.session_state.data.get("eventProposals", pd.DataFrame())
    
    # --- KPIs ---
    st.header("🚀 Key Performance Indicators")

    total_users = len(users_df)
    new_users_in_range = len(users_df[users_df['createdAt'] > date_filter_cutoff]) if 'createdAt' in users_df.columns else 0
    accepted_friendships = len(friendships_df[friendships_df['status'] == 'accepted']) if 'status' in friendships_df.columns else 0
    
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Users", f"{total_users:,}", f"{new_users_in_range:,} in last {time_range_days} days")
    col2.metric("Total Events", f"{len(events_df):,}")
    col3.metric("Total Friendships", f"{accepted_friendships:,}")
    col4.metric("Total Proposals", f"{len(proposals_df):,}")
    
    st.markdown("---")
    
    # --- Analytics Visualizations ---
    st.header("📈 Visual Analytics")

    # Filter data based on sidebar date range
    users_in_range = users_df[users_df['createdAt'] > date_filter_cutoff] if 'createdAt' in users_df.columns else pd.DataFrame()
    events_in_range = events_df[pd.to_datetime(events_df['start'], errors='coerce') > date_filter_cutoff] if 'start' in events_df.columns else pd.DataFrame()

    c1, c2 = st.columns(2)
    with c1:
        st.subheader("User Growth")
        if not users_in_range.empty:
            daily_signups = users_in_range.set_index('createdAt').resample('D').size().reset_index(name='count')
            fig = px.area(daily_signups, x='createdAt', y='count', title="Daily User Signups", labels={'createdAt': 'Date', 'count': 'Signups'})
            fig.update_traces(line_color='#00A9FF')
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No user data in selected time range.")

    with c2:
        st.subheader("Event Creation")
        if not events_in_range.empty:
            daily_events = events_in_range.set_index(pd.to_datetime(events_in_range['start'])).resample('D').size().reset_index(name='count')
            fig = px.bar(daily_events, x='start', y='count', title="Daily Events Created", labels={'start': 'Date', 'count': 'Events'})
            fig.update_traces(marker_color='#FF6868')
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No event data in selected time range.")

    c3, c4 = st.columns(2)
    with c3:
        st.subheader("Proposal Status Distribution")
        if not proposals_df.empty:
            status_counts = proposals_df['status'].value_counts().reset_index()
            fig = px.pie(status_counts, names='status', values='count', title="Event Proposal Statuses",
                         color_discrete_map={'accepted': '#28a745', 'declined': '#dc3545', 'pending': '#ffc107'})
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No proposal data available.")
            
    with c4:
        st.subheader("User Engagement")
        if not events_df.empty:
            events_per_user = events_df['userId'].value_counts().reset_index(name='event_count')
            fig = px.histogram(events_per_user, x='event_count', title="Distribution of Events per User",
                               labels={'event_count': 'Number of Events Created'})
            fig.update_traces(marker_color='#89B9AD')
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No event data available for engagement analysis.")


# ==============================================================================
# PAGE 2: MODERATION CENTER
# ==============================================================================
def moderation_page():
    st.title("🛡️ Moderation Center")
    st.markdown("Review and manage user reports to maintain a safe and positive community.")

    reports_df = st.session_state.data.get("reports", pd.DataFrame())
    users_df = st.session_state.data.get("users", pd.DataFrame())

    if reports_df.empty:
        st.success("🎉 No reports found. All clear!")
        return

    # --- Filters ---
    st.sidebar.header("Moderation Filters")
    status_filter = st.sidebar.multiselect(
        "Filter by Report Status",
        options=reports_df['status'].unique(),
        default=['pending_review']
    )
    
    filtered_reports = reports_df[reports_df['status'].isin(status_filter)]
    
    if filtered_reports.empty:
        st.info("No reports match the current filter.")
        return

    st.info(f"Displaying **{len(filtered_reports)}** report(s).")
    
    # --- Display Reports ---
    for _, report in filtered_reports.iterrows():
        with st.container(border=True):
            col1, col2 = st.columns([3, 1])
            with col1:
                st.subheader(f"Reason: {report['reason']}")
                st.caption(f"Report ID: {report['id']} | Date: {report['createdAt'].strftime('%Y-%m-%d %H:%M')}")
                st.markdown(f"**Reported User:** `{report['reportedUserId']}`")
                st.markdown(f"**Reporter:** `{report['reporterId']}`")
            with col2:
                # Actions for the report
                new_status = st.selectbox(
                    "Update Status",
                    options=['pending_review', 'resolved', 'dismissed'],
                    index=['pending_review', 'resolved', 'dismissed'].index(report['status']),
                    key=f"status_{report['id']}"
                )
                if st.button("Save Status", key=f"save_{report['id']}"):
                    db.collection('reports').document(report['id']).update({'status': new_status})
                    st.toast(f"Report {report['id']} updated!", icon="✅")
                    st.cache_data.clear() # Clear cache to refetch
                    st.rerun()

            if st.toggle("Show User Profiles", key=f"profiles_{report['id']}"):
                p1, p2 = st.columns(2)
                with p1:
                    st.write("Reporter Profile:")
                    reporter_profile = users_df[users_df['uid'] == report['reporterId']]
                    st.dataframe(reporter_profile, hide_index=True)
                with p2:
                    st.write("Reported User Profile:")
                    reported_profile = users_df[users_df['uid'] == report['reportedUserId']]
                    st.dataframe(reported_profile, hide_index=True)

            if st.toggle("Show Details", key=f"details_{report['id']}"):
                st.info(report['details'] if report['details'] else "No details provided.")

# --- Run the selected page ---
if selection == "📊 Main Dashboard":
    main_dashboard()
elif selection == "🛡️ Moderation Center":
    moderation_page()