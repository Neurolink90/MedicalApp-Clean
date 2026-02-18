importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Use the same config here
const firebaseConfig = {
    apiKey: "AIzaSyDu-DaxMY4O_IaRyPKM7DVigyi7zo1IntA",
    authDomain: "medirecords-pro.firebaseapp.com",
    projectId: "medirecords-pro",
    storageBucket: "medirecords-pro.firebaseasestorage.app",
    messagingSenderId: "379331373787",
    appId: "1:379331373787:web:33555fcacc7fa3a92a7afe",
    measurementId: "G-61P8TKS1V2"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

// Handle background notifications
messaging.onBackgroundMessage((payload) => {
  console.log('Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});