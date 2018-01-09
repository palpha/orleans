-- Orleans Reminders table - http://dotnet.github.io/orleans/Advanced-Concepts/Timers-and-Reminders
CREATE TABLE IF NOT EXISTS orleans.reminders
(
    service_id character varying(150) NOT NULL,
    grain_id character varying(150) NOT NULL,
    reminder_name character varying(150) NOT NULL,
    start_time timestamp(3) NOT NULL,
    period integer NOT NULL,
    grain_hash integer NOT NULL,
    version integer NOT NULL,

    CONSTRAINT "PK_RemindersTable_ServiceId_GrainId_ReminderName" PRIMARY KEY (service_id, grain_id, reminder_name)
);


CREATE OR REPLACE FUNCTION orleans.upsert_reminder_row(
    _service_id orleans.reminders.service_id%TYPE,
    _grain_id orleans.reminders.grain_id%TYPE,
    _reminder_name orleans.reminders.reminder_name%TYPE,
    _start_time orleans.reminders.start_time%TYPE,
    _period orleans.reminders.period%TYPE,
    _grain_hash orleans.reminders.grain_hash%TYPE
  )
  RETURNS TABLE(version integer) AS
$func$
DECLARE
    _version_var int := 0;
BEGIN
    INSERT INTO orleans.reminders
    (
        service_id,
        grain_id,
        reminder_name,
        start_time,
        period,
        grain_hash,
        version
    )
    SELECT
        _service_id,
        _grain_id,
        _reminder_name,
        _start_time,
        _period,
        _grain_hash,
        0
    ON CONFLICT (service_id, grain_id, reminder_name)
        DO UPDATE SET
            start_time = excluded.start_time,
            period = excluded.period,
            grain_hash = excluded.grain_hash,
            version = orleans.reminders.version + 1
    RETURNING
 orleans.reminders.version INTO STRICT _version_var;

    RETURN QUERY SELECT _version_var;
END
$func$ LANGUAGE plpgsql;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'UpsertReminderRowKey',
    'SELECT * FROM orleans.upsert_reminder_row(
        @ServiceId,
        @GrainId,
        @ReminderName,
        @StartTime,
        @Period,
        @GrainHash
    );'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'ReadReminderRowsKey',
    'SELECT
        grain_id,
        reminder_name,
        start_time,
        period,
        version
    FROM orleans.reminders
    WHERE
        service_id = @ServiceId AND @ServiceId IS NOT NULL
        AND grain_id = @GrainId AND @GrainId IS NOT NULL;'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'ReadReminderRowKey',
    'SELECT
        grain_id,
        reminder_name,
        start_time,
        period,
        version
    FROM orleans.reminders
    WHERE
        service_id = @ServiceId AND @ServiceId IS NOT NULL
        AND grain_id = @GrainId AND @GrainId IS NOT NULL
        AND reminder_name = @ReminderName AND @ReminderName IS NOT NULL;'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'ReadRangeRows1Key',
    'SELECT
        grain_id,
        reminder_name,
        start_time,
        period,
        version
    FROM orleans.reminders
    WHERE
        service_id = @ServiceId AND @ServiceId IS NOT NULL
        AND grain_hash > @BeginHash AND @BeginHash IS NOT NULL
        AND grain_hash <= @EndHash AND @EndHash IS NOT NULL;'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'ReadRangeRows2Key',
    'SELECT
        grain_id,
        reminder_name,
        start_time,
        period,
        version
    FROM orleans.reminders
    WHERE
        service_id = @ServiceId AND @ServiceId IS NOT NULL
        AND ((grain_hash > @BeginHash AND @BeginHash IS NOT NULL)
        OR (grain_hash <= @EndHash AND @EndHash IS NOT NULL));'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


CREATE OR REPLACE FUNCTION orleans.delete_reminder_row(
    _service_id orleans.reminders.service_id%TYPE,
    _grain_id orleans.reminders.grain_id%TYPE,
    _reminder_name orleans.reminders.reminder_name%TYPE,
    _version orleans.reminders.version%TYPE
)
  RETURNS TABLE(row_count integer) AS
$func$
DECLARE
    _row_count int := 0;
BEGIN
    DELETE FROM orleans.reminders
    WHERE
        service_id = _service_id AND _service_id IS NOT NULL
        AND grain_id = _grain_id AND _grain_id IS NOT NULL
        AND reminder_name = _reminder_name AND _reminder_name IS NOT NULL
        AND version = _version AND _version IS NOT NULL;

    GET DIAGNOSTICS _row_count = ROW_COUNT;

    RETURN QUERY SELECT _row_count;
END
$func$ LANGUAGE plpgsql;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'DeleteReminderRowKey',
    'SELECT *
    FROM orleans.delete_reminder_row(
        @ServiceId,
        @GrainId,
        @ReminderName,
        @Version
    );'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'DeleteReminderRowsKey',
    'DELETE FROM orleans.reminders
    WHERE
        service_id = @ServiceId AND @ServiceId IS NOT NULL;'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;