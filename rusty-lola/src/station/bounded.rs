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
