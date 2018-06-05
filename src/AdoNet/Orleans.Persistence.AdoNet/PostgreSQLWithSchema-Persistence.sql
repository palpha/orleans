CREATE TABLE IF NOT EXISTS orleans.storage
(
    grain_id_hash integer NOT NULL,
    grain_id_n0 bigint NOT NULL,
    grain_id_n1 bigint NOT NULL,
    grain_type_hash integer NOT NULL,
    grain_type_string character varying(512) NOT NULL,
    grain_id_extension_string character varying(512),
    service_id character varying(150) NOT NULL,
    payload_binary bytea,
    payload_xml xml,
    payload_json jsonb,
    modified_on timestamp without time zone NOT NULL,
    version integer
);


CREATE INDEX IF NOT EXISTS ix_storage ON orleans.storage USING btree (grain_id_hash, grain_type_hash);


CREATE OR REPLACE FUNCTION orleans.write_to_storage(
    _grain_id_hash orleans.storage.grain_id_hash%TYPE,
    _grain_id_n0 orleans.storage.grain_id_n0%TYPE,
    _grain_id_n1 orleans.storage.grain_id_n0%TYPE,
    _grain_type_hash orleans.storage.grain_type_hash%TYPE,
    _grain_type_string orleans.storage.grain_type_string%TYPE,
    _grain_id_extension_string orleans.storage.grain_id_extension_string%TYPE,
    _service_id orleans.storage.service_id%TYPE,
    _grain_state_version orleans.storage.version%TYPE,
    _payload_binary orleans.storage.payload_binary%TYPE,
    _payload_json orleans.storage.payload_json%TYPE,
    _payload_xml orleans.storage.payload_xml%TYPE
  )
  RETURNS TABLE(new_grain_state_version integer) AS
$func$
DECLARE
    _new_grain_state_version integer := _grain_state_version;
    _row_count integer := 0;
BEGIN
    -- Grain state is not null, so the state must have been read from the storage before.
    -- Let's try to update it.
    --
    -- When Orleans is running in normal, non-split state, there will
    -- be only one grain with the given ID and type combination only. This
    -- grain saves states mostly serially if Orleans guarantees are upheld. Even
    -- if not, the updates should work correctly due to version number.
    --
    -- In split brain situations there can be a situation where there are two or more
    -- grains with the given ID and type combination. When they try to INSERT
    -- concurrently, the table needs to be locked pessimistically before one of
    -- the grains gets @GrainStateVersion = 1 in return and the other grains will fail
    -- to update storage. The following arrangement is made to reduce locking in normal operation.
    --
    -- If the version number explicitly returned is still the same, Orleans interprets it so the pdate did not succeed
    -- and throws an InconsistentStateException.
    --
    -- See further information at http://dotnet.github.io/orleans/Getting-Started-With-Orleans/rain-Persistence.
    IF _grain_state_version IS NOT NULL
    THEN
        UPDATE orleans.storage
        SET
            payload_binary = _payload_binary,
            payload_json = _payload_json,
            payload_xml = _payload_xml,
            modified_on = (now() at time zone 'utc'),
            version = version + 1

        WHERE
            grain_id_hash = _grain_id_hash AND _grain_id_hash IS NOT NULL
            AND grain_type_hash = _grain_type_hash AND _grain_type_hash IS NOT NULL
            AND grain_id_n0 = _grain_id_n0 AND _grain_id_n0 IS NOT NULL
            AND grain_id_n1 = _grain_id_n1 AND _grain_id_n1 IS NOT NULL
            AND grain_type_string = _grain_type_string AND _grain_type_string IS NOT NULL
            AND
            (
                (
                    _grain_id_extension_string IS NOT NULL
                    AND grain_id_extension_string IS NOT NULL
                    AND grain_id_extension_string = _grain_id_extension_string
                )
                OR _grain_id_extension_string IS NULL
                AND grain_id_extension_string IS NULL
            )
            AND service_id = _service_id AND _service_id IS NOT NULL
            AND version IS NOT NULL AND version = _grain_state_version AND _grain_state_version IS NOT NULL;

        GET DIAGNOSTICS _row_count = ROW_COUNT;
        IF _row_count > 0
        THEN
            _new_grain_state_version := _grain_state_version + 1;
        END IF;
    END IF;

    -- The grain state has not been read. The following locks rather pessimistically
    -- to ensure only on INSERT succeeds.
    IF _grain_state_version IS NULL
    THEN
        INSERT INTO orleans.storage
        (
            grain_id_hash,
            grain_id_n0,
            grain_id_n1,
            grain_type_hash,
            grain_type_string,
            grain_id_extension_string,
            service_id,
            payload_binary,
            payload_json,
            payload_xml,
            modified_on,
            version
        )
        SELECT
            _grain_id_hash,
            _grain_id_n0,
            _grain_id_n1,
            _grain_type_hash,
            _grain_type_string,
            _grain_id_extension_string,
            _service_id,
            _payload_binary,
            _payload_json,
            _payload_xml,
            (now() at time zone 'utc'),
            1
        WHERE NOT EXISTS
         (
            -- There should not be any version of this grain state.
            SELECT 1
            FROM orleans.storage
            WHERE
                grain_id_hash = _grain_id_hash AND _grain_id_hash IS NOT NULL
                AND grain_type_hash = _grain_type_hash AND _grain_type_hash IS NOT NULL
                AND grain_id_n0 = _grain_id_n0 AND _grain_id_n0 IS NOT NULL
                AND grain_id_n1 = _grain_id_n1 AND _grain_id_n1 IS NOT NULL
                AND grain_type_string = _grain_type_string AND _grain_type_string IS NOT NULL
                AND
                (
                    (
                        _grain_id_extension_string IS NOT NULL
                        AND grain_id_extension_string IS NOT NULL
                        AND grain_id_extension_string = _grain_id_extension_string
                    )
                    OR _grain_id_extension_string IS NULL
                    AND grain_id_extension_string IS NULL
                )
                AND service_id = _service_id AND _service_id IS NOT NULL
         );

        GET DIAGNOSTICS _row_count = ROW_COUNT;
        IF _row_count > 0
        THEN
            _new_grain_state_version := 1;
        END IF;
    END IF;

    RETURN QUERY SELECT _new_grain_state_version;
END
$func$ LANGUAGE plpgsql;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'WriteToStorageKey',
    'SELECT * FROM orleans.write_to_storage(
        @GrainIdHash,
        @GrainIdN0,
        @GrainIdN1,
        @GrainTypeHash,
        @GrainTypeString,
        @GrainIdExtensionString,
        @ServiceId,
        @GrainStateVersion,
        @PayloadBinary,
        CAST(@PayloadJson AS jsonb),
        CAST(@PayloadXml AS xml)
    );'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'ReadFromStorageKey',
    'SELECT
        payload_binary,
        payload_xml,
        payload_json,
        (now() at time zone ''utc''),
        version
    FROM
 orleans.storage
    WHERE
        grain_id_hash = @GrainIdHash
        AND grain_type_hash = @GrainTypeHash AND @GrainTypeHash IS NOT NULL
        AND grain_id_n0 = @GrainIdN0 AND @GrainIdN0 IS NOT NULL
        AND grain_id_n1 = @GrainIdN1 AND @GrainIdN1 IS NOT NULL
        AND grain_type_string = @GrainTypeString AND GrainTypeString IS NOT NULL
        AND
        (
            (
                @GrainIdExtensionString IS NOT NULL
                AND grain_id_extension_string IS NOT NULL
                AND grain_id_extension_string = @GrainIdExtensionString
            )
            OR @GrainIdExtensionString IS NULL AND grain_id_extension_string IS NULL
        )
        AND service_id = @ServiceId AND @ServiceId IS NOT NULL;'
)
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;


INSERT INTO orleansquery (querykey, querytext)
VALUES
(
    'ClearStorageKey',
    'UPDATE orleans.storage
    SET
        payload_binary = NULL,
        payload_json = NULL,
        payload_xml = NULL,
        version = version + 1
    WHERE
        grain_id_hash = @GrainIdHash AND @GrainIdHash IS NOT NULL
        AND grain_type_hash = @GrainTypeHash AND @GrainTypeHash IS NOT NULL
        AND grain_id_n0 = @GrainIdN0 AND @GrainIdN0 IS NOT NULL
        AND grain_id_n1 = @GrainIdN1 AND @GrainIdN1 IS NOT NULL
        AND grain_type_string = @GrainTypeString AND @GrainTypeString IS NOT NULL
        AND
        (
            (
                @GrainIdExtensionString IS NOT NULL
                AND grain_id_extension_string IS NOT NULL
                AND grain_id_extension_string = @GrainIdExtensionString
            )
            OR @GrainIdExtensionString IS NULL AND grain_id_extension_string IS NULL
        )
        AND service_id = @ServiceId AND @ServiceId IS NOT NULL
        AND version IS NOT NULL AND version = @GrainStateVersion AND @GrainStateVersion IS NOT NULL
    RETURNING version;
')
ON CONFLICT (querykey) DO UPDATE SET querytext=excluded.querytext;