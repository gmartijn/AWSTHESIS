rem @echo off
rem ----------------------------------------------------------------------------------------------
rem Work part of MSc thesis on misconfigurations on AWS IaaS cloud environments, G.D. Martijn 2020
rem github.com/gmartijn/AWSTEST2
rem ----------------------------------------------------------------------------------------------
rem PREREQUISITES
rem * AWS CLI for Windows
rem * needs GNU Coreutils (included in the distribution), Powershell (executionpolicy off)

rem for detailed info. See Readme.md

REM CONNECT
rem First authenticate with your weapon of choice, and ensure you have the .aws directory in your user-profile
rem with the config (depicting the region of choice e.g. eu-west-1), and the credentials, which can be created 
rem either using aws-adfs-cli-mfa. or using any tool that can download the Credentials such as the saml to sts convertor.

REM PERMISSIONS
rem minimum account privilege is read-only (describe & get)

rem Revisions:
rem V0.1 GM 17-09-2020 initial release
rem V0.2 GM 20-09-2020 added subroutine for date handling
rem V0.4 GM 29-09-2020 added additional subroutines handling S3 buckets, retrieving AMI Roles (not complete!). 
rem V0.5 GM 01-10-2020 added IAM roles, check on encrypted parameters.
rem V0.6 GM 08-10-2020 added pmapper as an alternative to enumerate EC2 Roles and IAM toxic combinations, as a next best thing.
rem v0.7 GM 14-10-2020 added jq for readability of JSON policies, added the check for the password policy.
rem v0.8 GM 16-10-2020 added count for snapshots, and compare to limits, added additional powershell helpers to aid in processing the credential report csv file in order to properly execute checks.

rem get the account # in order to use further on in the script.
FOR /F "tokens=*" %%F IN ('aws sts get-caller-identity --query [Account] --output text') DO (
SET account=%%F
)
rem get the account alias in order to use further on in the script
FOR /F "tokens=*" %%F IN ('aws iam list-account-aliases --query [AccountAliases] --output text') DO (
SET alias=%%F

)
rem start of the report
echo -----------------------------------REPORT GENERATED on %date% %time% >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------------------------Info----------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------Accountname/alias-------------------------------- >> EVIDENCE.TXT
echo ----------------------------------------%alias%-%account% >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------Caller identity---------------------------------- >> EVIDENCE.TXT
aws sts get-caller-identity --output text >> EVIDENCE.TXT
rem pause
rem This line is needed to see which EC2 instances are in an account
aws ec2 describe-instances --query "Reservations[].Instances[*].InstanceId" --output text >> ec2.txt

echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------EC2 EVIDENCE ------------------------------------------ >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------------EC2 INFORMATIONAL --------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------List all properties of instances ------------------------------ >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
FOR /F %%A in (ec2.txt) do echo %%A --- ALL EC2 SETTINGS --- >> EVIDENCE.TXT & aws ec2 describe-instances --instance-id %%A --output table >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------List all AMI's stored in an AWS account------------------------ >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws ec2 describe-images --owners self --query "Images[*].[ImageId]" --output text >> amimages.txt
rem store stuff in temporary file for finding necessary information
FOR /F %%A in (amimages.txt) do echo %%A --- ALL AMI SETTINGS --- >> EVIDENCE.TXT & aws ec2 describe-images --image-id %%A --output table >> EVIDENCE.TXT & aws ec2 describe-images --image-id %%A --output table >> AMICHECK.TXT
rem 4.2.2
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------------EC2 TESTING SECTION-------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------------------TEST #1-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------Determine whether there are any AMI images in the account that are shared/public------->> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ImageId                Public >> EVIDENCE.TXT
aws ec2 describe-images --owner self --query "Images[*].[ImageId,Public]" --output table >> EVIDENCE.TXT
aws ec2 describe-images --owner self --query "Images[*].[Public]" --output text >> impub.txt
for /f "tokens=3" %%b in ('find /c "True" .\impub.TXT') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------NOK - Shared/Public Amazon Machine images found------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------OK - No Shared/Public Amazon Machine images found	-------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
rem section 4.2.2
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------------------TEST #2-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------AMI Encryption----------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws ec2 describe-images --owner self --query Images[*].BlockDeviceMappings[*].Ebs.[Encrypted] --output text >> AMICHECK2.TXT
aws ec2 describe-images --owner self --query Images[*]."[ImageId,BlockDeviceMappings,Ebs,Encrypted]" --output text >> EVIDENCE.TXT
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "False" .\AMICHECK2.TXT') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------NOK - Unencrypted Amazon Machine images found----------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------OK - Encrypted Amazon Machine images found------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
rem section 4.6.2
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------------------TEST #3-------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------Testing	whether the EBS volumes are encrypted--------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
 
aws ec2 describe-volumes --query Volumes[*].[VolumeId] --filters Name=encrypted,Values=false --output text >> volumeencrypt.txt
echo VolumeId               Encrypted >> EVIDENCE.TXT
aws ec2 describe-volumes --query Volumes[*]."[VolumeId,Encrypted]" --output table>> EVIDENCE.TXT
Setlocal EnableDelayedExpansion
  for /f "usebackq" %%b in (`type volumeencrypt.txt ^| find "" /v /c`) do (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------NOK unencrypted volumes found------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws ec2 describe-volumes --query Volumes[*].[VolumeId] --filters Name=encrypted,Values=false --output text >> EVIDENCE.TXT 
) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------------- OK only encrypted volumes ---------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

rem 4.2.4
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------------------TEST #4.1------------------------------------------ >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Testing mages older than 1 year----------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo Determine the age of AMI's used
aws ec2 describe-images --owners self --query "Images[*].[CreationDate]" --output text >> AMIAGE.TXT
set year=%date:~6,4%
setlocal enabledelayedexpansion
for /f "delims=" %%a in (amiage.txt) do (
    set "line=%%a"
    set "line=!line:~,4!"
    echo !line! ) >> amiage2.txt
	
rem deduplicate 
	
	setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (amiage2.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> amiage3.txt
      set "prevLine=%%a"
   )
)
echo IMAGEID                 CreationTime >> EVIDENCE.TXT
aws ec2 describe-images --owners self --query "Images[*].[ImageId,CreationDate]" --output t >> EVIDENCE.TXT

Setlocal EnableDelayedExpansion
for /f %%b in (amiage3.txt) do  (
    IF %%b EQU %year% (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------OK -  Only AMI's found that have been created in %%b >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------- NOK - %%b AMI's older then 1 year found >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
	
set refdatemonth=%date:~6,4%%date:~3,2%

setlocal enabledelayedexpansion
(
for /f "delims=" %%a in (amiage.txt) do (
    set "line=%%a"
    set "line=!line:~,7!"
    echo !line!  >> amimon2.txt )
)
)

setlocal enableDelayedExpansion
(
   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" amimon2.txt') do (
      set "line=%%b"
      if defined line set "line=!line:-=!"
      echo !line! >> amimon3.txt
   )
)
set month=%date:~3,2%
echo %month%
IF %month% EQU 06 (
    set newmonth=04
	) ELSE ( echo %month%
    )
IF %month% EQU 05 (
    set newmonth=03
	) ELSE ( echo %month%
	)
IF %month% EQU 04 (
    set newmonth=02
	) ELSE ( echo %month%
)
IF %month% EQU 03 (
    set newmonth=01
	) ELSE ( echo %month%
)
IF %month% EQU 02 (
    set newmonth=12
	) ELSE ( echo %month%
)
IF %month% EQU 01 (
    set newmonth=11
	) ELSE ( echo %month%
)
IF %month% EQU 12 (
    set newmonth=10
	) ELSE ( echo %month%
)
IF %month% EQU 11 (
    set newmonth=09
	) ELSE ( echo %month%
)
IF %month% EQU 10 (
    set newmonth=08
	) ELSE ( echo %month%
)
IF %month% EQU 09 (
    set newmonth=07
	) ELSE ( echo %month%
)
IF %month% EQU 08 (
    set newmonth=06
	) ELSE ( echo %month%
)
IF %month% EQU 07 (
    set newmonth=05
	) ELSE ( echo %month%
)
echo %newmonth%

echo %datemonth%
set reference=%year%%newmonth%
echo %reference%
echo 4.2.4
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------------TEST #4.2--------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------Testing AMI images older than 2 months------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
rem type amiage.txt >> EVIDENCE.TXT
rem Deduplicate the results

sort <amimon3.txt >amimon33.txt
	setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (amimon33.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> amimon4.txt
      set "prevLine=%%a"
   )
)

Setlocal EnableDelayedExpansion
for /f %%b in (amimon4.txt) do  (
    IF %%b LSS %reference% (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------- NOK - %%b AMI's older then 2 months found >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------OK - %%b No AMI's older then 2 months found >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
	

rem 4.2.5
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------------------------TEST #5.1----------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------Testing age of running EC2 instances---------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo IMAGEID                 LaunchTime >> EVIDENCE.TXT
aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query Reservations[*].Instances[*].LaunchTime --output text >> launch.txt
aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query Reservations[*].Instances[*]."[ImageId,LaunchTime]" --output text >> EVIDENCE.TXT

set year=%date:~6,4%
setlocal enabledelayedexpansion
for /f "delims=" %%a in (launch.txt) do (
    set "line=%%a"
    set "line=!line:~,4!"
    echo !line! ) >> launch2.txt
		
	setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (launch2.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> launch3.txt
      set "prevLine=%%a"
   )
)
	
Setlocal EnableDelayedExpansion
for /f %%b in (launch3.txt) do  (
    IF %%b EQU %year% (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------OK -  %%b EC2 instances not older than 1 year----------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------- NOK - %%b EC2 older then 1 year found---------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
	
set refdatemonth=%date:~6,4%%date:~3,2%

setlocal enabledelayedexpansion
for /f "delims=" %%a in (launch.txt) do (
    set "line=%%a"
    set "line=!line:~,7!"
    echo !line!  >> launchmon2.txt )

setlocal enableDelayedExpansion
(
   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" launchmon2.txt') do (
      set "line=%%b"
      if defined line set "line=!line:-=!"
      echo !line! >> launchmon3.txt
   )
)

set month=%date:~3,2%
echo %month%
IF %month% EQU 06 (
    set newmonth=04
	) ELSE ( echo %month%
    )
IF %month% EQU 05 (
    set newmonth=03
	) ELSE ( echo %month%
	)
IF %month% EQU 04 (
    set newmonth=02
	) ELSE ( echo %month%
)
IF %month% EQU 03 (
    set newmonth=01
	) ELSE ( echo %month%
)
IF %month% EQU 02 (
    set newmonth=12
	) ELSE ( echo %month%
)
IF %month% EQU 01 (
    set newmonth=11
	) ELSE ( echo %month%
)
IF %month% EQU 12 (
    set newmonth=10
	) ELSE ( echo %month%
)
IF %month% EQU 11 (
    set newmonth=09
	) ELSE ( echo %month%
)
IF %month% EQU 10 (
    set newmonth=08
	) ELSE ( echo %month%
)
IF %month% EQU 09 (
    set newmonth=07
	) ELSE ( echo %month%
)
IF %month% EQU 08 (
    set newmonth=06
	) ELSE ( echo %month%
)
IF %month% EQU 07 (
    set newmonth=05
	) ELSE ( echo %month%
)
echo %newmonth%

echo %datemonth%
set reference=%year%%newmonth%
echo %reference%
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #5.2--------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------Check existence of EC2 instances with lauchtime older 2 months---------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
sort <launchmon3.txt >launchmon33.txt
setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (launchmon33.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> launchmon4.txt
      set "prevLine=%%a"
   )
)


Setlocal EnableDelayedExpansion
for /f %%b in (launchmon4.txt) do  (
    IF %%b LSS %reference% (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------%%b 	- NOK - EC2 older then 2 months found--------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------%%b   OK - No EC2 older then 2 months found--------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
	
	

rem Get the security groups
aws ec2 describe-instances --query Reservations[].Instances[*].NetworkInterfaces[*].Groups[*].[GroupId] --output text >> secgroups.txt
rem sort, and deduplicate security groups
sort <secgroups.txt >secgroups2.txt
	setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (secgroups2.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> secgroups3.txt
      set "prevLine=%%a"
   )
)
rem 4.8.1

aws ec2 describe-instances --query Reservations[].Instances[*].NetworkInterfaces[*].Groups[*].[GroupId] --output text >> secgroups.txt

sort <secgroups.txt >secgroups2.txt
	setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (secgroups2.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> secgroups3.txt
      set "prevLine=%%a"
   )
)

REM TEST #9 Needs improvement, currently only overpermissive IP entries are identified... Maybe make a batch/powershell hibrid??
REM Also initial query needs tuning... For now i am giving up on this. 
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #6.1--------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check Security Groups--------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------manual check for wide port ranges------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
FOR /F %%A in (secgroups3.TXT) do aws ec2 describe-security-groups --group-ids %%A --query SecurityGroups[*].IpPermissions[*].IpRanges[*]."[CidrIp]" >> cidrips.txt


echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
FOR /F %%A in (secgroups3.TXT) do aws ec2 describe-security-groups --group-ids %%A --query SecurityGroups[*].IpPermissions[*] --output table >> EVIDENCE.txt

FOR /F %%A in (secgroups3.TXT) do aws ec2 describe-security-groups --group-ids %%A --query SecurityGroups[*].IpPermissions[*]."[FromPort,ToPort]" --output text >> ports.txt
rem todo; when the first port is value A, determine whether the value of last port is too high.
FOR /F %%A in (secgroups3.TXT) do aws ec2 describe-security-groups --group-ids %%A --query SecurityGroups[*].IpPermissions[*]."[FromPort]" --output text >> portsfrom.txt
FOR /F %%A in (secgroups3.TXT) do aws ec2 describe-security-groups --group-ids %%A --query SecurityGroups[*].IpPermissions[*]."[ToPort]" --output text >> portsto.txt
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #6.2--------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check Security Groups--------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------Check whether large range of IP adresses is allowed----------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "0.0/0" cidrips.txt' ) do  (
    IF %%b GEQ 1 ( 
	
	
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------over permissive x.x.0.0/0 Addresses found in security group----------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------OK - No x.x.0.0/0 Addresses found in security group---------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
	
	
	)
for /f "tokens=3" %%b in ('find /c "0.0/8" cidrips.txt' ) do  (
    IF %%b GEQ 1 ( 
	
	
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------over permissive x.x.0.0/8 Addresses found in security group---------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------OK - No x.x.0.0/8 Addresses found in security group---------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
	
	
	)
for /f "tokens=3" %%b in ('find /c "0.0/16" cidrips.txt' ) do  (
    IF %%b GEQ 1 ( 
	
	
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------over permissive x.x.0.0/16 Addresses found in security group---------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------OK - No x.x.0.0/16 Addresses found in security group-------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
	
	
	)
	
for /f "tokens=3" %%b in ('find /c "0.0/24" cidrips.txt' ) do  (
    IF %%b GEQ 1 ( 
	
	
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------over permissive x.x.0.0/24 Addresses found in security group--------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------OK - No x.x.0.0/24 Addresses found in security group------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
	
	
	)
	
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------Manual Check, are there any wide open ports ----------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	
rem 4.2.1

FOR /F %%A in (secgroups3.TXT) do aws ec2 describe-security-groups --group-ids %%A --query SecurityGroups[*].IpPermissions[*]."[FromPort,IpProtocol,ToPort]" --output table >> EVIDENCE.txt 

del secgroups*.txt /s

echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #7----------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check EC2 Role policy---------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------Note that this test is incomplete-------------------------------- >> EVIDENCE.TXT
echo ---------------------------- Manual verification is needed! --------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT

FOR /F %%A in (ec2.TXT) do aws ec2 describe-instances --instance-ids %%A --query Reservations[*].Instances[*].IamInstanceProfile.[Arn] --output text >> ARNS.txt


md delim
for /f "tokens=1,2 delims=/" %%a in (ARNS.TXT) do (
  set BEFORE_UNDERSCORE=%%a
  set AFTER_UNDERSCORE=%%b
echo %%b >> .\delim\names.txt
)


FOR /F %%A in (.\delim\Names.TXT) do aws iam list-attached-role-policies --role-name %%A --output text >> iampolicies.txt


for /f "tokens=3" %%b in ('find /c "Admin" iampolicies.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------NOK - Administrator permissions added to EC2 instance------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------- NO explicit Administrator permissions added to EC2 instance---------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------- Check lines below for Policies that contain admin-------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

type iampolicies.txt >> EVIDENCE.TXT
  
for /f "tokens=1,2 delims=	" %%a in (iampolicies.txt) do (
  set BEFORE_UNDERSCORE=%%a
  set AFTER_UNDERSCORE=%%b
echo %%b >> .\delim\names2.txt
)

for /f "tokens=1,2 delims=/" %%a in (.\delim\names2.TXT) do (
  set BEFORE_UNDERSCORE=%%a
  set AFTER_UNDERSCORE=%%b
echo %%b >> .\delim\names3.txt
)



 set f1=.\delim\names.txt
 set f2=.\delim\names3.txt
 set "sep=:

 (
   for /f "delims=" %%a in (%f1%) do (
      setlocal enabledelayedexpansion
       set /p line=
       echo(%%a!sep!!line! >> de.txt
      endlocal
   )
 )<%f2%

 
FOR /F %%A in (.\delim\Names.TXT) do aws iam list-role-policies --role-name %%A --output text >> iampolicies2.txt
 
for /f "tokens=1,2 delims=	" %%a in (iampolicies2.txt) do (
  set BEFORE_UNDERSCORE=%%a
  set AFTER_UNDERSCORE=%%b
echo %%b >> .\delim\names4.txt
)

 set f1=.\delim\names.txt
 set f2=.\delim\names4.txt
 set sep=: 
 

 (
   for /f "delims=" %%a in (%f1%) do (
      setlocal enabledelayedexpansion
       set /p line=
       echo(%%a!sep!!line! >> de.txt
      endlocal
   )
 )<%f2%
 
 sort <de.txt >de2.txt
	setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (de2.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> de4.txt
      set "prevLine=%%a"
   )
)

rem pmapper graph --create

rem pmapper analysis --output-type text >> EVIDENCE.TXT

rem some policies cannot be downloaded, therefore additional manual verification is needed!
 
for /f "tokens=1,2 delims=:" %%a in (de4.txt) do (
  set BEFORE_UNDERSCORE=%%a
  set AFTER_UNDERSCORE=%%b
  
  echo %%a
  echo %%b
aws iam get-role-policy --role-name %%a --policy-name %%b >> EVIDENCE.txt
)
rem 4.3.1 VPC Endpoint Access 

echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #8----------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check VPC endpoint access----------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------Note that this test is incomplete-------------------------------- >> EVIDENCE.TXT
echo ---------------------------- Manual verification is needed! --------------------------------- >> EVIDENCE.TXT
echo -------------------------------For Cross account access-------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws ec2 describe-vpc-endpoints --query VpcEndpoints[*].[VpcEndpointId] --output text >> vpc.txt
aws ec2 describe-vpc-endpoints --query VpcEndpoints[*] --output table >> EVIDENCE.TXT

FOR /F %%A in (vpc.TXT) do aws ec2 describe-vpc-endpoints --vpc-endpoint-ids %%A --query VpcEndpoints[*].[PolicyDocument] --output text >> vpcpolicies.txt

Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "*" .\vpcpolicies.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------NOK - Publicly accessible VPC points found-------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------OK - No public accessible points found----------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #9------------------------------------=---------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check VPC flow logs----------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT

rem 4.3.2 Gebrek aan VPC flow logs
aws ec2 describe-vpcs --query Vpcs[*].[VpcId] --output text >> vpcid.txt
FOR /F %%A in (vpcid.txt) do aws ec2 describe-flow-logs --filter Name=resource-id,Values=%%A --output table >> EVIDENCE.TXT
FOR /F %%A in (vpcid.txt) do aws ec2 describe-flow-logs --filter Name=resource-id,Values=%%A >> flowlog.txt


Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "[]" .\flowlog.TXT') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------NOK - INActive Flowlogs found----------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------OK - flowlogs present---------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
  
rem del flowlog.txt /s
del vpcid.txt /s


rem TODO: 4.4.1	Open storage accounts 
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #10.1---------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check open s3 buckets -------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws s3api list-buckets --query Buckets[*].[Name] --output text >> buckets.txt


FOR /F %%A in (buckets.txt) do aws s3api get-bucket-acl --bucket %%A --output table >> EVIDENCE.TXT

FOR /F %%A in (buckets.txt) do aws s3api get-bucket-acl --bucket %%A >> s3grants.txt


Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "AllUsers" .\s3grants.TXT') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------NOK - Open S3 buckets found------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------OK - No open S3 buckets found-------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
  
  
rem 4.4.2 S3 bucket encryption

echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #10.2--------------------------------------------->> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check s3 buckets encryption --------------------------------->> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT

FOR /F %%A in (buckets.txt) do aws s3api get-bucket-encryption	--bucket %%A --output text >> bucketencryption.txt & if errorlevel=1 echo notfound >> bucketencryption.txt

FOR /F %%A in (buckets.txt) do aws s3api get-bucket-encryption --bucket %%A >> EVIDENCE.TXT & if errorlevel=1 echo %%A notfound >> EVIDENCE.TXT
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "notfound" bucketencryption.TXT') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------NOK -%%b Unencrypted S3 buckets found--------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------OK - %%b encrypted buckets found-------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )


rem 4.4.3	S3 bucket SSL/TLS



echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #10.3-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check s3 bucket policy ------------------------------------- >> EVIDENCE.TXT
echo ----------------------------THIS test is not fully automated--------------------------------- >> EVIDENCE.TXT
echo ----------------------------------Find section where ---------------------------------------- >> EVIDENCE.TXT
echo -----------------------------{"Bool":{"aws:SecureTransport":"false"}------------------------- >> EVIDENCE.TXT
echo -----------------------------{"Bool":{"aws:SecureTransport":"true]}-------------------------- >> EVIDENCE.TXT
echo --------------------------Determine whether False=Deny (meaning that SSL is enforced)-------- >> EVIDENCE.TXT
echo --------------------------Determine whether True=Allow (meaning that SSL is enforced)-------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------Any conflict of both means that unencrypted connections are allowed------ >> EVIDENCE.TXT


  
FOR /F %%A in (buckets.txt) do echo %%A >> bucket-policy.txt & aws s3api get-bucket-policy --bucket %%A  --output text | jq -r ".Statement" >> bucket-policy.txt

FOR /F %%A in (buckets.txt) do echo %%A >> EVIDENCE.TXT & aws s3api get-bucket-policy --bucket %%A --output text | jq -r ".Statement" >> EVIDENCE.TXT

rem TODO: 4.5.1	Listener Security
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #11---------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check ELB HTTPS policy ------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws elbv2 describe-load-balancers --query LoadBalancers[*].[LoadBalancerName] --output text
aws elbv2 describe-load-balancers --query LoadBalancers[*].[LoadBalancerArn] --output text >> elbs.txt
FOR /F %%A in (elbs.txt) do aws elbv2 describe-listeners --load-balancer-arn %%A --query Listeners[]."[ListenerArn,Port,Protocol]" --output text >> ELBHTTP.TXT
FOR /F %%A in (elbs.txt) do aws elbv2 describe-listeners --load-balancer-arn %%A --query Listeners[]."[ListenerArn,Port,Protocol]" --output table >> EVIDENCE.TXT
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "HTTPS" ELBHTTP.TXT') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------OK -%%b HTTPS LISTENERS FOUND >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------NOK - %%b No HTTPS listeners found>> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )


rem TODO: 4.6.1	Public & Encrypted Snapshots
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #12.1-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check public snapshots ------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
rem aws ec2 describe-snapshots --owner-ids %account%--filters Name=status,Values=completed	--output table	--query 'Snapshots[*].SnapshotId'

aws ec2 describe-snapshots --owner-ids %account% --filters Name=status,Values=completed --output text --query Snapshots[*].[SnapshotId] >> snapshots.txt


for /f "tokens=3" %%b in ('find /c "snap" snapshots.txt') do  ( echo %%b snapshots in %account% %alias% >> EVIDENCE.TXT)
IF %%b GEQ 90000 (
echo SNAPSHOT LIMIT ALMOST REACHED 100000 allowed >> EVIDENCE.TXT
) ELSE (
echo SNAPSHOT LIMIT NOT REACHED 100000 allowed>> EVIDENCE.TXT)

FOR /F %%A in (snapshots.txt) do echo %%A >> Snappublic.txt & aws ec2 describe-snapshot-attribute --snapshot-id %%A --attribute createVolumePermission --query "CreateVolumePermissions[]" >> Snappublic.txt

Setlocal EnableDelayedExpansion

for /f "tokens=3" %%b in ('find /c "all" Snappublic.TXT') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------NOK -%%b public EBS Snapshots found >> EVIDENCE.TXT
echo ----------------------Look in evidence directory for snap-%alias%-%account%.txt >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------OK - %%b No Public EBS snapshosts found>> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

rename spappublic snap-%alias%-%account%.txt & move snap-%alias%-%account%.txt %alias%
  

echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #12.2-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check encrypted EBS snapshots ------------------------------ >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT

aws ec2 describe-snapshots --owner-ids %account% --query Snapshots[*].[Encrypted] --output text >> encsnap.txt
aws ec2 describe-snapshots --owner-ids %account% --query Snapshots[*].[SnapshotId,Encrypted] --output text >> EVIDENCE.TXT


Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "False" encsnap.txt.TXT') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------NOK -%%b unencrypted EBS Snapshots found >> EVIDENCE.TXT
echo -----------------------------Look in evidence directory for snap-%alias%-%account%.txt >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------ %%b No unencrypted EBS snapshosts found >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
  
rem TODO: 4.7.1	EFS encryptie 

aws efs describe-file-systems --output text --query FileSystems[*].[FileSystemId] >> efsfile.txt
FOR /F %%A in (efsfile.txt) do aws efs describe-file-systems --file-system-id %%A --query FileSystems[*].Encrypted --output text >> efsenc.txt


echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #13 >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check encrypted efs filesystems----------------------------  >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT


aws efs describe-file-systems --query FileSystems[*]."[Name,Encrypted]" --output text >> EVIDENCE.TXT
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "False" efsenc.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------NOK -%%b unencrypted EFS filesystems >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------OK - %%b No unencrypted EFS found >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

rem TODO: 4.9.1	Gebrek aan Identity and Access Management 
rem AWS IAM password beleid
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------TEST #14.0 IAM password policy >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws iam get-account-password-policy --output table >> EVIDENCE.TXT
rem Checking password length according to CIS guideline
rem https://www.cisecurity.org/white-papers/cis-primer-securing-login-credentials/#:~:text=Password%20Policy%20Recommendations%3A,for%20each%20account%20you%20access.
FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.MinimumPasswordLength') DO (
SET passlength=%%F
)

echo %passlength%
 IF %passlength% GEQ 10 (

echo -------------------------OK -Passwordlength is %passlength% >> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -Passwordlength is %passlength%>> EVIDENCE.TXT

)
    	
	)

FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.RequireSymbols') DO (
SET RequireSymbols=%%F
)

echo %RequireSymbols%
 IF %RequireSymbols% == true (

echo -------------------------OK -RequireSymbols is %RequireSymbols% >> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -RequireSymbols is %RequireSymbols% >> EVIDENCE.TXT

)
    	
	)

	FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.RequireNumbers') DO (
SET RequireNumbers=%%F
)

echo %RequireNumbers%
 IF %RequireNumbers% == true (

echo -------------------------OK -RequireNumbers is %RequireSymbols% >> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -RequireNumbers is %RequireNumbers% >> EVIDENCE.TXT

)
    	
	)
	
	
	
		FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.RequireUppercaseCharacters') DO (
SET RequireUppercaseCharacters=%%F
)

echo %RequireUppercaseCharacters%
 IF %RequireUppercaseCharacters% == true (

echo -------------------------OK -RequireUppercaseCharacters is %RequireUppercaseCharacters% >> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -RequireUppercaseCharactersis is %RequireUppercaseCharacters% >> EVIDENCE.TXT

)
    	
	)
	
	
		FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.RequireLowercaseCharacters') DO (
SET RequireLowercaseCharacters=%%F
)

echo %RequireLowercaseCharacters%
 IF %RequireLowercaseCharacters% == true (

echo -------------------------OK -RequireLowercaseCharacters %RequireLowercaseCharacters% >> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -RequireLowercaseCharacters is %RequireLowercaseCharacters% >> EVIDENCE.TXT

)
    	
	)
	
	
	
	
	
		FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.AllowUsersToChangePassword') DO (
SET AllowUsersToChangePassword=%%F
)

echo %AllowUsersToChangePassword%
 IF %AllowUsersToChangePassword% == true (

echo -------------------------OK -AllowUsersToChangePassword is %AllowUsersToChangePassword% >> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -AllowUsersToChangePasswords is %AllowUsersToChangePassword% >> EVIDENCE.TXT

)
    	
	)
	
	
		
	
		FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.ExpirePasswords') DO (
SET ExpirePasswords=%%F
)

echo %ExpirePasswords%
 IF %ExpirePasswords% == true (

echo -------------------------OK -ExpirePassword is %ExpirePasswords% >> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -ExpirePassword is %ExpirePasswords% >> EVIDENCE.TXT

)
    	
	)
		
		FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.MaxPasswordAge') DO (
SET MaxPasswordAge=%%F
)

echo %MaxPasswordAge%
 IF %MaxPasswordAge% LSS 60 (

echo -------------------------OK -MaxPasswordAge is less then 60, namely %MaxPasswordAge%>> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -MaxPasswordAge is higher then 60 namely %MaxPasswordAge% >> EVIDENCE.TXT

)
    	
	)
	
		FOR /F "tokens=*" %%F IN ('aws iam get-account-password-policy --query PasswordPolicy.PasswordReusePrevention') DO (
SET PasswordReusePrevention=%%F
)

echo %PasswordReusePrevention%
 IF %PasswordReusePrevention% GEQ 1 (
echo -------------------------OK -PasswordReusePrevention is higher then 1 namely %PasswordReusePrevention% >> EVIDENCE.TXT

		
	) ELSE (

echo -------------------------NOK -PasswordReusePrevention is %PasswordReusePrevention%>> EVIDENCE.TXT

)
    	
	)
	
	
	

rem AWS IAM Users with administrative permissions
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------TEST #14.1 IAM users with admin permissions---------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws iam list-users --output text --query Users[*].UserName >> usernames.txt
FOR /F %%A in (usernames.txt) do aws iam list-attached-user-policies --output text --user-name %%A --query AttachedPolicies[*].PolicyName >> userattachedpolicies.txt
FOR /F %%A in (usernames.txt) do echo %%A >> EVIDENCE.TXT & aws iam list-attached-user-policies --output text --user-name %%A  >> EVIDENCE.TXT

Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "Admin" userattachedpolicies.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------NOK - %%b IAM users with administrator privileges>> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------OK - %%b IAM admins found >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
rem Access Keys Rotation 

echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------TEST #14.2 IAM Users with access keys --------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT

FOR /F %%A in (usernames.txt) do aws iam list-access-keys --user-name %%A --query AccessKeyMetadata[*].[CreateDate] --output text >> accesskeyrotation.txt
FOR /F %%A in (usernames.txt) do aws iam list-access-keys --user-name %%A --query AccessKeyMetadata[*]."[UserName,CreateDate]" --output text >> EVIDENCE.TXT


set year=%date:~6,4%
set refdatemonth=%date:~6,4%%date:~3,2%

setlocal enabledelayedexpansion
for /f "delims=" %%a in (accesskeyrotation.txt) do (
    set "line=%%a"
    set "line=!line:~,7!"
    echo !line!  >> accesskeyrotation2.txt )

setlocal enableDelayedExpansion
(
   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" accesskeyrotation2.txt') do (
      set "line=%%b"
      if defined line set "line=!line:-=!"
      echo !line! >> accesskeyrotation3.txt
   )
)

set month=%date:~3,2%
echo %month%
IF %month% EQU 06 (
    set newmonth=04
	) ELSE ( echo %month%
    )
IF %month% EQU 05 (
    set newmonth=03
	) ELSE ( echo %month%
	)
IF %month% EQU 04 (
    set newmonth=02
	) ELSE ( echo %month%
)
IF %month% EQU 03 (
    set newmonth=01
	) ELSE ( echo %month%
)
IF %month% EQU 02 (
    set newmonth=12
	) ELSE ( echo %month%
)
IF %month% EQU 01 (
    set newmonth=11
	) ELSE ( echo %month%
)
IF %month% EQU 12 (
    set newmonth=10
	) ELSE ( echo %month%
)
IF %month% EQU 11 (
    set newmonth=09
	) ELSE ( echo %month%
)
IF %month% EQU 10 (
    set newmonth=08
	) ELSE ( echo %month%
)
IF %month% EQU 09 (
    set newmonth=07
	) ELSE ( echo %month%
)
IF %month% EQU 08 (
    set newmonth=06
	) ELSE ( echo %month%
)
IF %month% EQU 07 (
    set newmonth=05
	) ELSE ( echo %month%
)
echo %newmonth%

echo %datemonth%
set reference=%year%%newmonth%
echo %reference%

sort <accesskeyrotation3.txt >accesskeyrotation33.txt
setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (accesskeyrotation33.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> accesskeyrotation4.txt
      set "prevLine=%%a"
   )
)


Setlocal EnableDelayedExpansion
for /f %%b in (accesskeyrotation4.txt) do  (
    IF %%b LSS %reference% (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------%%b - NOK - Users with Accesskeys older than 2 months >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------%%b   OK -  Users No accesskeys older than 2 months >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

rem Credentials Last Used
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #14.3-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------check last logon date of IAM accounts---------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------check accounts with access keys (especially root)------------------- >> EVIDENCE.TXT
echo ----------------------------check accounts with logon dates in the past---------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------Additionally %account%-%alias%credreport.csv>> EVIDENCE.TXT
echo -----------------------------------------can be checked ------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws iam generate-credential-report
aws iam get-credential-report --query Content --output text >> credreport.txt
powershell ./decodebase64.ps1

powershell ./credreport.ps1 >> EVIDENCE.TXT

powershell ./passlast.ps1 >> lastpass.txt

Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "N" lastpass.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------NOK - Stale users found in IAM-------------------------------->> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------OK -  all Active users in IAM------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )
  
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "no_information" lastpass.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------------NOK - No_informationusers found in IAM ------------------------>> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------OK - No_information all Active users in IAM-------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

for /f "tokens=1 delims=N/A" %%a in (lastpass.txt) do (echo %%a >> lastpass2.txt)
for /f "tokens=1 delims=no_information" %%a in (lastpass2.txt) do (echo %%a >> lastpass3.txt) 

set year=%date:~6,4%
set refdatemonth=%date:~6,4%%date:~3,2%

setlocal enabledelayedexpansion
for /f "delims=" %%a in (lastpass3.txt) do (
    set "line=%%a"
    set "line=!line:~,7!"
    echo !line!  >> lastpass4.txt )

setlocal enableDelayedExpansion
(
   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" lastpass4.txt') do (
      set "line=%%b"
      if defined line set "line=!line:-=!"
      echo !line! >> lastpass5.txt
   )
)

set month=%date:~3,2%
echo %month%
IF %month% EQU 06 (
    set newmonth=04
	) ELSE ( echo %month%
    )
IF %month% EQU 05 (
    set newmonth=03
	) ELSE ( echo %month%
	)
IF %month% EQU 04 (
    set newmonth=02
	) ELSE ( echo %month%
)
IF %month% EQU 03 (
    set newmonth=01
	) ELSE ( echo %month%
)
IF %month% EQU 02 (
    set newmonth=12
	) ELSE ( echo %month%
)
IF %month% EQU 01 (
    set newmonth=11
	) ELSE ( echo %month%
)
IF %month% EQU 12 (
    set newmonth=10
	) ELSE ( echo %month%
)
IF %month% EQU 11 (
    set newmonth=09
	) ELSE ( echo %month%
)
IF %month% EQU 10 (
    set newmonth=08
	) ELSE ( echo %month%
)
IF %month% EQU 09 (
    set newmonth=07
	) ELSE ( echo %month%
)
IF %month% EQU 08 (
    set newmonth=06
	) ELSE ( echo %month%
)
IF %month% EQU 07 (
    set newmonth=05
	) ELSE ( echo %month%
)
echo %newmonth%

echo %datemonth%
set reference=%year%%newmonth%
echo %reference%

sort <lastpass5.txt >lastpass55.txt
setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (lastpass55.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> lastpass6.txt
      set "prevLine=%%a"
   )
)


Setlocal EnableDelayedExpansion
for /f %%b in (lastpass6.txt) do  (
    IF %%b LSS %reference% (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------%%b 	- NOK - Users logon older than 2 months >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------%%b   OK -  Users with logon older than 2 months>> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )



powershell ./accesskey.ps1 >> accesskeyactive.txt
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "true" accesskeyactive.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------NOK - %%b IAM users with accesskeys>> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------------OK -  No users with accesskeys--------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )



rem type credout.txt >> EVIDENCE.TXT

rem Hardware MFA for AWS Root Account & LAST use of MFA

echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #14.4-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------check MFA -------------------------------------------- >> EVIDENCE.TXT

aws iam list-virtual-mfa-devices --query VirtualMFADevices[*].User[]."[Arn,PasswordLastUsed]" --output text >> EVIDENCE.TXT
aws iam list-virtual-mfa-devices --query VirtualMFADevices[*].User[]."[PasswordLastUsed]" --output text >> rootlastused.TXT

powershell ./credmfa.ps1 >> mfa.txt

Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "false" mfa.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------NOK - %%b IAM users without MFA>> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------------------OK -  all IAM users with MFA------------------------ >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

set year=%date:~6,4%
set refdatemonth=%date:~6,4%%date:~3,2%

setlocal enabledelayedexpansion
for /f "delims=" %%a in (rootlastused.txt) do (
    set "line=%%a"
    set "line=!line:~,7!"
    echo !line!  >> rootlastused2.txt )

setlocal enableDelayedExpansion
(
   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" rootlastused2.txt') do (
      set "line=%%b"
      if defined line set "line=!line:-=!"
      echo !line! >> rootlastused3.txt
   )
)

set month=%date:~3,2%
echo %month%
IF %month% EQU 06 (
    set newmonth=05
	) ELSE ( echo %month%
    )
IF %month% EQU 05 (
    set newmonth=04
	) ELSE ( echo %month%
	)
IF %month% EQU 04 (
    set newmonth=03
	) ELSE ( echo %month%
)
IF %month% EQU 03 (
    set newmonth=02
	) ELSE ( echo %month%
)
IF %month% EQU 02 (
    set newmonth=01
	) ELSE ( echo %month%
)
IF %month% EQU 01 (
    set newmonth=12
	) ELSE ( echo %month%
)
IF %month% EQU 12 (
    set newmonth=11
	) ELSE ( echo %month%
)
IF %month% EQU 11 (
    set newmonth=10
	) ELSE ( echo %month%
)
IF %month% EQU 10 (
    set newmonth=09
	) ELSE ( echo %month%
)
IF %month% EQU 09 (
    set newmonth=08
	) ELSE ( echo %month%
)
IF %month% EQU 08 (
    set newmonth=07
	) ELSE ( echo %month%
)
IF %month% EQU 07 (
    set newmonth=06
	) ELSE ( echo %month%
)
echo %newmonth%

echo %datemonth%
set reference=%year%%newmonth%
echo %reference%

sort <rootlastused3.txt >rootlastused33.txt
setlocal EnableDelayedExpansion
set "prevLine="
for /F "delims=" %%a in (rootlastused33.txt) do (
   if "%%a" neq "!prevLine!" (
      echo %%a >> rootlastused4.txt
      set "prevLine=%%a"
   )
)


Setlocal EnableDelayedExpansion
for /f %%b in (rootlastused4.txt) do  (
    IF %%b GEQ %reference% (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------%%b 	- NOK - Root account used recently >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -----------------------------%%b   OK - No Root account use more than 1 month ago >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

rem AWS keys exposure 4.10.1

rename credout.txt %account%-%alias%credreport.csv

echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #15.1-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check KMS Key policies-------------------------------------- >> EVIDENCE.TXT
ho --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws kms list-aliases --query Aliases[*].[TargetKeyId] --output text >> keyids.txt
FOR /F %%A in (keyids.txt) do echo %%A >> EVIDENCE.TXT &  aws kms get-key-policy --key-id %%A --policy-name default --query Policy | jq -r >> EVIDENCE.TXT
FOR /F %%A in (keyids.txt) do echo %%A &  aws kms get-key-policy --key-id %%A --policy-name default --query Policy | jq -r >> keyps.txt
cat keyps.txt | grep "AWS" >> keyps.txt
cat keyps.txt | grep "AWS" >> EVIDENCE.TXT
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "*" keyps.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------NOK -%%b wide open key policies enabled >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------Review key policies to ensure that ------------------------------ >> EVIDENCE.TXT
echo ----------------------------------Conditions apply if not------------------------------------ >> EVIDENCE.TXT
echo ------------------------------------True positive-------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ----------------------------OK - %%b No Wide open keys found >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )


rem CMK Key rotation (only applies to Customer Managed Keys). 4.10.11
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #15.2-------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check KMS Key rotation-------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT


FOR /F %%A in (keyids.txt) do echo %%A >> EVIDENCE.TXT & aws kms get-key-rotation-status --key-id %%A --output text >> EVIDENCE.TXT
FOR /F %%A in (keyids.txt) do aws kms get-key-rotation-status --key-id %%A --output text >> rotation.txt
Setlocal EnableDelayedExpansion
for /f "tokens=3" %%b in ('find /c "False" rotation.txt') do  (
    IF %%b GEQ 1 (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ------------------------------NOK -%%b key no rotation disabled >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
		
	) ELSE (
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------OK - %%b Automatic key rotation enabled >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
)
    	
	)
  )

rem 4.11.1
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------------TEST #16---------------------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------------Check encrypted parameters---------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo -------------------------------Access to Encrypted Parameters ------------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
echo ---------------------------Searching for decodable secure strings---------------------------- >> EVIDENCE.TXT
echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
aws ssm describe-parameters --query Parameters[*].[Name] --filters="Key=Type,Values=SecureString" --output text >> params.txt
echo ------- DECODABLE SECURE strings stored in SSM that are decodable with a normal account -------
FOR /F %%A in (params.txt) do aws ssm get-parameters --names %%A --with-decryption --output text >> EVIDENCE.txt

rem For Future use:
rem echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
rem echo -----------------------User Defined Roles in the account------------------------------------- >> EVIDENCE.TXT  
rem echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
rem aws iam get-account-authorization-details --query RoleDetailList[].[RoleName] output text >> EVIDENCE.TXT
rem Rename the evidence file to the account #
rem echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
rem echo -----------------------SSM agents registered vs EC2 instances -------------------------------- >> EVIDENCE.TXT  
rem echo --------------------------------------------------------------------------------------------- >> EVIDENCE.TXT
rem aws ssm describe-instance-information --query InstanceInformationList[].[InstanceId] --output text >> SSMassociation.txt
rem aws ec2 describe-instances --query "Reservations[].Instances[*].InstanceId" --output text >> ec2.txt
rem grep -v -F -x -f SSMassociation.txt ec2.txt >> EVIDENCE.TXT & echo NOT ASSOCIATED >> EVIDENCE.TXT


md %alias%
del .\delim\*.txt
rd delim
rename EVIDENCE.TXT EC2-%alias%-%account%.txt & move EC2-%alias%-%account%.txt %alias%
rename ec2.txt %alias%-ec2.txt & move %alias%-ec2.txt %alias%
rename impub.txt %alias%-ec2.txt & move %alias%-impub.txt %alias%
rename amimages.txt %alias%-amimages.txt & move %alias%-amimages.txt %alias%
rename AMICHECK.txt %alias%-AMICHECK.txt & move %alias%-AMICHECK.txt %alias%
rename AMICHECK2.txt %alias%-AMICHECK2.txt & move %alias%-AMICHECK2.txt %alias%
rename params.txt %alias%-params.txt & move %alias%-params.txt %alias%
move %account%-%alias%credreport.csv %alias%
del amimon33.txt /s
del amimon4.txt /s
del ARNS.txt /s
del bucket-policy.txt /s
del bucketencryption.txt /s
del buckets.txt /s
del cidrips.txt /s
del cleanup.txt /s
del de.txt /s
del de2.txt /s
del de4.txt /s
del efsenc.txt /s
del efsfile.txt /s
del ELBHTTP.TXT /s
del elbs.txt /s
del encsnap.txt /s
del iampolicies.txt /s
del iampolicies2.txt /s
del keyids.txt /s
del launch.txt /s
del launch2.txt /s
del launch3.txt /s
del launchmon2.txt /s
del launchmon3.txt /s
del launchmon33.txt /s
del launchmon4.txt /s
del nn-sap-csv-ec2.txt /s
del ports.txt /s
del portsfrom.txt /s
del portsto.txt /s
del rotation.txt /s
del s3grants.txt /s
del Snappublic.txt /s
del snapshots.txt /s
del volumeencrypt.txt /s
del vpc.txt /s
del vpcpolicies.txt /s
del credreport.txt /s
del AMIAGE.TXT /s
del amiage2.txt /s
del amiage3.txt /s
del amimon2.txt /s
del amimon3.txt /s
del nn-sap-tst-ec2.txt /s
del rootlastused.TXT /s
del usernames.txt /s
del flowlog.txt /s
del keyps.txt /s
del accesskeyactive.txt /s
del lastpass.txt /s
del lastpass2.txt /s
del lastpass3.txt /s
del lastpass4.txt /s
del lastpass5.txt /s
del lastpass55.txt /s
del lastpass6.txt /s
del mfa.txt /s