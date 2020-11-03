rem @echo off
rem Prerequisites: AWS CLI for Windows
rem BATCH FILE specific for getting all RDS related settings
rem First authenticate with your weapon of choice, and ensure you have the .aws directory in your user-profile
rem with the config (depicting the region of choice e.g. eu-west-1), and the credentials, which can be created 
rem either using nn-auth, aws-adfs-cli-mfa. (e.g. nn-auth aws --interactive --no-proxy) or using any tool that can download the Credentials such as the saml to sts convertor.
rem minimum account privilege is read-only (describe & get)
rem Revisions:
rem V0.1 GM 11/06/2020
rem V0.2 GM added the lookup on security groups (Test 21) 16-6-2020
rem V0.3 GM Added the account alias, added a few performance tweaks (not traversing arrays), check on public databases, and certificate expiration 16-6-2020
rem V0.4 GM Added the generic overview of all databases in an account (inlcuding their settings), and added the database logging part.
rem
FOR /F "tokens=*" %%F IN ('aws sts get-caller-identity --query "Account" --output text') DO (
SET account=%%F
)
FOR /F "tokens=*" %%F IN ('aws iam list-account-aliases --query [AccountAliases] --output text') DO (
SET alias=%%F
)

echo -- ACCOUNT -- >> EVIDENCE.TXT
aws iam list-account-aliases --query [AccountAliases[ >> EVIDENCE.TXT
aws sts get-caller-identity --output text >> EVIDENCE.TXT
rem This line is needed to see which db instances are in an account
aws rds describe-db-instances --output text --query "DBInstances[*].[DBInstanceIdentifier]" >> dbidentifiers.TXT
echo -- INFO #1 -- >> EVIDENCE.TXT
echo List all properties of databases >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A --- ALL DB SETTINGS --- >> EVIDENCE.TXT & aws rds describe-db-instances --db-instance-identifier %%A --output table >> EVIDENCE.TXT
echo -- INFO # 2 -- >> EVIDENCE.TXT
echo DB snapshots on the account >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Snapshots >> EVIDENCE.txt & aws rds describe-db-snapshots --db-instance-identifier %%A --output table >> EVIDENCE.TXT
echo -- TEST #0.1 -- >> EVIDENCE.TXT
echo Determine whether database logging is enabled. >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A --- LOGGING --- >> EVIDENCE.txt & aws rds describe-db-log-files --db-instance-identifier %%A --output table >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do aws rds describe-db-log-files --db-instance-identifier %%A --output text >> DBLOGGING.TXT
rem Placeholder for downloading the logfiles, need to change this, due to the fact that it is not supported by AWS. Need to format it into an API request in the future.
echo -- TEST #0.2 -- >> EVIDENCE.TXT
echo Logfiles are stored in different directories.
echo Downloading logfiles. >> EVIDENCE.TXT

FOR /F %%A in (dbidentifiers.TXT) do md %%A
FOR /F %%A in (dbidentifiers.TXT) do md %%A\audit
FOR /F %%A in (dbidentifiers.TXT) do md %%A\log
FOR /F %%A in (dbidentifiers.TXT) do md %%A\trace

setlocal EnableDelayedExpansion  

FOR /F %%A in (dbidentifiers.txt) do (
    aws rds describe-db-log-files --db-instance-identifier %%A --query "DescribeDBLogFiles[*].LogFileName" --output text >> ./%%A/%%A.TXT"
    for /f %%B in (%%A/%%A.TXT) do (
        aws rds download-db-log-file-portion --db-instance-identifier "%%A" --log-file-name "%%B" --output text >> ./%%A/%%B"
    )
)
echo -- TEST #1 -- >> EVIDENCE.TXT
echo Determine whether any of the snapshots that were created are public test (GDPR, NIST, PCI-DSS) >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Snapshots >> EVIDENCE.txt & aws rds describe-db-snapshots --db-instance-identifier %%A --snapshot-type public --output table >> EVIDENCE.TXT
echo -- TEST #2 -- >> EVIDENCE.TXT
echo Determine whether any of the snapshots that were created are shared test (GDPR, NIST, PCI-DSS) >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Snapshots >> EVIDENCE.txt & aws rds describe-db-snapshots --db-instance-identifier %%A --snapshot-type shared --output table >> EVIDENCE.TXT
echo -- TEST #3 -- >> EVIDENCE.TXT
echo Determine whether any of the snapshots that were created are manual >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Snapshots >> EVIDENCE.txt & aws rds describe-db-snapshots --db-instance-identifier %%A --snapshot-type manual --output table >> EVIDENCE.TXT
echo -- TEST #5 -- >> EVIDENCE.TXT
echo Determine whether any of the snapshots that were created are performed by the AWS backup service >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Snapshots >> EVIDENCE.txt & aws rds describe-db-snapshots --db-instance-identifier %%A --snapshot-type automated --output table >> EVIDENCE.TXT
echo -- TEST #6 -- >> EVIDENCE.TXT
echo describe the instance class of the database to determine whether any of the legacy instance classes is used >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A DBinstance >> EVIDENCE.txt & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].DBInstanceClass" --output table >> EVIDENCE.TXT
echo -- TEST #7 -- >> EVIDENCE.TXT
echo show all database parameters associated with a database >> EVIDENCE.TXT
rem TODO: Below This section needs to be aligned with the SQL / ORACLE SAG
FOR /F %%A in (dbidentifiers.TXT) do aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].DBParameterGroups[*].DBParameterGroupName[]" --output text >> DBPARGROUP2.TXT
setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (DBPARGROUP2.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> DBPARGROUP3.txt
      set "prevLine=%%a"
   )
)
FOR /F %%A in (DBPARGROUP3.TXT) do echo %%A Database parameters >> EVIDENCE.txt & aws rds describe-db-parameters --db-parameter-group-name %%A --query "Parameters[*].[ParameterName,ParameterValue]" --output table >> EVIDENCE.TXT
rem --- End of section --- 
echo -- TEST #8 -- >> EVIDENCE.TXT
echo Determine whether any transport encryption is being used (Postgresql and mssql only) >> EVIDENCE.TXT
aws rds describe-db-instances --output text --query "DBInstances[*].[DBInstanceIdentifier]" --filters Name=engine,Values=sqlserver-se,postgres >> transport.TXT
FOR /F %%A in (transport.TXT) do aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].DBParameterGroups[*].DBParameterGroupName[]" --output text >> DBPARGROUP.TXT
FOR /F %%A in (DBPARGROUP.TXT) do echo %%A Transport "0 SSL, 1 SSL" >> EVIDENCE.txt & aws rds describe-db-parameters --db-parameter-group-name %%A --query "Parameters[?ParameterName=="rds.force_ssl"].ParameterValue" --output text >> EVIDENCE.TXT
echo -- TEST #9 -- >> EVIDENCE.TXT
echo Determine whether Mysql Aurora or MariaDB are using log exports to cloudwatch if no entries show up, there might be no mariadb or aurora, or no log exports have been setup >> EVIDENCE.TXT
aws rds describe-db-instances --output text --query "DBInstances[*].[DBInstanceIdentifier]" --filters Name=engine,Values=mysql,aurora,aurora-mysql,mariadb >> export.TXT
echo instances using mysql,aurora or mariadb >>EVIDENCE.TXT
type ./export.txt >> EVIDENCE.TXT
FOR /F %%A in (export.TXT) do echo %%A export cloudwatch >> EVIDENCE.TXT & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].EnabledCloudwatchLogsExports" --output text >> EVIDENCE.TXT
echo -- TEST #10 -- >> EVIDENCE.TXT
echo Determine whether databases are protected against deletion, no results here mean no databases are protected >> EVIDENCE.TXT
FOR /F %%A in (export.TXT) do echo %%A export DELETION PROTECTION & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].DeletionProtection" --output text >> EVIDENCE.TXT
echo -- TEST #11 -- >> EVIDENCE.TXT
echo Determine whether event subscriptions are attached to the RDS environment of AWS (no output means no subscriptions) >> EVIDENCE.TXT
echo %%A >> EVIDENCE.TXT & aws rds describe-event-subscriptions --query "EventSubscriptionsList[?SourceType == 'db-instance'].CustSubscriptionId" --output text >> EVIDENCE.TXT
echo -- TEST #12 -- >> EVIDENCE.TXT
echo Determine whether auto minor version upgrade is enabled (Lifecycle management) >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A minor version upgrade >> EVIDENCE.TXT & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].AutoMinorVersionUpgrade" --output table >> EVIDENCE.TXT
echo -- TEST #13 -- >> EVIDENCE.TXT
echo Determine whether auto backups are enabled >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Auto-backup retention period in # of days >> EVIDENCE.TXT & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].[DBInstanceIdentifier,BackupRetentionPeriod]" --output text >> EVIDENCE.TXT
echo -- TEST #14 -- >> EVIDENCE.TXT
echo Determine whether tagging to snapshots is enabled >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Snapshot tagging >> EVIDENCE.TXT & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].CopyTagsToSnapshot" --output table >> EVIDENCE.TXT
echo -- TEST #15 -- >> EVIDENCE.TXT
echo Determine whether Default ports are used for Database servers  Aurora/Mysql/MariaDB 3306, PostgreSQL 5432, Oracle 1521, SqlServer 1433 >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A ports >> EVIDENCE.TXT & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].[DBInstanceIdentifier,Engine,EngineVersion,Endpoint.Port]" --output text >> EVIDENCE.TXT
echo -- TEST #16 -- >> EVIDENCE.TXT
echo Determine whether the instances in your AWS account have the desired instance type >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Instance type >> EVIDENCE.TXT & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceClass]" --output text >> EVIDENCE.TXT
echo -- TEST #17 -- >> EVIDENCE.TXT
echo Determine whether the instances in your AWS are encrypted >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do echo %%A Encryption >> EVIDENCE.TXT & aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].[DBInstanceIdentifier,StorageEncrypted,KmsKeyId]" --output table >> EVIDENCE.TXT
echo -- TEST #18 -- >> EVIDENCE.TXT
echo Determine whether the databases are in public subnets >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].DBSubnetGroup.Subnets[*].SubnetIdentifier" --output text >> subnets.txt
setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (subnets.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> subnets2.txt
      set "prevLine=%%a"
   )
)
del subnets.txt /s
FOR /F %%A in (subnets2.TXT) do echo Databases in public subnets look for 0.0.0.0 routes >> EVIDENCE.TXT & aws ec2 describe-route-tables --query "RouteTables[*].Routes[]" --output text >> EVIDENCE.txt
echo -- TEST #19 -- >> EVIDENCE.TXT
echo Determine whether the databases are using common names for master logon >> EVIDENCE.TXT
FOR /F %%A in (dbidentifiers.TXT) do aws rds describe-db-instances --db-instance-identifier %%A --query "DBInstances[*].[DBInstanceIdentifier,MasterUsername]" --output text >> EVIDENCE.txt
echo -- TEST #20 -- >> EVIDENCE.TXT
echo Determine whether the databases security groups are not allowsing too much traffic (only applicable for accounts created before 04-12-2013 >> EVIDENCE.TXT
aws rds describe-db-security-groups --query "DBSecurityGroups[*].DBSecurityGroupName" --output text >> DBSEC.txt
FOR /F %%A in (DBSEC.TXT) do aws rds describe-db-security-groups --db-security-group-name %%A --query "DBSecurityGroups[*].[DBSecurityGroupName,IpRanges.CIDRIP]" --output text >> EVIDENCE.txt
echo -- TEST #21 -- >> EVIDENCE.TXT
echo determine security groups >> EVIDENCE.TXT
aws rds describe-db-instances --query "DBInstances[*].[VpcSecurityGroups[*].VpcSecurityGroupId]" --output text >> SECGRP.TXT
setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (SECGRP.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> SECGRP2.txt
      set "prevLine=%%a"
   )
)
FOR /F %%A in (SECGRP2.TXT) do aws ec2 describe-security-groups --group-ids %%A --output table >> EVIDENCE.TXT
echo -- TEST #22 -- >> EVIDENCE.TXT
echo Checking public availability of Databases >> EVIDENCE.TXT
aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier,PubliclyAccessible]" --output table >> EVIDENCE.TXT
echo -- TEST #23 -- >> EVIDENCE.TXT
echo Check Certificate expiration >> EVIDENCE.TXT
aws rds describe-certificates --output table >> EVIDENCE.TXT
rem Rename the evidence file to the account #
rename EVIDENCE.TXT RDS-%alias%-%account%.txt
rem CLEANUP!
del account.TXT /s
del alias.txt /s
del export.txt /s
del DBLOGGING.TXT /s
del DBPARGROUP.TXT /s
del DBPARGROUP2.TXT /s
del DBPARGROUP3.TXT /s
del transport.txt /s
del DBSEC.txt /s
del subnets2.txt /s
del secgrp.txt /s
del secgrp2.txt /s
del dbidentifiers.txt /s
