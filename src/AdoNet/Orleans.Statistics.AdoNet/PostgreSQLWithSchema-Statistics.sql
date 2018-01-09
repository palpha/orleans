CREATE TABLE IF NOT EXISTS orleans.statistics
(
    statistics_id serial NOT NULL ,
    deployment_id character varying(150) NOT NULL,
    "timestamp" timestamp(3) NOT NULL DEFAULT (now() at time zone 'utc'),
    id character varying(250) NOT NULL,
    host_name character varying(150) NOT NULL,
    name character varying(150) NOT NULL,
    is_value_delta boolean NOT NULL,
    stat_value character varying(1024) NOT NULL,
    statistic character varying(512) NOT NULL,

    CONSTRAINT "StatisticsTable_StatisticsTableId" PRIMARY KEY (statistics_id)
);


CREATE TABLE IF NOT EXISTS orleans.client_metrics
(
    deployment_id character varying(150) NOT NULL,
    client_id character varying(150) NOT NULL,
    "timestamp" timestamp(3) NOT NULL DEFAULT (now() at time zone 'utc'),
    address character varying(45) NOT NULL,
    host_name character varying(150) NOT NULL,
    cpu_usage float(53) NOT NULL,
    memory_usage bigint NOT NULL,
    send_queue_length integer NOT NULL,
    receive_queue_length integer NOT NULL,
    sent_messages bigint NOT NULL,
    received_messages bigint NOT NULL,
    connected_gateway_count bigint NOT NULL,

    CONSTRAINT "PK_ClientMetricsTable_DeploymentId_ClientId" PRIMARY KEY (deployment_id, client_id)
);


CREATE TABLE IF NOT EXISTS orleans.silo_metrics
(
    deployment_id character varying(150) NOT NULL,
    silo_id character varying(150) NOT NULL,
    "timestamp" timestamp(3) NOT NULL DEFAULT (now() at time zone 'utc'),
    address character varying(45) NOT NULL,
    port integer NOT NULL,
    generation integer NOT NULL,
    host_name character varying(150) NOT NULL,
    gateway_address character varying(45) NOT NULL,
    gateway_port integer NOT NULL,
    cpu_usage float(53) NOT NULL,
    memory_usage bigint NOT NULL,
    send_queue_length integer NOT NULL,
    receive_queue_length integer NOT NULL,
    sent_messages bigint NOT NULL,
    received_messages bigint NOT NULL,
    activation_count integer NOT NULL,
    recently_used_activation_count integer NOT NULL,
    request_queue_length bigint NOT NULL,
    is_overloaded boolean NOT NULL,
    client_count bigint NOT NULL,

    CONSTRAINT "PK_SiloMetricsTable_DeploymentId_SiloId" PRIMARY KEY (deployment_id, silo_id),
    CONSTRAINT "FK_SiloMetricsTable_MembershipVersionTable_DeploymentId" FOREIGN KEY (deployment_id) REFERENCES orleans.membership_version (deployment_id)
);


CREATE OR REPLACE FUNCTION orleans.upsert_report_client_metrics(
    _deployment_id orleans.client_metrics.deployment_id%TYPE,
    _client_id orleans.client_metrics.client_id%TYPE,
    _address orleans.client_metrics.address%TYPE,
    _host_name orleans.client_metrics.host_name%TYPE,
    _cpu_usage orleans.client_metrics.cpu_usage%TYPE,
    _memory_usage orleans.client_metrics.memory_usage%TYPE,
    _send_queue_length orleans.client_metrics.send_queue_length%TYPE,
    _receive_queue_length orleans.client_metrics.receive_queue_length%TYPE,
    _sent_messages orleans.client_metrics.sent_messages%TYPE,
    _received_messages orleans.client_metrics.received_messages%TYPE,
    _connected_gateway_count orleans.client_metrics.connected_gateway_count%TYPE
  )
  RETURNS void AS
$func$
BEGIN
    INSERT INTO orleans.client_metrics
    (
        deployment_id,
        client_id,
        address,
        host_name,
        cpu_usage,
        memory_usage,
        send_queue_length,
        receive_queue_length,
        sent_messages,
        received_messages,
        connected_gateway_count
    )
    SELECT
        _deployment_id,
        _client_id,
        _address,
        _host_name,
        _cpu_usage,
        _memory_usage,
        _send_queue_length,
        _receive_queue_length,
        _sent_messages,
        _received_messages,
        _connected_gateway_count
    ON CONFLICT (deployment_id, client_id)
        DO UPDATE SET
            "timestamp" = (now() at time zone 'utc'),
            address = _address,
            host_name = _host_name,
            cpu_usage = _cpu_usage,
            memory_usage = _memory_usage,
            send_queue_length = _send_queue_length,
            receive_queue_length = _receive_queue_length,
            sent_messages = _sent_messages,
            received_messages = _received_messages,
            connected_gateway_count = _connected_gateway_count;
END
$func$ LANGUAGE plpgsql;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'UpsertReportClientMetricsKey',
    'SELECT * FROM orleans.upsert_report_client_metrics(
        @DeploymentId,
        @ClientId,
        @Address,
        @HostName,
        @CpuUsage,
        @MemoryUsage,
        @SendQueueLength,
        @ReceiveQueueLength,
        @SentMessages,
        @ReceivedMessages,
        @ConnectedGatewayCount
    );'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


CREATE OR REPLACE FUNCTION orleans.upsert_silo_metrics(
    _deployment_id orleans.silo_metrics.deployment_id%TYPE,
    _silo_id orleans.silo_metrics.silo_id%TYPE,
    _address orleans.silo_metrics.address%TYPE,
    _port orleans.silo_metrics.port%TYPE,
    _generation orleans.silo_metrics.generation%TYPE,
    _host_name orleans.silo_metrics.host_name%TYPE,
    _gateway_address orleans.silo_metrics.gateway_address%TYPE,
    _gateway_port orleans.silo_metrics.gateway_port%TYPE,
    _cpu_usage orleans.silo_metrics.cpu_usage%TYPE,
    _memory_usage orleans.silo_metrics.memory_usage%TYPE,
    _activation_count orleans.silo_metrics.activation_count%TYPE,
    _recently_used_activation_count orleans.silo_metrics.recently_used_activation_count%TYPE,
    _send_queue_length orleans.silo_metrics.send_queue_length%TYPE,
    _receive_queue_length orleans.silo_metrics.receive_queue_length%TYPE,
    _request_queue_length orleans.silo_metrics.request_queue_length%TYPE,
    _sent_messages orleans.silo_metrics.sent_messages%TYPE,
    _received_messages orleans.silo_metrics.received_messages%TYPE,
    _is_overloaded orleans.silo_metrics.is_overloaded%TYPE,
    _client_count orleans.silo_metrics.client_count%TYPE
  )
  RETURNS void AS
$func$
BEGIN
    INSERT INTO orleans.silo_metrics
    (
        deployment_id,
        silo_id,
        address,
        port,
        generation,
        host_name,
        gateway_address,
        gateway_port,
        cpu_usage,
        memory_usage,
        send_queue_length,
        receive_queue_length,
        sent_messages,
        received_messages,
        activation_count,
        recently_used_activation_count,
        request_queue_length,
        is_overloaded,
        client_count
    )
    SELECT
        _deployment_id,
        _silo_id,
        _address,
        _port,
        _generation,
        _host_name,
        _gateway_address,
        _gateway_port,
        _cpu_usage,
        _memory_usage,
        _send_queue_length,
        _receive_queue_length,
        _sent_messages,
        _received_messages,
        _activation_count,
        _recently_used_activation_count,
        _request_queue_length,
        _is_overloaded,
        _client_count
    ON CONFLICT (deployment_id, silo_id)
        DO UPDATE SET
            "timestamp" = (now() at time zone 'utc'),
            address = _address,
            port = _port,
            generation = _generation,
            host_name = _host_name,
            gateway_address = _gateway_address,
            gateway_port = _gateway_port,
            cpu_usage = _cpu_usage,
            memory_usage = _memory_usage,
            activation_count = _activation_count,
            recently_used_activation_count = _recently_used_activation_count,
            send_queue_length = _send_queue_length,
            receive_queue_length = _receive_queue_length,
            request_queue_length = _request_queue_length,
            sent_messages = _sent_messages,
            received_messages = _received_messages,
            is_overloaded = _is_overloaded,
            client_count = _client_count;
END
$func$ LANGUAGE plpgsql;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'UpsertSiloMetricsKey',
    'SELECT * FROM orleans.upsert_silo_metrics(
        @DeploymentId,
        @SiloId,
        @Address,
        @Port,
        @Generation,
        @HostName,
        @GatewayAddress,
        @GatewayPort,
        @CpuUsage,
        @MemoryUsage,
        @ActivationCount,
        @RecentlyUsedActivationCount,
        @SendQueueLength,
        @ReceiveQueueLength,
        @RequestQueueLength,
        @SentMessages,
        @ReceivedMessages,
        @IsOverloaded,
        @ClientCount
    );'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'InsertOrleansStatisticsKey',
    'START TRANSACTION;
    INSERT INTO orleans.statistics
    (
        deployment_id,
        id,
        host_name,
        name,
        is_value_delta,
        stat_value,
        statistic
    )
    SELECT
        @DeploymentId,
        @Id,
        @HostName,
        @Name,
        @IsValueDelta,
        @StatValue,
        @Statistic;
    COMMIT;'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;