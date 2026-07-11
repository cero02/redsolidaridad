const firebaseConfig = {
  apiKey: "AIzaSyDwjdhwGSjPxGGdVdVJyJDVr7hTJcmzC50",
  authDomain: "red-solidaridad.firebaseapp.com",
  projectId: "red-solidaridad",
  storageBucket: "red-solidaridad.firebasestorage.app",
  messagingSenderId: "88259511751",
  appId: "1:88259511751:web:acd607005ba43c6672852e",
  measurementId: "G-6Z33L2VQL8"
};

firebase.initializeApp(firebaseConfig);
window.db = firebase.firestore();
window.auth = firebase.auth();
