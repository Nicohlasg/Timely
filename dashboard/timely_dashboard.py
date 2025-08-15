# timely_dashboard.py
# To run: streamlit run timely_dashboard.py

import json
import streamlit as st
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import plotly.express as px
from datetime import datetime, timedelta

# --- Page Configuration ---
st.set_page_config(
    page_title="Timely Admin Dashboard",
    page_icon="🗓️",
    layout="wide",
)

# --- Firebase Connection (Robust & Simplified) ---
@st.cache_resource
def init_firebase():
    """Initializes a persistent Firebase connection using Streamlit secrets."""
    try:
        if not firebase_admin._apps:
            service_account_str = st.secrets.get("firebase_service_account")
            if not service_account_str:
                st.error("Firebase credentials not found in Streamlit secrets. Please add the full content of your service account JSON to a secret named 'firebase_service_account'.")
                return None
            
            service_account_info = json.loads(service_account_str)
            cred = credentials.Certificate(service_account_info)
            firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        st.error(f"🔥 Firebase Initialization Error: {e}. Please ensure your secrets are configured correctly.")
        return None

db = init_firebase()
if not db:
    st.stop()

# --- Data Fetching & Processing (with Limits and Caching) ---
@st.cache_data(ttl=300) # Cache for 5 minutes
def fetch_data(limit_per_collection: int):
    """Fetches all necessary collections with a document limit and performs cleaning."""
    collections_to_fetch = ["users", "events", "friendships", "reports", "eventProposals", "tasks"]
    data = {}
    
    progress_bar = st.progress(0, text="Connecting to database...")
    
    for i, collection_name in enumerate(collections_to_fetch):
        try:
            progress_bar.progress((i) / len(collections_to_fetch), text=f"Fetching {collection_name}...")
            if db is None:
                st.warning("Database connection is not initialized. Skipping data fetch.")
                data[collection_name] = pd.DataFrame()
                continue
            docs = db.collection(collection_name).limit(limit_per_collection).stream()
            records = [doc.to_dict() | {'id': doc.id} for doc in docs]
            data[collection_name] = pd.DataFrame(records)
        except Exception as e:
            st.warning(f"Could not load collection '{collection_name}': {e}")
            data[collection_name] = pd.DataFrame()

    progress_bar.progress(1.0, text="Data loaded!")
    progress_bar.empty()

    # --- Standardize Timestamps and Data Types ---
    timestamp_cols = {
        "users": "createdAt", "events": "start", "friendships": "createdAt",
        "reports": "createdAt", "eventProposals": "createdAt", "tasks": "dueDate"
    }
    for df_name, col_name in timestamp_cols.items():
        if df_name in data and col_name in data[df_name].columns:
            data[df_name][col_name] = pd.to_datetime(data[df_name][col_name], errors='coerce')

    return data

# --- Sidebar Controls ---
st.sidebar.title("🛠️ Controls")

if st.sidebar.button("🔄 Refresh Data"):
    st.cache_data.clear()
    st.toast("Dashboard data has been refreshed!", icon="✅")
    st.rerun()

doc_limit = st.sidebar.number_input(
    "Max Documents per Collection",
    min_value=50, max_value=5000, value=1000, step=50,
    help="Limits how many documents are fetched to prevent timeouts. Increase if you have more data."
)

st.sidebar.markdown("---")

# Fetch data using the limit from the sidebar
if 'data' not in st.session_state or st.session_state.get('doc_limit') != doc_limit:
    st.session_state.data = fetch_data(doc_limit)
    st.session_state.doc_limit = doc_limit

# --- Page Navigation ---
st.sidebar.title("Navigation")
selection = st.sidebar.radio("Go to", ["📊 Overview", "👥 User Management", "🛡️ Moderation Center"])

# --- Main App Body ---
st.title("Timely Admin Dashboard")

if selection == "📊 Overview":
    # Unpack dataframes needed for this page
    users_df = st.session_state.data.get("users", pd.DataFrame())
    events_df = st.session_state.data.get("events", pd.DataFrame())
    friendships_df = st.session_state.data.get("friendships", pd.DataFrame())

    # --- KPIs ---
    st.header("🚀 Key Performance Indicators")
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Users", f"{len(users_df):,}")
    col2.metric("Total Events", f"{len(events_df):,}")
    col3.metric("Accepted Friendships", len(friendships_df[friendships_df['status'] == 'accepted']) if 'status' in friendships_df else 0)
    col4.metric("Pending Reports", len(st.session_state.data.get("reports", pd.DataFrame())[lambda df: df.get("status") == "pending_review"]))
    
    st.markdown("---")
    st.header("📈 Analytics")
    
    # --- Date Range Filter for Charts ---
    time_range_days = st.slider(
        "Select time range for charts (in days)",
        min_value=7, max_value=365, value=90, step=1
    )
    date_filter_cutoff = datetime.now() - timedelta(days=time_range_days)
    
    c1, c2 = st.columns(2)
    with c1:
        st.subheader("User Growth")
        if not users_df.empty and 'createdAt' in users_df.columns:
            users_in_range = users_df[users_df['createdAt'] > date_filter_cutoff]
            daily_signups = users_in_range.set_index('createdAt').resample('D').size().reset_index(name='count')
            fig = px.area(daily_signups, x='createdAt', y='count', title="Daily User Signups", labels={'createdAt': 'Date', 'count': 'Signups'})
            fig.update_traces(line_color='#00A9FF')
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No user data to display.")

    with c2:
        st.subheader("Event Creation")
        if not events_df.empty and 'start' in events_df.columns:
            events_in_range = events_df[events_df['start'] > date_filter_cutoff]
            daily_events = events_in_range.set_index('start').resample('D').size().reset_index(name='count')
            fig = px.bar(daily_events, x='start', y='count', title="Daily Events Created", labels={'start': 'Date', 'count': 'Events'})
            fig.update_traces(marker_color='#FF6868')
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No event data to display.")
            
elif selection == "👥 User Management":
    st.header("👥 User Management")
    users_df = st.session_state.data.get("users", pd.DataFrame())
    
    search_query = st.text_input("Search users by name, email, or username")
    
    if not users_df.empty:
        filtered_users = users_df.copy()
        if search_query:
            query = search_query.lower()
            searchable_cols = ['firstName', 'lastName', 'email', 'username']
            # Ensure all searchable columns exist before trying to search them
            cols_to_search = [col for col in searchable_cols if col in filtered_users.columns]
            filtered_users = filtered_users[
                filtered_users[cols_to_search]
                .apply(lambda row: row.astype(str).str.lower().str.contains(query, na=False).any(), axis=1)
            ]
        
        display_cols = ['firstName', 'lastName', 'username', 'email', 'createdAt']
        st.dataframe(filtered_users[[col for col in display_cols if col in filtered_users.columns]], use_container_width=True, hide_index=True)
    else:
        st.warning("No user data found.")

elif selection == "🛡️ Moderation Center":
    st.header("🛡️ Moderation Center")
    reports_df = st.session_state.data.get("reports", pd.DataFrame())
    users_df = st.session_state.data.get("users", pd.DataFrame())

    if reports_df.empty:
        st.success("🎉 No reports found. All clear!")
    else:
        status_filter = st.multiselect(
            "Filter by Report Status",
            options=reports_df['status'].unique(),
            default=['pending_review']
        )
        
        filtered_reports = reports_df[reports_df['status'].isin(status_filter)]
        st.info(f"Displaying **{len(filtered_reports)}** report(s).")

        for _, report in filtered_reports.iterrows():
            with st.container(border=True):
                col1, col2 = st.columns([3, 1])
                with col1:
                    st.subheader(f"Reason: {report['reason']}")
                    # createdAt may be NaT; guard before strftime
                    created = report.get('createdAt')
                    created_str = created.strftime('%Y-%m-%d %H:%M') if hasattr(created, 'strftime') else str(created)
                    st.caption(f"Report ID: {report['id']} | Date: {created_str}")
                with col2:
                    new_status = st.selectbox("Update Status", options=['pending_review', 'resolved', 'dismissed'], index=['pending_review', 'resolved', 'dismissed'].index(report['status']), key=f"status_{report['id']}")
                    if st.button("Save", key=f"save_{report['id']}"):
                        db.collection('reports').document(report['id']).update({'status': new_status})
                        st.toast(f"Report {report['id']} updated!", icon="✅")
                        st.cache_data.clear()
                        st.rerun()

                st.markdown(f"**Reported User ID:** `{report['reportedUserId']}`")
                st.markdown(f"**Reporter ID:** `{report['reporterId']}`")
                
                if st.toggle("Show Details & Profiles", key=f"details_{report['id']}"):
                    st.info(f"**Details:** {report['details'] or 'No details provided.'}")
                    p1, p2 = st.columns(2)
                    with p1:
                        st.write("**Reporter Profile:**")
                        st.dataframe(users_df[users_df['uid'] == report['reporterId']], hide_index=True)
                    with p2:
                        st.write("**Reported User Profile:**")
                        st.dataframe(users_df[users_df['uid'] == report['reportedUserId']], hide_index=True)