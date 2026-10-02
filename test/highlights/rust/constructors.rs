fn check(n: u8) -> Result<u8, String> {
    if n > 9 {
        return Err(format!("{n}"));
    }
    let names: Vec<u8> = Vec::new();
    let first = Option::Some(Wrapper::<u8>(n));
    Ok(Wrapper(n).0)
}
