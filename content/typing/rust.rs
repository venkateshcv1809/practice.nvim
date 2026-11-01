use std::fmt::{Display, Formatter};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct User {
    pub id: u64,
    pub name: String,
    pub email: Option<String>,
}

#[derive(Debug)]
pub enum Error {
    Empty,
    Missing(u64),
}

impl Display for Error {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::Empty => write!(f, "empty"),
            Error::Missing(id) => write!(f, "missing {id}"),
        }
    }
}

pub trait Store {
    fn get(&self, id: u64) -> Result<User, Error>;
}

pub fn greet(user: &User) -> String {
    let host = user.email.as_deref().unwrap_or("local");
    format!("hello {} @ {host}", user.name)
}

pub fn first<'a, T>(items: &'a [T]) -> Result<&'a T, Error> {
    items.first().ok_or(Error::Empty)
}

pub fn total(values: impl IntoIterator<Item = u32>) -> u32 {
    values.into_iter().fold(0, |sum, n| sum + n)
}

#[macro_export]
macro_rules! ids {
    ($($id:expr),* $(,)?) => {
        [$($id),*]
    };
}

pub fn demo() -> Result<String, Error> {
    let user = User {
        id: 7,
        name: "ada".into(),
        email: Some("ada@ex.com".into()),
    };
    let names = ["ada", "grace"];
    let _ = first(&names)?;
    Ok(greet(&user))
}
