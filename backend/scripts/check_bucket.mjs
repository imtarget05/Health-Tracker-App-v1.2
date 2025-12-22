import { firebasePromise, getBucket } from '../src/lib/firebase.js';

(async () => {
    try {
        await firebasePromise;
        console.log('Firebase initialized');
        try {
            const bucket = getBucket();
            console.log('Configured bucket name:', bucket.name);
            const [exists] = await bucket.exists();
            console.log('Bucket exists:', exists);
            if (!exists) {
                console.error('Bucket does not exist or service account lacks permission to access it.');
                process.exitCode = 2;
            }
        } catch (err) {
            console.error('Error while checking bucket:', err && err.message ? err.message : err);
            console.error(err);
            process.exitCode = 3;
        }
    } catch (e) {
        console.error('Firebase initialization failed:', e && e.message ? e.message : e);
        process.exitCode = 1;
    }
})();
