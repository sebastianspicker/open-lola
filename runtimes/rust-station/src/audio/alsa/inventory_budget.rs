//! Bounded traversal policy for ALSA-owned hint arrays, independently testable.
use super::{AlsaError, AlsaResult};
use std::time::Duration;
const MAX_HINTS: usize = 4096;
const MAX_ELAPSED: Duration = Duration::from_secs(2);

pub(super) fn walk_hints(
    mut next: impl FnMut(usize) -> AlsaResult<bool>,
    mut elapsed: impl FnMut() -> Duration,
) -> AlsaResult<()> {
    for index in 0..MAX_HINTS {
        if elapsed() >= MAX_ELAPSED {
            return Err(AlsaError::InventoryLimit);
        }
        if !next(index)? {
            return Ok(());
        }
    }
    Err(AlsaError::InventoryLimit)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn oversized_hint_source_stops_at_the_admission_limit() {
        let mut visited = 0;
        assert!(matches!(
            walk_hints(
                |_| {
                    visited += 1;
                    Ok(true)
                },
                || Duration::ZERO
            ),
            Err(AlsaError::InventoryLimit)
        ));
        assert_eq!(visited, MAX_HINTS);
        assert!(walk_hints(|index| Ok(index < 3), || Duration::ZERO).is_ok());
    }
    #[test]
    fn elapsed_budget_stops_before_reading_another_hint() {
        assert!(matches!(
            walk_hints(|_| panic!("must not read after deadline"), || MAX_ELAPSED),
            Err(AlsaError::InventoryLimit)
        ));
    }
}
