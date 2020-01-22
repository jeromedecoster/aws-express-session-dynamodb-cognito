# the directory of his script file
dir="$(cd "$(dirname "$0")"; pwd)"

cd "$dir"

source settings.sh

#
# create user pool
#

echo 'cognito-idp create-user-pool'
aws cognito-idp create-user-pool \
    --region $COGNITO_REGION \
    --pool-name $POOL_NAME \
    --auto-verified-attributes email \
    --alias-attributes email \
    --policies "PasswordPolicy={MinimumLength=6,RequireUppercase=false,\
    RequireLowercase=true,RequireNumbers=false,RequireSymbols=false}"

POOL_ID=$(aws cognito-idp list-user-pools \
    --region $COGNITO_REGION \
    --max-results 60 \
    --query "UserPools[?Name=='$POOL_NAME'].Id" \
    --output text)

echo 'sed > settings.sh'
sed --in-place "s|POOL_ID=.*$|POOL_ID=$POOL_ID|" settings.sh

echo 'cognito-idp create-user-pool-client'
aws cognito-idp create-user-pool-client \
    --region $COGNITO_REGION \
    --user-pool-id $POOL_ID \
    --client-name $POOL_NAME-client \
    --explicit-auth-flows ALLOW_ADMIN_USER_PASSWORD_AUTH \
        ALLOW_CUSTOM_AUTH \
        ALLOW_USER_PASSWORD_AUTH \
        ALLOW_USER_SRP_AUTH \
        ALLOW_REFRESH_TOKEN_AUTH

CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
    --region $COGNITO_REGION \
    --user-pool-id $POOL_ID \
    --query "UserPoolClients[?ClientName=='$POOL_NAME-client'].ClientId" \
    --output text)

echo 'sed > settings.sh'
sed --expression "s|POOL_ID=.*$|POOL_ID=$POOL_ID|" \
    --expression "s|CLIENT_ID=.*$|CLIENT_ID=$CLIENT_ID|" \
    --in-place settings.sh

#
# create 2 confirmed users : 
#   username=a password=aaaaaa email=a@a.com
#   username=b password=bbbbbb email=b@b.com
#

echo 'cognito-idp admin-create-user'
aws cognito-idp admin-create-user \
    --region $COGNITO_REGION \
    --user-pool-id $POOL_ID \
    --username a \
    --temporary-password aaaaaa \
    --user-attributes=Name=email,Value=a@a.com

SESSION=$(aws cognito-idp admin-initiate-auth \
    --region $COGNITO_REGION \
    --user-pool-id $POOL_ID \
    --client-id $CLIENT_ID \
    --auth-flow ADMIN_NO_SRP_AUTH \
    --auth-parameters USERNAME=a,PASSWORD=aaaaaa \
    --query "Session" \
    --output text)

aws cognito-idp admin-respond-to-auth-challenge \
    --region $COGNITO_REGION \
    --user-pool-id $POOL_ID \
    --client-id $CLIENT_ID \
    --challenge-name NEW_PASSWORD_REQUIRED \
    --challenge-responses NEW_PASSWORD=aaaaaa,USERNAME=a \
    --session "$SESSION"

echo 'cognito-idp admin-create-user'
aws cognito-idp admin-create-user \
    --region $COGNITO_REGION \
    --user-pool-id $POOL_ID \
    --username b \
    --temporary-password bbbbbb \
    --user-attributes=Name=email,Value=b@b.com

SESSION=$(aws cognito-idp admin-initiate-auth \
    --region $COGNITO_REGION \
    --user-pool-id $POOL_ID \
    --client-id $CLIENT_ID \
    --auth-flow ADMIN_NO_SRP_AUTH \
    --auth-parameters USERNAME=b,PASSWORD=bbbbbb \
    --query "Session" \
    --output text)

aws cognito-idp admin-respond-to-auth-challenge \
    --region $COGNITO_REGION \
    --user-pool-id $POOL_ID \
    --client-id $CLIENT_ID \
    --challenge-name NEW_PASSWORD_REQUIRED \
    --challenge-responses NEW_PASSWORD=bbbbbb,USERNAME=b \
    --session "$SESSION"