

FOR /F "tokens=*" %%F IN ('aws sts get-caller-identity --query [Account] --output text') DO (
SET account=%%F
)
FOR /F "tokens=*" %%F IN ('aws iam list-account-aliases --query [AccountAliases] --output text') DO (
SET alias=%%F
)
echo -- REPORT GENERATED on %date% %time% >> EVIDENCE.TXT
echo -- ACCOUNT -- >> EVIDENCE.TXT
aws iam list-account-aliases --query [AccountAliases] --output text >> EVIDENCE.TXT
aws sts get-caller-identity --query [Account] --output text >> EVIDENCE.TXT
aws sts get-caller-identity --output text >> EVIDENCE.TXT

echo ------- SECURE STRINGS stored in SSM --------- >> EVIDENCE.TXT
aws ssm describe-parameters --query Parameters[*].[Name] --filters="Key=Type,Values=SecureString" --output text >> params.txt
echo ------- DECODABLE SECURE strings stored in SSM that are decodable with a normal account -------
FOR /F %%A in (params.txt) do aws ssm get-parameters --names %%A --with-decryption --output text >> EVIDENCE.txt
rename EVIDENCE.TXT securepar-%account%-%alias%.txt
del params.txt /s

