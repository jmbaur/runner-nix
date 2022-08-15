use clap::Parser;

#[derive(Parser, Debug)]
pub struct Args {
    /// The command to run.
    #[clap(short, long, value_parser)]
    pub command: String,
    /// The adapter to use for authenticating run requests and setting up the environment.
    #[clap(short, long, value_parser)]
    pub adapter: String,
}
