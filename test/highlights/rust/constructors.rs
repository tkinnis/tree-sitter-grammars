fn check(n: u8) -> Result<u8, String> {
    if n > 9 {
        return Err(format!("{n}"));
    }
    Ok(Wrapper(n).0)
}
