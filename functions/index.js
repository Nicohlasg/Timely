const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const cors = require("cors")({ origin: true });

// Initialize Firebase Admin SDK.
admin.initializeApp();
const db = admin.firestore();

// Get client ID and secret from environment variables.
const OAUTH_CLIENT_ID = functions.config().google.client_id;
const OAUTH_CLIENT_SECRET = functions.config().google.client_secret;
const REDIRECT_URI = "https://developers.google.com/oauthplayground";

const oauth2Client = new google.auth.OAuth2(
  OAUTH_CLIENT_ID,
  OAUTH_CLIENT_SECRET,
  REDIRECT_URI,
);

// A predefined list of nice colors for events
const PREDEFINED_COLORS = [
  4282339708, 4294922960, 4280391411, 4283215998, 4294954402,
  4289864256, 4294925721, 4280422911, 4286540287, 4294944162,
  // Adding more colors from Google's default palette
  4294935099, 4283334349, 4278239206, 4294949555, 4294953670,
  4294960335, 4294968294, 4287694335, 4284989949, 4281620479,
];

// Normalize Firestore Timestamp | ISO string | Date -> Date
function safeToDate(value) {
  try {
    if (!value) return new Date('Invalid');
    if (value instanceof Date) return value;
    if (typeof value?.toDate === 'function') return value.toDate();
    if (typeof value === 'string') return new Date(value);
    return new Date(value);
  } catch (_) {
    return new Date('Invalid');
  }
}

function isInvalidDate(d) {
  return !(d instanceof Date) || isNaN(d.getTime());
}

/**
 * Creates a consistent color based on the event title.
 * @param {string} title The title of the event.
 * @return {number} A color value.
 */
function getColorForTitle(title) {
  let hash = 0;
  if (title.length === 0) return PREDEFINED_COLORS[0];
  for (let i = 0; i < title.length; i++) {
    hash = title.charCodeAt(i) + ((hash << 5) - hash);
    hash = hash & hash; // Convert to 32bit integer
  }
  const index = Math.abs(hash % PREDEFINED_COLORS.length);
  return PREDEFINED_COLORS[index];
}

/**
 * Analyzes a list of events with the same title to find a repeat pattern.
 * @param {Array} events The list of Google Calendar event objects.
 * @return {object} An object containing the repeat rule and the last event date.
 */
function detectRepeatRule(events) {
  if (events.length < 2) {
    return { rule: "never", until: null };
  }
  events.sort((a, b) => new Date(a.start.dateTime || a.start.date) - new Date(b.start.dateTime || b.start.date));
  const lastEventDate = new Date(events[events.length - 1].start.dateTime || events[events.length - 1].start.date);

  // Check for fixed day intervals first
  const diffs = [];
  for (let i = 1; i < events.length; i++) {
    const prev = new Date(events[i - 1].start.dateTime || events[i - 1].start.date);
    const curr = new Date(events[i].start.dateTime || events[i].start.date);
    const diffDays = Math.round((curr.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24));
    diffs.push(diffDays);
  }

  const allSame = diffs.every((d) => d === diffs[0]);
  if (allSame) {
    const diff = diffs[0];
    if (diff === 1) return { rule: "daily", until: lastEventDate };
    if (diff === 7) return { rule: "weekly", until: lastEventDate };
    if (diff === 14) return { rule: "everyTwoWeeks", until: lastEventDate };
  }

  // Check for monthly
  let isMonthly = true;
  for (let i = 1; i < events.length; i++) {
    const prev = new Date(events[i - 1].start.dateTime || events[i - 1].start.date);
    const curr = new Date(events[i].start.dateTime || events[i].start.date);
    if (prev.getDate() !== curr.getDate()) {
      isMonthly = false;
      break;
    }
    const monthDiff = (curr.getFullYear() - prev.getFullYear()) * 12 + (curr.getMonth() - prev.getMonth());
    if (monthDiff !== 1) {
      isMonthly = false;
      break;
    }
  }
  if (isMonthly) return { rule: "monthly", until: lastEventDate };

  // Check for yearly
  let isYearly = true;
  for (let i = 1; i < events.length; i++) {
    const prev = new Date(events[i - 1].start.dateTime || events[i - 1].start.date);
    const curr = new Date(events[i].start.dateTime || events[i].start.date);
    if (prev.getDate() !== curr.getDate() || prev.getMonth() !== curr.getMonth()) {
      isYearly = false;
      break;
    }
    if (curr.getFullYear() - prev.getFullYear() !== 1) {
      isYearly = false;
      break;
    }
  }
  if (isYearly) return { rule: "yearly", until: lastEventDate };

  return { rule: "never", until: null };
}


exports.storeAuthToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated.",
    );
  }
  const userId = context.auth.uid;
  const { code } = data;

  if (!code) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required parameter: code.",
    );
  }

  try {
    const { tokens } = await oauth2Client.getToken(code);
    const refreshToken = tokens.refresh_token;
    if (refreshToken) {
      await db.collection("google_tokens").doc(userId).set({
        refreshToken: refreshToken,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, message: "Successfully stored refresh token." };
    } else {
      return { success: false, message: "No refresh token found. User may have already granted consent." };
    }
  } catch (error) {
    console.error("Error exchanging auth code:", error.response?.data || error.message);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to exchange auth code for token.",
    );
  }
});

exports.syncGoogleCalendar = functions.runWith({ timeoutSeconds: 180, memory: "512MB" }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated.",
    );
  }
  const userId = context.auth.uid;
  const { calendarId } = data;
  const targetCalendarId = calendarId || "primary";

  try {
    const tokenDocRef = db.collection("google_tokens").doc(userId);
    const tokenDoc = await tokenDocRef.get();
    if (!tokenDoc.exists) {
      throw new functions.https.HttpsError("unauthenticated", "User not authenticated with Google.");
    }

    oauth2Client.setCredentials({ refresh_token: tokenDoc.data().refreshToken });
    const calendar = google.calendar({ version: "v3", auth: oauth2Client });

    const userTimezone = "Asia/Singapore";

    const googleEventsResult = await calendar.events.list({
      calendarId: targetCalendarId,
      timeMin: (new Date()).toISOString(),
      timeZone: userTimezone,
      maxResults: 250,
      singleEvents: true,
      orderBy: "startTime",
    });
    const googleEvents = googleEventsResult.data.items || [];

    const firebaseSnapshot = await db.collection("events").where("userId", "==", userId).get();

    const googleIdToFirebaseEvent = {};
    firebaseSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data.googleEventId) {
        googleIdToFirebaseEvent[data.googleEventId] = { id: doc.id, ...data };
      }
    });

    const eventsByTitle = {};
    for (const gEvent of googleEvents) {
      if (gEvent.status === 'cancelled') continue;
      const title = gEvent.summary || "Untitled Event";
      if (!eventsByTitle[title]) {
        eventsByTitle[title] = [];
      }
      eventsByTitle[title].push(gEvent);
    }

    const batch = db.batch();

    for (const title in eventsByTitle) {
      const gEventsInGroup = eventsByTitle[title];
      const { rule, until } = detectRepeatRule(gEventsInGroup);
      const color = getColorForTitle(title);

      if (rule !== "never") {
        const masterGEvent = gEventsInGroup[0];
        const existingFbEvent = Object.values(googleIdToFirebaseEvent).find(
          (e) => e.title === title && e.repeatRule !== 'never'
        );

        const eventData = {
          userId: userId,
          title: masterGEvent.summary || "Untitled Event",
          location: masterGEvent.location || "",
          start: new Date(masterGEvent.start.dateTime || masterGEvent.start.date),
          end: new Date(masterGEvent.end.dateTime || masterGEvent.end.date),
          allDay: !!masterGEvent.start.date,
          color: color,
          repeatRule: rule,
          repeatUntil: until ? until.toISOString().split('T')[0] : null,
          exceptions: [],
          importance: "medium",
          googleEventId: masterGEvent.id,
        };

        if (existingFbEvent) {
          const eventRef = db.collection("events").doc(existingFbEvent.id);
          batch.update(eventRef, eventData);
        } else {
          const eventRef = db.collection("events").doc();
          batch.set(eventRef, eventData);
        }
      } else {
        for (const gEvent of gEventsInGroup) {
          const existingFbEvent = googleIdToFirebaseEvent[gEvent.id];
          const eventData = {
            userId: userId,
            googleEventId: gEvent.id,
            title: gEvent.summary || "Untitled Event",
            location: gEvent.location || "",
            start: new Date(gEvent.start.dateTime || gEvent.start.date),
            end: new Date(gEvent.end.dateTime || gEvent.end.date),
            allDay: !!gEvent.start.date,
            color: color,
            repeatRule: "never",
            repeatUntil: null,
            exceptions: [],
            importance: "medium",
          };

          if (existingFbEvent) {
            const eventRef = db.collection("events").doc(existingFbEvent.id);
            batch.update(eventRef, eventData);
          } else {
            const eventRef = db.collection("events").doc();
            batch.set(eventRef, eventData);
          }
        }
      }
    }

    await batch.commit();

    return { success: true, message: "Sync successful." };

  } catch (error) {
    console.error("Error syncing Google Calendar:", error.response?.data || error.message, error.stack);
    if (error.code === 401 || (error.response && error.response.status === 401)) {
      await db.collection("google_tokens").doc(userId).delete();
      throw new functions.https.HttpsError("unauthenticated", "Authentication error. Please sign in again.");
    }
    throw new functions.https.HttpsError("internal", "An error occurred during sync.");
  }
});


// =================================================================
// ============== NEW FUNCTION ADDED BELOW =========================
// =================================================================

/**
 * Finds common free time slots for a group of users.
 * This is a Callable Function, invoked from the client SDK.
 * @param {object} data The data passed to the function.
 * @param {string[]} data.userIds An array of user IDs to check.
 * @param {number} data.durationMinutes The required duration of the free slot.
 * @param {string} data.startRangeISO ISO string for the start of the search.
 * @param {string} data.endRangeISO ISO string for the end of the search.
 * @param {object} context The context of the function call, containing auth info.
 * @return {Promise<{availableSlots: string[]}>} A list of available ISO time slots.
 */
exports.findFreeSlots = functions.https.onCall(async (data, context) => {
  // 1. Authentication and Validation
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated.",
    );
  }
  const myUid = context.auth.uid;

  const { userIds, durationMinutes, startRangeISO, endRangeISO } = data;
  if (!userIds || !Array.isArray(userIds) || userIds.length === 0 ||
    !durationMinutes || !startRangeISO || !endRangeISO) {
    throw new functions.https.HttpsError(
      "invalid-argument", "Missing required parameters.",
    );
  }

  // 2. Authorization Check: Ensure the caller has permission to view schedules.
  const authorizedUserIds = [myUid]; // The caller is always authorized for their own schedule.
  const friendCheckPromises = userIds
    .filter((id) => id !== myUid) // Don't check friendship with self
    .map(async (friendId) => {
      const friendshipId = [myUid, friendId].sort().join("_");
      const friendshipDoc = await db.collection("friendships").doc(friendshipId).get();

      if (friendshipDoc.exists && friendshipDoc.data().status === "accepted") {
        authorizedUserIds.push(friendId);
      } else {
        // For security, we throw an error if any requested user is not a friend.
        throw new functions.https.HttpsError(
          "permission-denied",
          `You do not have permission to view the schedule of user ${friendId}.`,
        );
      }
    });

  await Promise.all(friendCheckPromises);

  const startRange = new Date(startRangeISO);
  const endRange = new Date(endRangeISO);
  const eventsRef = db.collection("events");
  const allBusySlots = [];

  try {
    // 3. Fetch events and expand recurrences for all authorized users
    const querySnapshot = await eventsRef.where("userId", "in", authorizedUserIds).get();

    querySnapshot.forEach((doc) => {
      const event = doc.data();
      const masterStart = event.start.toDate();
      const masterEnd = event.end.toDate();
      const eventDurationMs = masterEnd.getTime() - masterStart.getTime();

      // Handle 'never' rule (non-recurring)
      if (event.repeatRule === "never") {
        if (masterStart < endRange && masterEnd > startRange) {
          allBusySlots.push({ start: masterStart, end: masterEnd });
        }
        return; // continue to next event
      }

      // Handle recurring events
      let currentStart = new Date(masterStart.getTime());
      const repeatUntil = event.repeatUntil ? event.repeatUntil.toDate() : endRange;
      const searchLimit = endRange < repeatUntil ? endRange : repeatUntil;

      while (currentStart < searchLimit) {
        const currentEnd = new Date(currentStart.getTime() + eventDurationMs);
        if (currentStart < endRange && currentEnd > startRange) {
          allBusySlots.push({ start: currentStart, end: currentEnd });
        }

        switch (event.repeatRule) {
          case "daily":
            currentStart.setDate(currentStart.getDate() + 1);
            break;
          case "weekly":
            currentStart.setDate(currentStart.getDate() + 7);
            break;
          // TODO: Implement 'everyTwoWeeks', 'monthly', 'yearly', and 'exceptions'
          // For now, we break to prevent infinite loops on these rules.
          default:
            currentStart = endRange; // Exit loop
            break;
        }
      }
    });

    // 3. Algorithm: Merge all busy slots and find the gaps
    if (allBusySlots.length === 0) {
      return { availableSlots: [startRange.toISOString()] };
    }

    // Sort all busy slots by start time
    allBusySlots.sort((a, b) => a.start - b.start);

    // Merge overlapping/adjacent busy slots into a consolidated timeline
    const mergedBusyTimes = [allBusySlots[0]];
    for (let i = 1; i < allBusySlots.length; i++) {
      const lastMerged = mergedBusyTimes[mergedBusyTimes.length - 1];
      const current = allBusySlots[i];
      if (current.start <= lastMerged.end) {
        // Overlap or adjacent, merge by extending the end time
        lastMerged.end = new Date(Math.max(lastMerged.end, current.end));
      } else {
        mergedBusyTimes.push(current);
      }
    }

    // 4. Find the free gaps between the merged busy slots
    const freeSlots = [];
    let lastBusyEnd = startRange;
    const durationMs = durationMinutes * 60 * 1000;

    mergedBusyTimes.forEach((busyBlock) => {
      const gapStart = lastBusyEnd;
      const gapEnd = busyBlock.start;
      if (gapEnd.getTime() - gapStart.getTime() >= durationMs) {
        freeSlots.push(gapStart.toISOString());
      }
      if (busyBlock.end > lastBusyEnd) {
        lastBusyEnd = busyBlock.end;
      }
    });

    // Check the final gap between the last event and the end of the search range
    if (endRange.getTime() - lastBusyEnd.getTime() >= durationMs) {
      freeSlots.push(lastBusyEnd.toISOString());
    }

    return { availableSlots: freeSlots };
  } catch (error) {
    console.error("Error finding free slots:", error);
    throw new functions.https.HttpsError(
      "internal", "An error occurred.",
    );
  }
});

/**
 * Fetches the calendar events for a given friend, respecting their permissions.
 * @param {object} data The data passed to the function.
 * @param {string} data.friendId The UID of the friend whose schedule is being requested.
 * @param {object} context The context of the function call.
 * @return {Promise<{events: object[]}>} A list of calendar event objects.
 */
exports.getFriendSchedule = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }
  
  const myUid = context.auth.uid;
  const { friendId } = data;
  if (!friendId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing friendId.");
  }

  try {
    const friendDoc = await db.collection("users").doc(friendId).get();
    if (!friendDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Friend profile not found.");
    }
    const friendData = friendDoc.data();

    // Permission Check 1: Are we friends?
    const friendshipIds = [[myUid, friendId].sort().join("_")];
    const friendshipDoc = await db.collection("friendships").doc(friendshipIds[0]).get();

    if (!friendshipDoc.exists || friendshipDoc.data().status !== "accepted") {
      throw new functions.https.HttpsError("permission-denied", "You are not friends with this user.");
    }

    // Permission Check 2: Does their setting allow viewing?
    if (friendData.schedulePermission === "request") {
       // TODO: Implement a request/grant system. For now, we deny.
       throw new functions.https.HttpsError("permission-denied", "This user requires you to request permission to view their schedule.");
    }

    // If all checks pass, fetch the friend's events.
    // Query only by userId to avoid composite index requirements, then filter future events in memory.
    const eventsSnapshot = await db.collection("events")
      .where("userId", "==", friendId)
      .limit(500)
      .get();
    
    const now = new Date();
    const events = eventsSnapshot.docs.map(doc => {
      const eventData = doc.data();
      const start = safeToDate(eventData.start);
      const end = safeToDate(eventData.end);
      if (isInvalidDate(start) || isInvalidDate(end)) {
        return null; // skip malformed
      }
      if (end < now) return null; // Only future or ongoing events
      return { ...eventData, start: start.toISOString(), end: end.toISOString() };
    });

    return { events: events.filter(Boolean) };

  } catch (error) {
    console.error("Error getting friend schedule:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error; // Re-throw HttpsError
    }
    throw new functions.https.HttpsError("internal", "An internal error occurred.");
  }
});

/**
 * Allows a user to propose an event to a friend.
 * Checks for scheduling conflicts before creating the proposal.
 * @param {object} data The data passed to the function.
 * @param {string} data.recipientId The UID of the friend receiving the proposal.
 * @param {object} data.eventData The details of the proposed event.
 * @param {string} data.eventData.title The event title.
 * @param {string} data.eventData.location The event location.
 * @param {string} data.eventData.startISO The event start time (ISO string).
 * @param {string} data.eventData.endISO The event end time (ISO string).
 * @param {object} context The context of the function call.
 * @return {Promise<{success: boolean, reason?: string, conflictingEventTitle?: string}>}
 */
exports.proposeEvent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const { recipientId, eventData } = data;
  const proposerId = context.auth.uid;

  if (!recipientId || !eventData || !eventData.startISO || !eventData.endISO) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required parameters.");
  }

  try {
    const proposedStart = safeToDate(eventData.startISO);
    const proposedEnd = safeToDate(eventData.endISO);

    // Fetch recipient's future events to check for conflicts
    // NOTE: This uses the same simplified recurrence logic as getFriendSchedule.
    // You would need to expand this for full recurrence support.
    const eventsRef = db.collection("events");
    const querySnapshot = await eventsRef
        .where("userId", "==", recipientId)
        .where("end", ">", proposedStart)
        .get();

    let conflictingEventTitle = null;
    querySnapshot.forEach(doc => {
      const event = doc.data();
      const eventStart = safeToDate(event.start);
      const eventEnd = safeToDate(event.end);

      // Check for overlap: (StartA < EndB) and (EndA > StartB)
      if (proposedStart < eventEnd && proposedEnd > eventStart) {
        conflictingEventTitle = event.title;
      }
    });

    if (isInvalidDate(proposedStart) || isInvalidDate(proposedEnd)) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid date format.");
    }

    if (conflictingEventTitle) {
      return {
        success: false,
        reason: "conflict",
        conflictingEventTitle: conflictingEventTitle,
      };
    }

    // No conflict, so create the proposal.
    const proposerDoc = await db.collection("users").doc(proposerId).get();
    let proposerName = "Someone";
    if (proposerDoc.exists) {
      const pd = proposerDoc.data() || {};
      const first = pd.firstName || "";
      const last = pd.lastName || "";
      const combined = `${first} ${last}`.trim();
      proposerName = combined || pd.username || pd.email || "Someone";
    }

    await db.collection("eventProposals").add({
      proposerId: proposerId,
      proposerName: proposerName,
      recipientId: recipientId,
      title: eventData.title || "Untitled Event",
      location: eventData.location || "",
      start: admin.firestore.Timestamp.fromDate(proposedStart),
      end: admin.firestore.Timestamp.fromDate(proposedEnd),
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };

  } catch (error) {
    console.error("Error proposing event:", error);
    throw new functions.https.HttpsError("internal", "An internal error occurred while proposing the event.");
  }
});

/**
 * Handles a user's response to an event proposal.
 * @param {object} data The data passed to the function.
 * @param {string} data.proposalId The ID of the event proposal document.
 * @param {string} data.response The response, either 'accepted' or 'declined'.
 * @param {object} context The context of the function call.
 */
exports.respondToProposal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const { proposalId, response } = data;
  const myUid = context.auth.uid;

  if (!proposalId || !response || !["accepted", "declined"].includes(response)) {
    throw new functions.https.HttpsError("invalid-argument", "Missing or invalid parameters.");
  }
  
  const proposalRef = db.collection("eventProposals").doc(proposalId);

  return db.runTransaction(async (transaction) => {
    const proposalDoc = await transaction.get(proposalRef);
    if (!proposalDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Proposal not found.");
    }

    const proposalData = proposalDoc.data();
    if (proposalData.recipientId !== myUid) {
      throw new functions.https.HttpsError("permission-denied", "You are not the recipient of this proposal.");
    }
    if (proposalData.status !== "pending") {
      throw new functions.https.HttpsError("failed-precondition", "This proposal has already been handled.");
    }

    if (response === "accepted") {
      // Create a new event in the recipient's calendar
      const recipientEventRef = db.collection("events").doc();
      transaction.set(recipientEventRef, {
        userId: myUid,
        title: proposalData.title,
        location: proposalData.location,
        start: proposalData.start,
        end: proposalData.end,
        color: getColorForTitle(proposalData.title),
        allDay: false,
        repeatRule: "never",
        exceptions: [],
        importance: "medium",
      });

      // Also create a mirrored event in the sender's calendar for visibility
      const senderEventRef = db.collection("events").doc();
      transaction.set(senderEventRef, {
        userId: proposalData.proposerId,
        title: proposalData.title,
        location: proposalData.location,
        start: proposalData.start,
        end: proposalData.end,
        color: getColorForTitle(proposalData.title),
        allDay: false,
        repeatRule: "never",
        exceptions: [],
        importance: "medium",
      });

      // Optional: Write a notification record for the sender
      const notifRef = db.collection("notifications").doc();
      transaction.set(notifRef, {
        userId: proposalData.proposerId,
        type: "proposalAccepted",
        title: proposalData.title,
        byUserId: myUid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        meta: {
          proposalId: proposalRef.id,
          location: proposalData.location || "",
          start: proposalData.start,
          end: proposalData.end,
        },
      });
    }
    
    // Update the proposal status
    transaction.update(proposalRef, { status: response });
  });
});


/**
 * Sends a push notification when a new event proposal is created.
 */
exports.sendProposalNotification = functions.firestore
  .document("eventProposals/{proposalId}")
  .onCreate(async (snap, context) => {
    const proposal = snap.data();

    const recipientId = proposal.recipientId;
    const proposerName = proposal.proposerName;

    // Get the recipient's FCM tokens
    const tokensSnapshot = await db.collection("users").doc(recipientId).collection("fcm_tokens").get();
    if (tokensSnapshot.empty) {
      console.log("No FCM tokens for recipient:", recipientId);
      return;
    }
    
    const tokens = tokensSnapshot.docs.map(doc => doc.id);
    
    const payload = {
      notification: {
        title: "New Event Proposal!",
        body: `${proposerName} has invited you to "${proposal.title}".`,
        click_action: "FLUTTER_NOTIFICATION_CLICK", // For handling taps on client
      },
    };

    // Send notification to all of the user's devices
    return admin.messaging().sendToDevice(tokens, payload);
});


/**
 * Blocks another user, preventing any future interaction.
 * @param {object} data The data passed to the function.
 * @param {string} data.userIdToBlock The UID of the user to block.
 * @param {object} context The context of the function call.
 */
exports.blockUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const myUid = context.auth.uid;
  const { userIdToBlock } = data;

  if (!userIdToBlock) {
    throw new functions.https.HttpsError("invalid-argument", "Missing userIdToBlock.");
  }

  // Prevent users from blocking themselves
  if (myUid === userIdToBlock) {
    throw new functions.https.HttpsError("invalid-argument", "You cannot block yourself.");
  }

  try {
    const friendshipIds = [myUid, userIdToBlock].sort().join("_");
    const friendshipDocRef = db.collection("friendships").doc(friendshipIds);

    // Create or update the friendship document to set the status to 'blocked'
    await friendshipDocRef.set({
      users: [myUid, userIdToBlock].sort(),
      requesterId: myUid, // The blocker is the requester in this context
      status: 'blocked',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }); // Use merge to not overwrite existing data if any

    return { success: true, message: "User has been blocked." };

  } catch (error) {
    console.error("Error blocking user:", error);
    throw new functions.https.HttpsError("internal", "An internal error occurred while blocking the user.");
  }
});


/**
 * Submits a report against a user or content.
 * @param {object} data The data passed to the function.
 * @param {string} data.reportedUserId The UID of the user being reported.
 * @param {string} data.reason The predefined reason for the report.
 * @param {string} [data.details] Optional additional details from the user.
 * @param {object} context The context of the function call.
 */
exports.submitReport = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const reporterId = context.auth.uid;
  const { reportedUserId, reason, details } = data;

  if (!reportedUserId || !reason) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required parameters: reportedUserId and reason.");
  }

  try {
    // Add the report to a new 'reports' collection for admin review
    await db.collection("reports").add({
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      reason: reason,
      details: details || "",
      status: "pending_review", // Initial status for the report
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: "Report submitted successfully." };

  } catch (error) {
    console.error("Error submitting report:", error);
    throw new functions.https.HttpsError("internal", "An internal error occurred while submitting the report.");
  }
});