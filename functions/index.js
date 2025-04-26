const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendNewMessageNotification = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    const message = snap.data();
    const conversationId = event.params.conversationId;

    // Get conversation participants
    const conversationDoc = await admin
      .firestore()
      .collection("conversations")
      .doc(conversationId)
      .get();
    const participants =
      conversationDoc.exists && conversationDoc.data().participants
        ? conversationDoc.data().participants
        : [];
    const sender = message.sender;

    // Gather FCM tokens for all recipients except sender
    const tokens = [];
    for (const uid of participants) {
      if (uid !== sender) {
        const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(uid)
          .get();
        if (userDoc.exists && userDoc.data().fcmToken) {
          tokens.push(userDoc.data().fcmToken);
        }
      }
    }

    if (tokens.length === 0) return null;

    const payload = {
      notification: {
        title: "New Message",
        body: message.text || "(Media message)",
      },
      data: {
        conversationId: conversationId,
        senderId: sender,
      },
    };

    try {
      const response = await admin.messaging().sendToDevice(tokens, payload);
      console.log("Notification sent:", response);
      return null;
    } catch (error) {
      console.error("Error sending notification:", error);
      return null;
    }
  });
