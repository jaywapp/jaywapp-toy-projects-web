importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDHLM57BStx214mDibIXCIkqibQ4RIyLts',
  authDomain: 'zaro-55798.firebaseapp.com',
  projectId: 'zaro-55798',
  storageBucket: 'zaro-55798.firebasestorage.app',
  messagingSenderId: '286715565538',
  appId: '1:286715565538:web:ee704fee04331ff506d5bb',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification ?? {};
  self.registration.showNotification(notification.title ?? '자로₩', {
    body: notification.body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data ?? {},
  });
});
