use database_types::connection_description::SshTunnelDescription;
use log::warn;
use russh::Channel;
use russh::ChannelMsg;
use russh::client::Msg;
use std::sync::Arc;

use database_types::connection_description::ConnectionDescription;
use database_types::connection_description::DatabaseBackend;
#[cfg(feature = "mysql")]
use diesel::MysqlConnection;
#[cfg(feature = "postgres")]
use diesel::PgConnection;
use diesel::{Connection, MultiConnection};
use log::error;
use russh::client;

struct SshClient {}

impl client::Handler for SshClient {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &russh::keys::ssh_key::PublicKey,
    ) -> Result<bool, Self::Error> {
        // FIXME Do not accept all SSH servers
        Ok(true)
    }
}

pub enum DbConnection {
    OrmBased(OrmConnection),
    SshBased(SshConnection),
}

#[derive(MultiConnection)]
pub enum OrmConnection {
    #[cfg(feature = "mysql")]
    MySql(MysqlConnection),
    #[cfg(feature = "postgres")]
    PostgreSql(PgConnection),
}

pub struct SshConnection {
    channel: Channel<Msg>,
    // FIXME Type of shell required?
    sql_login_command: String,
    password: String,
}

impl SshConnection {
    pub async fn execute_sql(mut self, sql_query: String) {
        let sql_login_result = self
            .channel
            .exec(true, self.sql_login_command.as_bytes())
            .await;
        match sql_login_result {
            Ok(_) => {
                // FIXME Check all write results
                let _password_write_result = self
                    .channel
                    .data(format!("{}\n", self.password).as_bytes())
                    .await;
                let _sql_query_write_result = self
                    .channel
                    .data(format!("{};\n", sql_query).as_bytes())
                    .await;
                let _eof_write_result = self.channel.eof().await;

                let mut opt_exit_status = None;
                let mut stdout_buffer = Vec::new();
                let mut stderr_buffer = Vec::new();
                loop {
                    let Some(message) = self.channel.wait().await else {
                        break;
                    };
                    match message {
                        ChannelMsg::Data { data } => stdout_buffer.extend_from_slice(&data),
                        ChannelMsg::ExtendedData { data, ext: _ } => {
                            stderr_buffer.extend_from_slice(&data)
                        }
                        ChannelMsg::ExitStatus { exit_status } => {
                            opt_exit_status = Some(exit_status)
                        }
                        _ => {}
                    }
                }

                let close_result = self.channel.close().await;
                match close_result {
                    Ok(_) => {}
                    Err(error) => error!("Closing SSH channel failed due '{}'", error),
                }

                if opt_exit_status.is_none() {
                    warn!(
                        "Command '{}' with query '{}' finished without exit code",
                        self.sql_login_command, sql_query
                    );
                }
                let exit_status = opt_exit_status.unwrap();
                if exit_status != 0 {
                    error!(
                        "Command '{}' with query '{}' finished with exit code '{}'",
                        self.sql_login_command, sql_query, exit_status
                    );
                }

                warn!(
                    "Command '{}' with query '{}' yielded stderr: '{}'",
                    self.sql_login_command,
                    sql_query,
                    String::from_utf8_lossy(&stderr_buffer)
                );

                // FIXME Turn logging output to function return values
                warn!("Got stdout: '{}'", String::from_utf8_lossy(&stdout_buffer));
            }
            Err(error) => error!("Could not log in to database due '{}'", error),
        }
    }
}

async fn create_ssh_client(host: &str, port: u16) -> Option<client::Handle<SshClient>> {
    let config = client::Config {
        nodelay: true,
        ..Default::default()
    };

    let arc_config = Arc::new(config);

    let ssh_client = SshClient {};

    let connection_result = client::connect(arc_config, (host, port), ssh_client).await;

    match connection_result {
        Ok(ssh_session) => Some(ssh_session),
        Err(error) => {
            error!("Could not create SSH session due '{}'", error);
            None
        }
    }
}

async fn authenticate_ssh_client(
    ssh_session: &mut client::Handle<SshClient>,
    username: &str,
    password: &str,
) -> bool {
    let authentication_result = ssh_session.authenticate_password(username, password).await;

    match authentication_result {
        Ok(authentication) => authentication.success(),
        Err(error) => {
            error!("SSH authentication failed due '{}'", error);
            false
        }
    }
}

async fn setup_ssh_client(description: &SshTunnelDescription) -> Option<client::Handle<SshClient>> {
    let ssh_session_result = create_ssh_client(&description.host, description.port).await;

    if ssh_session_result.is_none() {
        return None;
    }

    let mut ssh_session = ssh_session_result.unwrap();

    if !authenticate_ssh_client(
        &mut ssh_session,
        &description.username,
        &description.password,
    )
    .await
    {
        return None;
    }

    return Some(ssh_session);
}

pub async fn get_connection(connection: ConnectionDescription) -> Option<DbConnection> {
    let db_host = connection.host;
    let db_port = connection.port;

    if connection.ssh_tunnel.is_some() {
        let ssh_tunnel_description = connection.ssh_tunnel.unwrap();

        let opt_ssh_client = setup_ssh_client(&ssh_tunnel_description).await;

        if opt_ssh_client.is_none() {
            return None;
        }

        let ssh_client = opt_ssh_client.unwrap();
        let opt_channel = ssh_client.channel_open_session().await;

        let sql_login_command = match connection.backend {
            #[cfg(feature = "postgres")]
            DatabaseBackend::PostgreSql => todo!(),
            // FIXME What about mariadb?
            #[cfg(feature = "mysql")]
            DatabaseBackend::MySql => format!(
                "mysql -N -B {database} -h {host} -P {port} -u {user} -p",
                host = db_host,
                port = db_port,
                user = connection.user,
                database = connection.name
            ),
        };

        return match opt_channel {
            Ok(channel) => Some(DbConnection::SshBased(SshConnection {
                channel,
                sql_login_command,
                password: connection.password,
            })),
            Err(error) => {
                error!("Could not create SSH session due '{}'", error);
                return None;
            }
        };
    }

    match connection.backend {
        #[cfg(feature = "postgres")]
        DatabaseBackend::PostgreSql => {
            let database_url: String = format!(
                "postgres://{user}:{password}@{host}:{port}/{name}",
                user = connection.user,
                password = connection.password,
                host = db_host,
                port = db_port,
                name = connection.name
            );
            let connection = PgConnection::establish(&database_url);

            if connection.is_ok() {
                return Some(DbConnection::OrmBased(OrmConnection::PostgreSql(
                    connection.unwrap(),
                )));
            }

            error!(
                "Connecting to database via '{}' failed due '{}'",
                database_url,
                connection.err().unwrap()
            );
            return None;
        }
        #[cfg(feature = "mysql")]
        DatabaseBackend::MySql => {
            let database_url: String = format!(
                "mysql://{user}:{password}@{host}:{port}/{name}",
                user = connection.user,
                password = connection.password,
                host = db_host,
                port = db_port,
                name = connection.name
            );
            let connection = MysqlConnection::establish(&database_url);

            if connection.is_ok() {
                return Some(DbConnection::OrmBased(OrmConnection::MySql(
                    connection.unwrap(),
                )));
            }

            error!(
                "Connecting to database via '{}' failed due '{}'",
                database_url,
                connection.err().unwrap()
            );
            return None;
        }
    }
}
