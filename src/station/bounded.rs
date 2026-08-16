//! Small bounded-history helpers for long-running station services.

pub(crate) const MAX_HISTORY_ITEMS: usize = 64;

pub(crate) fn push_bounded<T>(items: &mut Vec<T>, item: T) {
    if items.len() == MAX_HISTORY_ITEMS {
        items.remove(0);
    }
    items.push(item);
}

pub(crate) fn push_unique_bounded<T: PartialEq>(items: &mut Vec<T>, item: T) {
    if !items.contains(&item) {
        push_bounded(items, item);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn history_keeps_only_the_newest_items() {
        let mut items = Vec::new();
        for item in 0..=MAX_HISTORY_ITEMS {
            push_bounded(&mut items, item);
        }
        assert_eq!(items.len(), MAX_HISTORY_ITEMS);
        assert_eq!(items.first(), Some(&1));
        assert_eq!(items.last(), Some(&MAX_HISTORY_ITEMS));
    }

    #[test]
    fn unique_history_does_not_duplicate_items() {
        let mut items = Vec::new();
        push_unique_bounded(&mut items, "chat".to_owned());
        push_unique_bounded(&mut items, "chat".to_owned());
        assert_eq!(items, ["chat"]);
    }
}
