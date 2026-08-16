use std::sync::{Mutex, MutexGuard};

pub(super) fn lock_unpoison<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|error| error.into_inner())
}

#[cfg(test)]
mod tests {
    use super::lock_unpoison;
    use std::sync::{Arc, Mutex};
    use std::thread;

    #[test]
    fn recovers_a_poisoned_lock() {
        let lock = Arc::new(Mutex::new(0));
        let poisoned_lock = Arc::clone(&lock);
        let poisoned = thread::spawn(move || {
            let _guard = poisoned_lock
                .lock()
                .expect("lock should initially be available");
            panic!("poison lock");
        });
        assert!(poisoned.join().is_err());

        let guard = lock_unpoison(&lock);
        assert_eq!(*guard, 0);
    }
}
