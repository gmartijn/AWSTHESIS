Minimum permissions to run the toolset is ReadOnlyAccess

Authentication can be performed using the .aws directory and storing your credentials in there. 

Tool is not region specific, just uses the region you store in your .aws/config

Just Run and have fun

Report will be stored in directory with the account id and account Alias with the name Evidence.txt afther that.

Hope you enjoy.

Part of the testing toolset for AWS IaaS infrastructure

* Test 1 is to determine whether any of the AMI's are shared. Shared AMI's run the risk of sharing confidential information with external parties
* Test 2 is to determine whether AMI encryption has been used, as an additional control against (unwanted) AMI sharing
* Test 3 is to determine whether EBS volumes are encrypted, If AWS ever discards of disks unsafely, the contents cannot be read.
* Test 4.1 is to determine whether there are old AMI's > 1 year. Giving an indication on how well the AMI's are managed, in lue of path and vulnerability management
* Test 4.2 is to determine the same for 4.1 only for 2 months...
* Test 5.1 is to determine the age of AMI's > 1 year. Giving an indication on how well the AMI's are managed, in lue of path and vulnerability management
* Test 5.2 is to determine the age of AMI's > 2 months. Giving an indication on how well the AMI's are managed, in lue of path and vulnerability management
* Test 6.1 is over permissive security groups (e.g. wide port ragens), e.g. essentially giving the host a bigger attack surface
* Test 6.2 is to determine wide ip ranges, take special care for 0.0.0.0/0
* Test 7 is to determine the EC2 Role permissions, Too high permissions can lead to privilege escalation of the host to the AWS account.
* Test 8 is to determine open VPC endpoint, VPC endpoints are used to create private ip access for aws native services e.g. s3. 
* Test 9 is to determine the lack of flow logs. If you do not log, you cannot see it.
* Test 10.1 is to determine open storage buckets (s3) e.g. that have world wide access, which could lead to potentially anyone reading the info or writing
* Test 10.2 is to determine whether the S3 buckets are encrypted essentially the same risk as EBS
* Test 10.3 is to determine whether there is an SSL policy attached to the S3 bucket. So data to and from the bucket has SSL encryption.
* Test 11 is whether there is an SSL policy attached to the ELB. So data to and from the bucket has SSL encryption.
* Test 12.1 is to determine whether any of the EBS snapshots are public. Shared snapshots run the risk of being taken, and used by external parties
* Test 12.2 is to determine whether the snapshots are encrypted, as a mitigating control against public EBS snapshots.
* Test 13 is to determine whether EFS filesystems have been encrypted, as a mitigating control against same risk as #3.
* Test 14.0 tests the password policy against the CIS benchmark, the lack of a proper password policy can lead to external attackers brute-forcing into your AWS account
* Test 14.1 test checks whether any of the IAM defined users have Administrator role attached, This should only be attached to a limited amount
* Test 14.2 Tests whehter there are users with old access keys
* Test 14.3 Looks of users with old accounts, when accounts are not used they should be disabled to prevent misuse.
* Test 14.4 tests the lastlogon of the Root. Recent use of the root account can be seen as the use of the root account for daily actions, and does not leave the actions accountable to a person
* Test 15.1 Looks for the permissions of AWS Keys, and determines whether they are accessible by other accounts or public
* Test 15.2 Looks for Key rotation of KMS keys, they should be rotated yearly at least
* Test 16 looks for secrets that are stored in the SSM manager that can be accessed with a read-only acocunt.