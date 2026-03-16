importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

const firebaseConfig = {
  apiKey: "AIzaSyDu-DaxmY4O_IaRyPKM7DVigyi7zo1INtA", // UPDATED: Uppercase 'N'
  authDomain: "medirecords-pro.firebaseapp.com",
  projectId: "medirecords-pro",
  storageBucket: "medirecords-pro.firebasestorage.app", // FIXED: Removed 'ase'
  messagingSenderId: "379331373787",
  appId: "1:379331373787:web:33555fcacc7fa3a92a7afe",
  measurementId: "G-61P8TKS1V2"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});