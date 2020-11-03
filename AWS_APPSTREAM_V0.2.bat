rem @echo off
rem Prerequisites: AWS CLI for Windows
rem BATCH FILE specific for getting all APPSTREAM related settings
rem First authenticate with your weapon of choice, and ensure you have the .aws directory in your user-profile
rem with the config (depicting the region of choice e.g. eu-west-1), and the credentials, which can be created 
rem either using nn-auth, aws-adfs-cli-mfa. (e.g. nn-auth aws --interactive --no-proxy) or using any tool that can download the Credentials such as the saml to sts convertor.
rem minimum account privilege is read-only (describe & get)
rem Revisions:
rem V0.1 GM 16/06/2020 initial version get stack and s3 bucket from stack
rem V0.2 GM 17/06/2020 Added fleets, images.
rem 
rem 
rem
FOR /F "tokens=*" %%F IN ('aws sts get-caller-identity --query "Account" --output text') DO (
SET account=%%F
)
FOR /F "tokens=*" %%F IN ('aws iam list-account-aliases --query "AccountAliases" --output text') DO (
SET alias=%%F
)

echo -- ACCOUNT -- >> EVIDENCE.TXT
aws iam list-account-aliases --query "AccountAliases" --output text >> EVIDENCE.TXT
aws sts get-caller-identity --output text >> EVIDENCE.TXT
rem This line is needed to see which appstream stacks are in an account
echo -- Stacks on %account% -- >> EVIDENCE.TXT
aws appstream describe-stacks --output table >> EVIDENCE.TXT
aws appstream describe-stacks --output text >> stacks.TXT
Echo ---- FLEETS on %account% ---- >> EVIDENCE.TXT
aws appstream describe-fleets --output table >> EVIDENCE.TXT
Echo ---- Images on %account% ---- >> EVIDENCE.TXT
aws appstream describe-images --output table >> EVIDENCE.TXT
aws appstream describe-images --output text --query "Images[*].Name" >> images.txt
echo ---- ANY Public images on the account? ---- >> EVIDENCE.TXT
aws appstream describe-images --query "Images[*].[Name,Visibility]" --output table >> EVIDENCE.TXT

echo -- INFO #1 -- S3 bucket settings related to the Fleets >> EVIDENCE.TXT

aws appstream describe-stacks --query "Stacks[*].StorageConnectors[*].ResourceIdentifier" --output text >> storageconnectors.txt
setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (storageconnectors.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> storageconnectors2.txt
      set "prevLine=%%a"
    )
 )
del storageconnectors.txt /s
FOR /F %%A in (storageconnectors2.TXT) do echo %%A S3 bucket >> EVIDENCE.txt & aws s3api get-bucket-encryption --bucket %%A --output table >> EVIDENCE.TXT
FOR /F %%A in (storageconnectors2.TXT) do echo %%A S3 bucket >> EVIDENCE.txt & aws s3api get-bucket-location --bucket %%A --output table >> EVIDENCE.TXT
FOR /F %%A in (storageconnectors2.TXT) do echo %%A S3 bucket >> EVIDENCE.txt & aws s3api get-bucket-logging --bucket %%A --output table >> EVIDENCE.TXT
FOR /F %%A in (storageconnectors2.TXT) do echo %%A S3 bucket >> EVIDENCE.txt & aws s3api get-bucket-policy --bucket %%A --output table >> EVIDENCE.TXT
FOR /F %%A in (storageconnectors2.TXT) do echo %%A S3 bucket >> EVIDENCE.txt & aws s3api get-bucket-policy-status --bucket %%A --output table >> EVIDENCE.TXT
FOR /F %%A in (storageconnectors2.TXT) do echo %%A S3 bucket >> EVIDENCE.txt & aws s3api get-bucket-versioning --bucket %%A --output table >> EVIDENCE.TXT
FOR /F %%A in (storageconnectors2.TXT) do echo %%A S3 bucket >> EVIDENCE.txt & aws s3api get-bucket-website --bucket %%A --output table >> EVIDENCE.TXT
del storageconnectors2.txt /s

rem aws appstream describe-images --output table





rem echo DB snapshots on the account >> EVIDENCE.TXT
rem FOR /F %%A in (dbidentifiers.TXT) do echo %%A Snapshots >> EVIDENCE.txt & aws rds describe-db-snapshots --db-instance-identifier %%A --output table >> EVIDENCE.TXT
rem echo -- TEST #1 -- >> EVIDENCE.TXT
rem echo Determine whether any of the snapshots that were created are public test (GDPR, NIST, PCI-DSS) >> EVIDENCE.TXT
rem FOR /F %%A in (dbidentifiers.TXT) do echo %%A Snapshots >> EVIDENCE.txt & aws rds describe-db-snapshots --db-instance-identifier %%A --snapshot-type public --output table >> EVIDENCE.TXT
rem echo -- TEST #2 -- >> EVIDENCE.TXT
rem setlocal EnableDelayedExpansion
rem set "prevLine="
rem for /F "delims=" %%a in (SECGRP.txt) do (
rem    if "%%a" neq "!prevLine!" (
rem       echo %%a >> SECGRP2.txt
rem       set "prevLine=%%a"
rem    )
rem )

rename EVIDENCE.TXT APPSTREAM-%alias%-%account%.txt
rem CLEANUP!
del stacks.txt /s

