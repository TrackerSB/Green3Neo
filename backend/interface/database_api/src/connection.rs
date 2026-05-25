use database_types::connection_description::SshTunnelDescription;
use diesel::RunQueryDsl;
use log::warn;
use russh::Channel;
use russh::ChannelMsg;
use russh::client::Msg;
#[cfg(feature = "mysql")]
use sea_query::MysqlQueryBuilder;
#[cfg(feature = "postgres")]
use sea_query::PostgresQueryBuilder;
use sea_query::QueryStatementWriter;
use std::collections::HashMap;
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

use crate::api::models;

#[derive(MultiConnection)]
pub enum OrmConnection {
    #[cfg(feature = "mysql")]
    MySql(MysqlConnection),
    #[cfg(feature = "postgres")]
    PostgreSql(PgConnection),
}

impl OrmConnection {
    pub fn to_string<QueryType: QueryStatementWriter>(&self, sql_query: QueryType) -> String {
        return match self {
            #[cfg(feature = "postgres")]
            Self::PostgreSql(_) => sql_query.to_string(PostgresQueryBuilder),
            #[cfg(feature = "mysql")]
            Self::MySql(_) => sql_query.to_string(MysqlQueryBuilder),
        };
    }

    pub fn load_member<QueryType: QueryStatementWriter>(
        &mut self,
        sql_query: QueryType,
    ) -> Option<Vec<models::Member>> {
        let sql_query_string = self.to_string(sql_query);

        let query_result = diesel::sql_query(&sql_query_string).load::<models::Member>(self);

        return match query_result {
            Ok(result) => Some(result),
            Err(error) => {
                error!(
                    "Executing query '{}' failed due '{}'",
                    sql_query_string, error
                );
                return None;
            }
        };
    }
}

pub struct SshConnection {
    channel: Channel<Msg>,
    // FIXME Type of shell required?
    sql_login_command: String,
    password: String,
    backend: DatabaseBackend,
}

impl SshConnection {
    pub fn to_string<QueryType: QueryStatementWriter>(&self, sql_query: QueryType) -> String {
        return match self.backend {
            #[cfg(feature = "postgres")]
            DatabaseBackend::PostgreSql => sql_query.to_string(PostgresQueryBuilder),
            #[cfg(feature = "mysql")]
            DatabaseBackend::MySql => sql_query.to_string(MysqlQueryBuilder),
        };
    }

    async fn read_sql_result(&mut self) -> Vec<Vec<String>> {
        let mut opt_exit_status = None;
        let mut stdout_buffer = Vec::new();
        let mut stderr_buffer = Vec::new();
        loop {
            let Some(message) = self.channel.wait().await else {
                break;
            };
            match message {
                ChannelMsg::Data { data } => stdout_buffer.extend_from_slice(&data),
                ChannelMsg::ExtendedData { data, ext: _ } => stderr_buffer.extend_from_slice(&data),
                ChannelMsg::ExitStatus { exit_status } => opt_exit_status = Some(exit_status),
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
                "Command '{}' finished without exit code",
                self.sql_login_command
            );
        }
        let exit_status = opt_exit_status.unwrap();
        if exit_status != 0 {
            error!(
                "Command '{}' finished with exit code '{}'",
                self.sql_login_command, exit_status
            );
        }

        warn!(
            "Command '{}' yielded stderr: '{}'",
            self.sql_login_command,
            String::from_utf8_lossy(&stderr_buffer)
        );

        return String::from_utf8_lossy(&stdout_buffer)
            .lines()
            .map(|line| line.split('\t').map(ToOwned::to_owned).collect())
            .collect();
    }

    fn convert_to_json(cells: Vec<Vec<String>>) -> Vec<serde_json::Value> {
        let cells_split = cells.split_first();

        if cells_split.is_none() {
            error!("Could not create objects since field names could not be determined");
            return vec![];
        }

        let (field_names, rows) = cells_split.unwrap();

        if rows.iter().any(|row| row.len() != field_names.len()) {
            error!("There are rows of different size than the row of field names");
            return vec![];
        }

        let mut field_to_index = HashMap::<String, usize>::new();
        for (index, name) in field_names.iter().enumerate() {
            field_to_index.insert(name.clone(), index);
        }

        let mut json_objects: Vec<serde_json::Value> = vec![];
        for row in rows {
            let mut object_properties = serde_json::Map::new();

            for (field, index) in &field_to_index {
                // FIXME Cast to data type of column
                object_properties.insert(field.clone(), serde_json::json!(row[*index]));
            }

            json_objects.push(serde_json::json!(object_properties));
        }

        json_objects
    }

    pub async fn load_member<QueryType: QueryStatementWriter>(
        &mut self,
        sql_query: QueryType,
    ) -> Option<Vec<models::Member>> {
        let sql_query_string = self.to_string(sql_query);
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
                    .data(format!("{};\n", sql_query_string).as_bytes())
                    .await;
                let _eof_write_result = self.channel.eof().await;

                let cells = self.read_sql_result().await;
                let json_result = SshConnection::convert_to_json(cells);
                json_result
                    .into_iter()
                    .map(|value| serde_json::from_value(value))
                    .filter(|result| match result {
                        Ok(_member) => true,
                        Err(error) => {
                            error!("Could not interpret some row as member due '{}", error);
                            false
                        }
                    })
                    .map(Result::unwrap)
                    .collect()
            }
            Err(error) => {
                error!("Could not log in to database due '{}'", error);
                None
            }
        }
    }
}

pub enum DbConnection {
    OrmBased(OrmConnection),
    SshBased(SshConnection),
}

impl DbConnection {
    pub fn to_string<QueryType: QueryStatementWriter>(&self, sql_query: QueryType) -> String {
        return match self {
            Self::OrmBased(connection) => connection.to_string(sql_query),
            Self::SshBased(connection) => connection.to_string(sql_query),
        };
    }

    pub async fn load_member<QueryType: QueryStatementWriter>(
        &mut self,
        sql_query: QueryType,
    ) -> Option<Vec<models::Member>> {
        return match self {
            Self::OrmBased(connection) => connection.load_member(sql_query),
            Self::SshBased(connection) => connection.load_member(sql_query).await,
        };
    }
}

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
            Ok(channel) => Some(DbConnection::SshBased(match connection.backend {
                #[cfg(feature = "postgres")]
                DatabaseBackend::PostgreSql => SshConnection {
                    channel,
                    sql_login_command: todo!("Implement psql login command"),
                    password: connection.password,
                    backend: connection.backend,
                },
                // FIXME What about mariadb?
                #[cfg(feature = "mysql")]
                DatabaseBackend::MySql => SshConnection {
                    channel,
                    sql_login_command: format!(
                        "mysql -B {database} -h {host} -P {port} -u {user} -p",
                        host = db_host,
                        port = db_port,
                        user = connection.user,
                        database = connection.name
                    ),
                    password: connection.password,
                    backend: connection.backend,
                },
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
