importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

const firebaseConfig = {
  apiKey: "AIzaSyCrJBZBBvH_C6zVQxQ7WZl7NhooYgb0870", 
  authDomain: "medirecords-pro.firebaseapp.com",
  projectId: "medirecords-pro",
  storageBucket: "medirecords-pro.firebasestorage.app", 
  messagingSenderId: "379331373787",
  appId: "1:379331373787:web:33555fcacc7fa3a92a7afe",
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: './favicon.png'
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});