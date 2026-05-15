use database_types::connection_description::SshTunnelDescription;
use russh::Channel;
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
    SshBased(Channel<Msg>),
}

#[derive(MultiConnection)]
pub enum OrmConnection {
    #[cfg(feature = "mysql")]
    MySql(MysqlConnection),
    #[cfg(feature = "postgres")]
    PostgreSql(PgConnection),
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

        return match opt_channel {
            Ok(channel) => Some(DbConnection::SshBased(channel)),
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
