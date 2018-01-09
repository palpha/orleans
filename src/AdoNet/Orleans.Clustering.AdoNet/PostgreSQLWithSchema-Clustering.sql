-- For each deployment, there will be only one (active) membership version table version column which will be updated periodically.
CREATE TABLE IF NOT EXISTS orleans.membership_version
(
    deployment_id character varying(150) NOT NULL,
    "timestamp" timestamp(3) NOT NULL DEFAULT (now() at time zone 'utc'),
    version integer NOT NULL DEFAULT 0,

    CONSTRAINT "PK_OrleansMembershipVersionTable_DeploymentId" PRIMARY KEY (deployment_id)
);


-- Every silo instance has a row in the membership table.
CREATE TABLE IF NOT EXISTS orleans.membership
(
    deployment_id character varying(150) NOT NULL,
    address character varying(45) NOT NULL,
    port integer NOT NULL,
    generation integer NOT NULL,
    silo_name character varying(150) NOT NULL,
    host_name character varying(150) NOT NULL,
    status integer NOT NULL,
    proxy_port integer NULL,
    suspect_times text NULL,
    start_time timestamp(3) NOT NULL,
    i_am_alive_time timestamp(3) NOT NULL,

    CONSTRAINT "PK_MembershipTable_DeploymentId" PRIMARY KEY (deployment_id, address, port, generation),
    CONSTRAINT "FK_MembershipTable_MembershipVersionTable_DeploymentId" FOREIGN KEY (deployment_id) REFERENCES orleans.membership_version (deployment_id)
);


CREATE OR REPLACE FUNCTION orleans.update_i_am_alive_time(
    _deployment_id orleans.membership.deployment_id%TYPE,
    _address orleans.membership.address%TYPE,
    _port orleans.membership.port%TYPE,
    _generation orleans.membership.generation%TYPE,
    _i_am_alive_time orleans.membership.i_am_alive_time%TYPE)
  RETURNS void AS
$func$
BEGIN
    -- This is expected to never fail by Orleans, so return value
    -- is not needed nor is it checked.
    UPDATE orleans.membership as d
    SET
        i_am_alive_time = _i_am_alive_time
    WHERE
        d.deployment_id = _deployment_id AND _deployment_id IS NOT NULL
        AND d.address = _address AND _address IS NOT NULL
        AND d.port = _port AND _port IS NOT NULL
        AND d.generation = _generation AND _generation IS NOT NULL;
END
$func$ LANGUAGE plpgsql;


INSERT INTO "OrleansQuery" ("QueryKey", "QueryText")
VALUES
(
    'UpdateIAmAlivetimeKey',
    '-- This is expected to never fail by Orleans, so return value
    -- is not needed nor is it checked.
    SELECT * FROM orleans.update_i_am_alive_time(
        @DeploymentId,
        @Address,
        @Port,
        @Generation,
        @IAmAliveTime
    );'
)
ON CONFLICT ("QueryKey") DO UPDATE SET "QueryText"=excluded."QueryText";


CREATE OR REPLACE FUNCTION orleans.insert_membership_version(
    _deployment_id orleans.membership.deployment_id%TYPE
)
  RETURNS TABLE(row_count integer) AS
$func$
DECLARE
    _row_count int := 0;
BEGIN
    BEGIN
        INSERT INTO orleans.membership_version
        (
            deployment_id
        )
        SELECT _deployment_id
        ON CONFLICT (deployment_id) DO NOTHING;

        GET DIAGNOSTICS _row_count = ROW_COUNT;

        ASSERT _row_count <> 0, 'no rows affected, rollback';

        RETURN QUERY SELECT _row_count;
    EXCEPTION
    WHEN assert_failure THEN
        RETURN QUERY SELECT _row_count;
    END;
END
$func$ LANGUAGE plpgsql;


INSERT INTO "OrleansQuery" ("QueryKey", "QueryText")
VALUES
(
    'InsertMembershipVersionKey',
    'SELECT * FROM orleans.insert_membership_version(
        @DeploymentId
    );'
)
ON CONFLICT ("QueryKey") DO UPDATE SET "QueryText"=excluded."QueryText";


CREATE OR REPLACE FUNCTION orleans.insert_membership(
    _deployment_id orleans.membership.deployment_id%TYPE,
    _address orleans.membership.address%TYPE,
    _port orleans.membership.port%TYPE,
    _generation orleans.membership.generation%TYPE,
    _silo_name orleans.membership.silo_name%TYPE,
    _host_name orleans.membership.host_name%TYPE,
    _status orleans.membership.status%TYPE,
    _proxy_port orleans.membership.proxy_port%TYPE,
    _start_time orleans.membership.start_time%TYPE,
    _i_am_alive_time orleans.membership.i_am_alive_time%TYPE,
    _version orleans.membership_version.version%TYPE)
  RETURNS TABLE(row_count integer) AS
$func$
DECLARE
    _row_count int := 0;
BEGIN
    BEGIN
        INSERT INTO orleans.membership
        (
            deployment_id,
            address,
            port,
            generation,
            silo_name,
            host_name,
            status,
            proxy_port,
            start_time,
            i_am_alive_time
        )
        SELECT
            _deployment_id,
            _address,
            _port,
            _generation,
            _silo_name,
            _host_name,
            _status,
            _proxy_port,
            _start_time,
            _i_am_alive_time
        ON CONFLICT (deployment_id, address, port, generation) DO
            NOTHING;

        GET DIAGNOSTICS _row_count = ROW_COUNT;

        UPDATE orleans.membership_version
        SET
            "timestamp" = (now() at time zone 'utc'),
            version = version + 1
        WHERE
            deployment_id = _deployment_id AND _deployment_id IS NOT NULL
            AND version = _version AND _version IS NOT NULL
            AND _row_count > 0;

        GET DIAGNOSTICS _row_count = ROW_COUNT;

        ASSERT _row_count <> 0, 'no rows affected, rollback';


        RETURN QUERY SELECT _row_count;
    EXCEPTION
    WHEN assert_failure THEN
        RETURN QUERY SELECT _row_count;
    END;
END
$func$ LANGUAGE plpgsql;


INSERT INTO "OrleansQuery" ("QueryKey", "QueryText")
VALUES
(
    'InsertMembershipKey',
    'SELECT * FROM orleans.insert_membership(
        @DeploymentId,
        @Address,
        @Port,
        @Generation,
        @SiloName,
        @HostName,
        @Status,
        @ProxyPort,
        @StartTime,
        @IAmAliveTime,
        @Version
    );'
)
ON CONFLICT ("QueryKey") DO UPDATE SET "QueryText"=excluded."QueryText";


CREATE OR REPLACE FUNCTION orleans.update_membership(
    _deployment_id orleans.membership.deployment_id%TYPE,
    _address orleans.membership.address%TYPE,
    _port orleans.membership.port%TYPE,
    _generation orleans.membership.generation%TYPE,
    _status orleans.membership.status%TYPE,
    _suspect_times orleans.membership.suspect_times%TYPE,
    _i_am_alive_time orleans.membership.i_am_alive_time%TYPE,
    _version orleans.membership_version.version%TYPE
  )
  RETURNS TABLE(row_count integer) AS
$func$
DECLARE
    _row_count int := 0;
BEGIN
    BEGIN

    UPDATE orleans.membership_version
    SET
        "timestamp" = (now() at time zone 'utc'),
        version = version + 1
    WHERE
        deployment_id = _deployment_id AND _deployment_id IS NOT NULL
        AND version = _version AND _version IS NOT NULL;


    GET DIAGNOSTICS _row_count = ROW_COUNT;

    UPDATE orleans.membership
    SET
        status = _status,
        suspect_times = _suspect_times,
        i_am_alive_time = _i_am_alive_time
    WHERE
        deployment_id = _deployment_id AND _deployment_id IS NOT NULL
        AND address = _address AND _address IS NOT NULL
        AND port = _port AND _port IS NOT NULL
        AND generation = _generation AND _generation IS NOT NULL
        AND _row_count > 0;


        GET DIAGNOSTICS _row_count = ROW_COUNT;

        ASSERT _row_count <> 0, 'no rows affected, rollback';


        RETURN QUERY SELECT _row_count;
    EXCEPTION
    WHEN assert_failure THEN
        RETURN QUERY SELECT _row_count;
    END;
END
$func$ LANGUAGE plpgsql;


INSERT INTO "OrleansQuery" ("QueryKey", "QueryText")
VALUES
(
    'UpdateMembershipKey',
    'SELECT * FROM orleans.update_membership(
        @DeploymentId,
        @Address,
        @Port,
        @Generation,
        @Status,
        @SuspectTimes,
        @IAmAliveTime,
        @Version
    );'
)
ON CONFLICT ("QueryKey") DO UPDATE SET "QueryText"=excluded."QueryText";


INSERT INTO "OrleansQuery" ("QueryKey", "QueryText")
VALUES
(
    'MembershipReadRowKey',
    'SELECT
        v.deployment_id,
        m.address,
        m.port,
        m.generation,
        m.silo_name,
        m.host_name,
        m.status,
        m.proxy_port,
        m.suspect_times,
        m.start_time,
        m.i_am_alive_time,
        v.version
    FROM
 orleans.membership_version v
        -- This ensures the version table will returned even if there is no matching membership row.
        LEFT OUTER JOIN orleans.membership m ON v.deployment_id = m.deployment_id
        AND address = @Address AND @Address IS NOT NULL
        AND port = @Port AND @Port IS NOT NULL
        AND generation = @Generation AND @Generation IS NOT NULL
    WHERE
        v.deployment_id = @DeploymentId AND @DeploymentId IS NOT NULL;'
)
ON CONFLICT ("QueryKey") DO UPDATE SET "QueryText"=excluded."QueryText";


INSERT INTO "OrleansQuery" ("QueryKey", "QueryText")
VALUES
(
    'MembershipReadAllKey',
    'SELECT
        v.deployment_id,
        m.address,
        m.port,
        m.generation,
        m.silo_name,
        m.host_name,
        m.status,
        m.proxy_port,
        m.suspect_times,
        m.start_time,
        m.i_am_alive_time,
        v.version
    FROM
 orleans.membership_version v LEFT OUTER JOIN orleans.membership m
        ON v.deployment_id = m.deployment_id
    WHERE
        v.deployment_id = @DeploymentId AND @DeploymentId IS NOT NULL;'
)
ON CONFLICT ("QueryKey") DO UPDATE SET "QueryText"=excluded."QueryText";


INSERT INTO "OrleansQuery" ("QueryKey", "QueryText")
VALUES
(
    'DeleteMembershipTableEntriesKey',
    'DELETE FROM orleans.membership
    WHERE deployment_id = @DeploymentId AND @DeploymentId IS NOT NULL;
    DELETE FROM orleans.membership_version
    WHERE deployment_id = @DeploymentId AND @DeploymentId IS NOT NULL;'
)
ON CONFLICT ("QueryKey") DO UPDATE SET "QueryText"=excluded."QueryText";


INSERT INTO "OrleansQuery" ("QueryKey", "QueryText")
VALUES
(
    'GatewaysQueryKey',
    'SELECT
        address,
        proxy_port,
        generation
    FROM
 orleans.membership
    WHERE
        deployment_id = @DeploymentId AND @DeploymentId IS NOT NULL
        AND status = @Status AND @Status IS NOT NULL
        AND proxy_port > 0;'
)
ON CONFLICT ("QueryKey") DO UPDATE SET "QueryText"=excluded."QueryText";