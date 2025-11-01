import admin from "firebase-admin";

if (!admin.apps.length) {
  // Initialize Firebase Admin using your environment variable from Vercel
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

export default async function handler(req, res) {
  try {
    const terminalsSnapshot = await db.collection("terminals").get();

    const terminals = terminalsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.status(200).json({ terminals });
  } catch (error) {
    console.error("Error fetching terminals:", error);
    res.status(500).json({ error: "Failed to fetch terminals" });
  }
}
