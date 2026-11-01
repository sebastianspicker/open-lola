fn main() {
    let code = rusty_lola::cli::run(None);
    rusty_lola::remove_bundled_resources();
    std::process::exit(code);
}
