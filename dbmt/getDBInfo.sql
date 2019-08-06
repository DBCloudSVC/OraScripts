set line 170
set pages 1000
set trimspool on
set trimout on
set feedback 200
set newpage none

col host_name for a35
col instance_name for a15
col status for a15
col version for a15

prompt ===============Instance basic information===============
SELECT host_name,
       instance_name,
       version,
       status
FROM   v$instance;

prompt ===============Database basic information===============
SELECT NAME,
       DB_UNIQUE_NAME,
       OPEN_MODE,
       DATABASE_ROLE
FROM   v$database;

prompt ===============Total database size===============
SELECT Sum(tsize) / 1024 / 1024 / 1024 AS TOTAL_SIZE_GB
FROM   (SELECT bytes AS tsize
        FROM   v$datafile
        UNION ALL
        SELECT bytes AS tsize
        FROM   v$tempfile
        UNION ALL
        SELECT bytes * members AS tsize
        FROM   v$log);

col member for a70
prompt ===============Logfile information===============
SELECT THREAD#,
       vl.GROUP#,
       MEMBER,
       BYTES / 1024 / 1024 MB
FROM   v$log vl,
       v$logfile vlf
WHERE  vl.group# = vlf.group#;

col FORCE_LOGGING for a13
prompt ===============Tablespace list===============
SELECT TABLESPACE_NAME,
       BLOCK_SIZE,
       LOGGING,
       FORCE_LOGGING
FROM   dba_tablespaces;

col AUTOEXTENSIBLE for a7
col ONLINE_STATUS for a13
col FILE_NAME for a60
prompt ===============Tablespaces and datafiles===============
SELECT TABLESPACE_NAME,
       'Data'                 AS type,
       FILE_NAME,
       BYTES / 1024 / 1024    MB,
       STATUS,
       AUTOEXTENSIBLE,
       MAXBYTES / 1024 / 1024 MAX_MB,
       ONLINE_STATUS
FROM   dba_data_files
UNION ALL
SELECT TABLESPACE_NAME,
       'Temp'                 AS type,
       FILE_NAME,
       BYTES / 1024 / 1024    MB,
       STATUS,
       AUTOEXTENSIBLE,
       MAXBYTES / 1024 / 1024 MAX_MB,
       'TEMPFILE'             AS ONLINE_STATUS
FROM   dba_temp_files
ORDER  BY type,
          TABLESPACE_NAME;

prompt ===============Free space in datafiles===============
SELECT   FILE_NAME,
         CEIL( (NVL(HWM,1) * DBATP.BLOCK_SIZE) / 1024 / 1024 )                                                  SMALLEST,
         CEIL( BLOCKS * DBATP.BLOCK_SIZE / 1024 / 1024)                                                         CURRSIZE,
         CEIL( BLOCKS * DBATP.BLOCK_SIZE / 1024 / 1024) - CEIL( (NVL(HWM,1) * DBATP.BLOCK_SIZE) / 1024 / 1024 ) Shrinkable
FROM     DBA_DATA_FILES DBADF,
         DBA_TABLESPACES DBATP,
         ( SELECT  FILE_ID,
                           MAX(BLOCK_ID + BLOCKS-1) HWM
                  FROM     DBA_EXTENTS
                  GROUP BY FILE_ID ) DBAFS
WHERE    DBADF.FILE_ID = DBAFS.FILE_ID(+)
         AND DBADF.TABLESPACE_NAME = DBATP.TABLESPACE_NAME
ORDER BY 4 DESC;

col Status for a10;
col Name for a30;
col Type for a15;
col Ext_Management for a15;
col MaxSize(M) for 9999990.99 justify right;
col CurSize(M) for 9999990.99 justify right;
col Used(M) for 9999990.99 justify right;
col Free(M) for 9999990.99 justify right;
col Used% for 990.99 justify right;
col Raise for a15 justify left;
prompt ===============Tablespace type and usage===============
SELECT d.status "Status",
       d.tablespace_name "Name",
       d.contents "Type",
       d.extent_management "Ext_Management",
       NVL(a.maxbytes / 1024 / 1024, 0) "MaxSize(M)",
       NVL(a.bytes    / 1024 / 1024, 0) "CurSize(M)",
       NVL(a.bytes    - NVL(f.bytes, 0), 0) / 1024 / 1024 "Used(M)",
       NVL(NVL(f.bytes, 0), 0) / 1024 / 1024 "Free(M)",
       NVL((a.bytes - NVL(f.bytes, 0)) / a.maxbytes * 100, 0) "Used%", (
       CASE
              WHEN to_number(NVL((a.bytes - NVL(f.bytes, 0)) / a.maxbytes * 100, 00)) >= 85 THEN 'Warning'
       END) AS "Raise"
FROM   sys.dba_tablespaces d,
       (SELECT  tablespace_name,
                         SUM(bytes)                                                       bytes,
                         SUM(greatest(DECODE(AUTOEXTENSIBLE,'YES',MAXBYTES,BYTES),BYTES)) maxbytes
                FROM     dba_data_files
                GROUP BY tablespace_name) a,
       (SELECT  tablespace_name,
                         SUM(bytes) bytes
                FROM     dba_free_space
                GROUP BY tablespace_name) f
WHERE  d.tablespace_name = a.tablespace_name(+)
       AND d.tablespace_name = f.tablespace_name(+)
       AND NOT (d.extent_management LIKE 'LOCAL'
              AND d.contents LIKE 'TEMPORARY')
UNION ALL
SELECT   d.status "Status",
         d.tablespace_name "Name",
         d.contents "Type",
         d.extent_management "Ext_Management",
         NVL(a.maxbytes / 1024 / 1024, 0) "MaxSize(M)",
         NVL(a.bytes    / 1024 / 1024, 0) "CurSize(M)",
         NVL(t.bytes, 0) / 1024 / 1024 "Used(M)",
         (NVL(a.bytes / 1024 / 1024, 0)) - (NVL(t.bytes, 0) / 1024 / 1024) "Free(M)",
         NVL(t.bytes / a.maxbytes * 100, 0) "Used%", (
         CASE
                  WHEN to_number(NVL((NVL(t.bytes, 0)) / a.maxbytes * 100, 00)) >= 85 THEN 'Warning'
         END) AS "Raise"
FROM     sys.dba_tablespaces d,
         (SELECT  tablespace_name,
                           SUM(bytes)                                       bytes,
                           SUM(DECODE(AUTOEXTENSIBLE,'YES',MAXBYTES,BYTES)) maxbytes
                  FROM     dba_temp_files
                  GROUP BY tablespace_name) a,
         (SELECT  tablespace_name,
                           SUM(vt.blocks * dt.block_size) bytes
                  FROM     v$tempseg_usage vt,
                           dba_tablespaces dt
                  WHERE    vt.tablespace = dt.tablespace_name
                  GROUP BY tablespace_name) t
WHERE    d.tablespace_name = a.tablespace_name(+)
         AND d.tablespace_name = t.tablespace_name(+)
         AND d.extent_management LIKE 'LOCAL'
         AND d.contents LIKE 'TEMPORARY'
ORDER BY "Used%" DESC;

prompt ===============Invalid user objects===============
SELECT OWNER,
       OBJECT_TYPE,
       OBJECT_NAME
FROM   dba_objects
WHERE  STATUS <> 'VALID'
       AND owner NOT IN ( 'SYS', 'SYSTEM' );

col segment_name for a40
prompt ===============List TOP 20 large segments===============
SELECT *
FROM   (SELECT OWNER,
               SEGMENT_TYPE,
               SEGMENT_NAME,
               BYTES / 1024 / 1024 MB
        FROM   dba_segments
        ORDER  BY MB DESC)
WHERE  rownum < 21;

prompt ===============Process information===============
SELECT PID,
       SPID,
       USERNAME,
       SERIAL#,
       PROGRAM,
       PGA_USED_MEM,
       PGA_ALLOC_MEM,
       PGA_MAX_MEM
FROM   v$process
WHERE  BACKGROUND IS NULL;

col machine for a30
col osuser for a15
col username for a15
prompt ===============Session information===============
SELECT SID,
       SERIAL#,
       USERNAME,
       OSUSER,
       MACHINE,
       PROGRAM,
       LOGON_TIME,
       CURRENT_QUEUE_DURATION
FROM   v$session;

prompt ===============Extent information of user segments===============
SELECT OWNER,
       SEGMENT_NAME,
       SEGMENT_TYPE,
       TABLESPACE_NAME,
       Count(*)                 NO_Extents,
       Max(BYTES / 1024 / 1024) MAX_Extent,
       Sum(BYTES / 1024 / 1024) Total_MB
FROM   dba_extents
WHERE  owner NOT IN ( 'SYS', 'SYSTEM', 'XDB', 'WMSYS',
                      'DBSNMP', 'OUTLN' )
GROUP  BY OWNER,
          SEGMENT_NAME,
          SEGMENT_TYPE,
          TABLESPACE_NAME;

col value for a40
prompt ===============List some important parameters===============
SELECT NAME,
       VALUE,
       ISDEFAULT,
       ISMODIFIED
FROM   v$parameter
WHERE  NAME IN ( 'cpu_count', 'shared_pool_size', 'large_pool_size', 'java_pool_size',
                 'streams_pool_size', 'filesystemio_options', 'disk_asynch_io', 'sga_target',
                 'memory_target', 'db_file_name_convert', 'log_file_name_convert', 'db_keep_cache_size',
                 'db_recycle_cache_size', 'log_archive_config', 'log_buffer', 'db_file_multiblock_read_count',
                 'db_create_file_dest', 'db_recovery_file_dest', 'sec_case_sensitive_logon', 'remote_login_passwordfile',
                 'db_domain', 'global_names', 'local_listener', 'remote_listener',
                 'cursor_space_for_time', 'session_cached_cursors', 'job_queue_processes', 'cursor_sharing',
                 'deferred_segment_creation', 'pga_aggregate_target', 'optimizer_index_cost_adj', 'optimizer_index_caching',
                 'query_rewrite_enabled', 'client_result_cache_size', 'client_result_cache_lag', 'asm_diskstring', 'asm_diskgroups' );