//! Interactive station UI + headless controller.

#[cfg(feature = "gui")]
pub mod app;
pub mod controller;
pub mod state;

#[cfg(feature = "gui")]
pub use app::*;
pub use controller::*;
pub use state::*;

/// Reports how to enable the optional interactive UI while keeping headless
/// controller and CLI paths available in minimal builds.
#[cfg(not(feature = "gui"))]
pub fn run_interactive_ui() -> Result<(), String> {
    Err(
        "interactive UI is unavailable in this build; rebuild rusty-lola with `--features gui`"
            .into(),
    )
}

#[cfg(all(test, not(feature = "gui")))]
mod tests {
    #[test]
    fn interactive_ui_reports_the_required_rebuild_feature() {
        let error = super::run_interactive_ui().expect_err("minimal build has no window backend");
        assert!(error.contains("--features gui"));
    }
}
