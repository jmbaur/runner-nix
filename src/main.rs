use systemd::daemon;

fn main() {
    println!("START");
    daemon::listen_fds(true).unwrap().iter().for_each(|fd| {
        println!("{}", fd);
    });
    println!("END");
}
